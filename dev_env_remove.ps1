#Requires -Version 5.1
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Wait-BeforeExit {
    param([int]$ExitCode = 0)

    Write-Host ""
    Read-Host "콘솔을 닫으려면 Enter를 누르세요"
    exit $ExitCode
}

if ($PSVersionTable.PSEdition -ne "Desktop" -or $PSVersionTable.PSVersion.Major -ne 5) {
    Write-Host "이 스크립트는 Windows PowerShell 5.1에서 실행해야 합니다." -ForegroundColor Yellow
    Wait-BeforeExit 1
}

trap {
    Write-Host "`n오류: $($_.Exception.Message)" -ForegroundColor Red
    Wait-BeforeExit 1
}

$Root = $PSScriptRoot
$ManifestDir = Join-Path $Root "manifest"
$RemoveDockerDesktop = $true
$RemoveVisualStudioBuildTools = $true
$RemoveVSCodeUserData = $true

function Write-Section { param([string]$Message)
    Write-Host "`n============================================================" -ForegroundColor DarkGray
    Write-Host " $Message" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor DarkGray
}
function Test-CommandExists { param([string]$Command)
    return $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}
function Read-Manifest { param([string]$Path)
    if (-not (Test-Path $Path)) { throw "Manifest not found: $Path" }
    return Get-Content $Path | ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and -not $_.StartsWith("#") }
}
function Remove-WingetPackage { param([string]$Id)
    $list = winget list --id $Id --exact --source winget --accept-source-agreements 2>$null | Out-String
    if ($list -match [regex]::Escape($Id)) {
        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        $output = @(& winget uninstall --id $Id --exact --source winget --accept-source-agreements --silent 2>&1)
        $exitCode = $LASTEXITCODE
        $ErrorActionPreference = $previousErrorActionPreference
        $message = $output -join "`n"
        if ($exitCode -eq 0) {
            $output | ForEach-Object { Write-Host $_ }
        } elseif ($message -match "not installed|No installed package|No package found") {
            Write-Host "[SKIP] $Id is not installed." -ForegroundColor DarkYellow
        } else {
            throw "winget uninstall failed for $Id. Exit code: $exitCode"
        }
    }
}
function Remove-UserPathEntry { param([string]$Directory)
    $userPath = [Environment]::GetEnvironmentVariable("Path","User")
    if (-not $userPath) { return }
    $parts = $userPath -split ";" | Where-Object { $_ -and $_ -ne $Directory }
    [Environment]::SetEnvironmentVariable("Path",($parts -join ";"),"User")
    if (($env:Path -split ";") -contains $Directory) {
        $env:Path = (($env:Path -split ";") | Where-Object { $_ -and $_ -ne $Directory }) -join ";"
    }
}
function Remove-UvDataDirectory { param([string]$Path, [string]$Label)
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    try {
        $fullPath = [System.IO.Path]::GetFullPath($Path.Trim())
    } catch {
        throw "uv $Label 경로를 확인할 수 없습니다: $Path"
    }
    $allowedRoots = @($env:USERPROFILE, $env:LOCALAPPDATA, $env:APPDATA) |
        Where-Object { $_ } |
        ForEach-Object { [System.IO.Path]::GetFullPath($_).TrimEnd('\') }
    $isAllowed = $false
    foreach ($root in $allowedRoots) {
        if ($fullPath.StartsWith($root + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
            $isAllowed = $true
            break
        }
    }
    if (-not $isAllowed) { throw "안전상 허용되지 않은 uv $Label 경로입니다: $fullPath" }
    if (Test-Path -LiteralPath $fullPath) {
        Remove-Item -LiteralPath $fullPath -Recurse -Force
        Write-Host "Removed uv $Label data: $fullPath"
    } else {
        Write-Host "[SKIP] uv $Label data not found: $fullPath" -ForegroundColor DarkYellow
    }
}

Write-Section "Development Environment Removal"
Write-Host "This removes tools from the manifests."
Write-Host "It will NOT delete ~/dev, source code, or project files."
Write-Host "WARNING: uv cache, uv-managed Python installations, and uv tool environments will be removed." -ForegroundColor Yellow
if ($RemoveDockerDesktop) {
    Write-Host "WARNING: Removing Docker Desktop may destroy local containers, images, volumes, and Docker data." -ForegroundColor Red
    Write-Host "Back up important Docker volumes before continuing." -ForegroundColor Yellow
}
if ($RemoveVisualStudioBuildTools) {
    Write-Host "Visual Studio Build Tools is configured for removal." -ForegroundColor Yellow
}
if ((Read-Host "Type REMOVE to continue") -ne "REMOVE") {
    Write-Host "Cancelled."
    Wait-BeforeExit 0
}

if (-not (Test-CommandExists "winget")) { throw "winget is required." }

Write-Section "Python CLI Tools"
if (Test-CommandExists "uv") {
    foreach ($tool in (Read-Manifest (Join-Path $ManifestDir "python-tools.txt"))) {
        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        $output = @(& uv tool uninstall $tool 2>&1)
        $exitCode = $LASTEXITCODE
        $ErrorActionPreference = $previousErrorActionPreference
        $message = $output -join "`n"
        if ($exitCode -eq 0 -or $message -match "Uninstalled") {
            $output | ForEach-Object { Write-Host $_ }
        } elseif ($message -match "not installed|isn't installed|does not exist") {
            Write-Host "[SKIP] $tool is not installed." -ForegroundColor DarkYellow
        } else {
            throw "uv tool uninstall failed for $tool. Exit code: $exitCode"
        }
    }
}

Write-Section "uv"
$uvDataCleaned = $false
if (Test-CommandExists "uv") {
    Write-Host "Cleaning uv cache..." -ForegroundColor Gray
    & uv cache clean
    if ($LASTEXITCODE -ne 0) { throw "uv cache clean failed. Exit code: $LASTEXITCODE" }

    $uvPythonDir = (& uv python dir 2>$null | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { throw "uv python dir failed. Exit code: $LASTEXITCODE" }
    $uvToolDir = (& uv tool dir 2>$null | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { throw "uv tool dir failed. Exit code: $LASTEXITCODE" }
    Remove-UvDataDirectory $uvPythonDir "Python"
    Remove-UvDataDirectory $uvToolDir "tool"
    $uvDataCleaned = $true
}
$uvBinaryDirectories = @(
    (Join-Path $env:USERPROFILE ".local\bin"),
    (Join-Path $env:USERPROFILE ".cargo\bin"),
    (Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Links")
)
$uvBinaryNames = @("uv.exe", "uvx.exe", "uvw.exe")
$uvRemoved = $false
foreach ($directory in $uvBinaryDirectories) {
    foreach ($binaryName in $uvBinaryNames) {
        $binaryPath = Join-Path $directory $binaryName
        if (Test-Path -LiteralPath $binaryPath) {
            Remove-Item -LiteralPath $binaryPath -Force
            Write-Host "Removed: $binaryPath"
            $uvRemoved = $true
        }
    }
}
if (-not $uvRemoved) {
    Write-Host "[SKIP] uv standalone binaries were not found in the standard locations." -ForegroundColor DarkYellow
}
if (-not $uvDataCleaned) {
    Write-Host "[SKIP] uv data cleanup was skipped because uv is not available." -ForegroundColor DarkYellow
}

Write-Section "VS Code Extensions"
if (Test-CommandExists "code") {
    $extensions = @(& code --list-extensions 2>$null | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ })
    $failedExtensions = @()
    if ($extensions.Count -eq 0) {
        Write-Host "[SKIP] No VS Code extensions are installed." -ForegroundColor DarkYellow
    }
    foreach ($extension in $extensions) {
        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        $output = @(& code --uninstall-extension $extension 2>&1)
        $exitCode = $LASTEXITCODE
        $ErrorActionPreference = $previousErrorActionPreference
        $message = $output -join "`n"
        if ($exitCode -eq 0 -or $message -match "Successfully uninstalled|uninstalled") {
            $output | ForEach-Object { Write-Host $_ }
        } elseif ($message -match "not installed|isn't installed|is not installed") {
            Write-Host "[SKIP] $extension is not installed." -ForegroundColor DarkYellow
        } else {
            $failedExtensions += $extension
            Write-Host "[FAILED] Could not uninstall $extension. Exit code: $exitCode" -ForegroundColor Red
        }
    }
    if ($failedExtensions.Count -gt 0) {
        Write-Host "VS Code extensions that could not be removed:" -ForegroundColor Red
        $failedExtensions | ForEach-Object { Write-Host "- $_" -ForegroundColor Red }
    }
} else {
    Write-Host "[SKIP] code command is not available." -ForegroundColor DarkYellow
}

if ($RemoveVSCodeUserData) {
    Write-Section "VS Code User Data"
    $vsCodePathEntries = @(
        (Join-Path $env:LOCALAPPDATA "Programs\Microsoft VS Code\bin"),
        (Join-Path $env:ProgramFiles "Microsoft VS Code\bin")
    )
    foreach ($pathEntry in $vsCodePathEntries) {
        Remove-UserPathEntry $pathEntry
        Write-Host "PATH cleaned: $pathEntry"
    }

    $vsCodeUserDataPaths = @(
        (Join-Path $env:USERPROFILE ".vscode"),
        (Join-Path $env:APPDATA "Code\User")
    )
    foreach ($path in $vsCodeUserDataPaths) {
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Recurse -Force
            Write-Host "Removed: $path"
        } else {
            Write-Host "[SKIP] Not found: $path" -ForegroundColor DarkYellow
        }
    }
}

Write-Section "Tauri CLI"
if (Test-CommandExists "cargo") {
    $installedCargoTools = & cargo install --list 2>$null | Out-String
    if ($installedCargoTools -notmatch "(?m)^\s*tauri-cli\s") {
        Write-Host "[SKIP] tauri-cli is not installed." -ForegroundColor DarkYellow
    } else {
        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        $output = @(& cargo uninstall tauri-cli 2>&1)
        $exitCode = $LASTEXITCODE
        $ErrorActionPreference = $previousErrorActionPreference
        $message = $output -join "`n"
        if ($exitCode -eq 0 -or $message -match "Removing|Removed|uninstalled") {
            $output | ForEach-Object { Write-Host $_ }
        } else {
            $output | ForEach-Object { Write-Host $_ -ForegroundColor Red }
            throw "cargo uninstall failed for tauri-cli. Exit code: $exitCode"
        }
    }
}

Write-Section "pnpm"
if (Test-CommandExists "corepack") { try { corepack disable } catch {} }

Write-Section "WinGet Packages"
foreach ($package in (Read-Manifest (Join-Path $ManifestDir "winget-packages.txt"))) {
    if ($package -eq "Docker.DockerDesktop" -and -not $RemoveDockerDesktop) { continue }
    if ($package -eq "Microsoft.VisualStudio.2022.BuildTools" -and -not $RemoveVisualStudioBuildTools) { continue }
    Remove-WingetPackage $package
}

Write-Section "Rustup"
if ((Read-Host "Remove Rust toolchains and ~/.cargo too? [y/N]") -match "^[Yy]$") {
    $rustup = Join-Path $env:USERPROFILE ".cargo\bin\rustup.exe"
    if (Test-Path $rustup) {
        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        $output = @(& $rustup self uninstall -y 2>&1)
        $exitCode = $LASTEXITCODE
        $ErrorActionPreference = $previousErrorActionPreference
        $output | ForEach-Object { Write-Host $_ }
        if ($exitCode -ne 0) { throw "rustup self uninstall failed. Exit code: $exitCode" }
    } else {
        Write-Host "[SKIP] rustup is not installed." -ForegroundColor DarkYellow
    }
}

Write-Section "Done"
Write-Host "Development tools removed. Project files and Docker/PostgreSQL data were preserved." -ForegroundColor Green
Wait-BeforeExit 0
