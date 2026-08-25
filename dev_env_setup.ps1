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
    Write-Host ""
    Write-Host "이 스크립트는 Windows PowerShell 5.1에서 실행해야 합니다." -ForegroundColor Yellow
    Write-Host "PowerShell 7에서는 실행하지 말고 Windows PowerShell을 열어주세요." -ForegroundColor Yellow
    Wait-BeforeExit 1
}

$Root = $PSScriptRoot
$ManifestDir = Join-Path $Root "manifest"

function Write-Section { param([string]$Message)
    Write-Host "`n============================================================" -ForegroundColor DarkGray
    Write-Host " $Message" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor DarkGray
}
function Test-CommandExists { param([string]$Name)
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}
function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
function Assert-Administrator {
    if (-not (Test-Administrator)) { throw "관리자 권한으로 Windows PowerShell을 다시 실행하세요." }
}
function Read-Manifest { param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "Manifest not found: $Path" }
    return @(Get-Content -LiteralPath $Path | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#")) { $line }
    })
}
function Refresh-Path {
    $machine = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $user = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machine;$user"
}
function Add-ExistingUserPath { param([string]$Directory)
    if (-not (Test-Path -LiteralPath $Directory)) { return }
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $parts = @()
    if ($userPath) { $parts = @($userPath -split ";" | Where-Object { $_ }) }
    if ($parts -notcontains $Directory) {
        [Environment]::SetEnvironmentVariable("Path", (($parts + $Directory) -join ";"), "User")
    }
    if (($env:Path -split ";") -notcontains $Directory) { $env:Path = "$Directory;$env:Path" }
}
function Invoke-Native { param([string]$Name, [string[]]$Arguments)
    if (-not (Test-CommandExists $Name)) { throw "명령을 찾을 수 없습니다: $Name" }
    & $Name @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Name 실행 실패. 종료 코드: $LASTEXITCODE" }
}
function Get-VersionLine { param([string]$Name)
    if (-not (Test-CommandExists $Name)) { return "NOT FOUND" }
    try {
        $line = & $Name --version 2>&1 | Select-Object -First 1
        if ($line) { return ([string]$line).Trim() }
        return "installed"
    } catch { return "FAILED TO RUN" }
}
function Install-WingetPackage { param([string]$Id)
    Write-Host "Checking $Id ..." -ForegroundColor Gray
    $installed = & winget list --id $Id --exact --source winget --accept-source-agreements 2>$null | Out-String
    if ($installed -match [regex]::Escape($Id)) {
        $output = @(& winget upgrade --id $Id --exact --source winget --accept-source-agreements --accept-package-agreements --silent 2>&1)
        $exitCode = $LASTEXITCODE
        $output | ForEach-Object { Write-Host $_ }
        if ($exitCode -ne 0 -and (($output -join "`n") -notmatch "No available upgrade|No newer package versions")) {
            throw "winget 실행 실패. 종료 코드: $exitCode"
        }
    } else {
        Invoke-Native "winget" @("install", "--id", $Id, "--exact", "--source", "winget", "--accept-source-agreements", "--accept-package-agreements", "--silent")
    }
}

function Step-Check {
    Write-Section "1. 환경 점검"
    Write-Host "PowerShell: $($PSVersionTable.PSVersion)"
    Write-Host "관리자 권한: $(Test-Administrator)"
    foreach ($name in @("winget", "git", "python", "py", "uv", "node", "npm", "corepack", "pnpm", "dotnet", "rustup", "rustc", "cargo", "docker", "code")) {
        $version = Get-VersionLine $name
        $color = if ($version -eq "NOT FOUND" -or $version -eq "FAILED TO RUN") { "DarkYellow" } else { "Green" }
        Write-Host ("{0,-12} {1}" -f $name, $version) -ForegroundColor $color
    }
    Write-Host "이 단계는 시스템을 변경하지 않습니다." -ForegroundColor Green
}
function Step-Winget {
    Assert-Administrator
    Write-Section "2. WinGet 패키지 설치"
    if (-not (Test-CommandExists "winget")) { throw "winget이 없습니다. Microsoft App Installer를 먼저 설치하세요." }
    foreach ($id in (Read-Manifest (Join-Path $ManifestDir "winget-packages.txt"))) { Install-WingetPackage $id }
    Refresh-Path
    Add-ExistingUserPath (Join-Path $env:LOCALAPPDATA "Programs\Microsoft VS Code\bin")
    Add-ExistingUserPath (Join-Path $env:ProgramFiles "Microsoft VS Code\bin")
}
function Step-Uv {
    Write-Section "4. uv 설치 및 확인"
    if (Test-CommandExists "uv") { Write-Host ("uv: {0}" -f (Get-VersionLine "uv")) -ForegroundColor Green; return }
    if (-not (Test-CommandExists "winget")) { throw "uv 설치에 필요한 winget을 찾을 수 없습니다. 먼저 2번을 실행하세요." }
    Install-WingetPackage "astral-sh.uv"
    Refresh-Path
    Add-ExistingUserPath (Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Links")
    if (-not (Test-CommandExists "uv")) { throw "uv가 설치되었지만 현재 터미널에서 찾을 수 없습니다. 새 터미널을 열어주세요." }
    Write-Host ("uv: {0}" -f (Get-VersionLine "uv")) -ForegroundColor Green
}
function Step-VSCodeExtensions {
    Write-Section "3. VS Code 확장 설치"
    if (-not (Test-CommandExists "code")) { throw "code 명령을 찾을 수 없습니다. 먼저 2번을 실행하세요." }
    foreach ($extension in (Read-Manifest (Join-Path $ManifestDir "vscode-extensions.txt"))) {
        Write-Host "Installing VS Code extension: $extension" -ForegroundColor Gray
        Invoke-Native "code" @("--install-extension", $extension, "--force")
    }
}
function Step-PythonTools {
    Write-Section "5. Python CLI 도구 설치"
    if (-not (Test-CommandExists "uv")) { throw "먼저 4번을 실행하세요." }
    foreach ($tool in (Read-Manifest (Join-Path $ManifestDir "python-tools.txt"))) { Invoke-Native "uv" @("tool", "install", "--upgrade", $tool) }
}
function Step-Node {
    Write-Section "6. Node.js / pnpm 구성"
    if (-not (Test-CommandExists "corepack")) { throw "corepack이 없습니다. 먼저 2번을 실행하세요." }
    Invoke-Native "corepack" @("enable")
    Invoke-Native "corepack" @("prepare", "pnpm@latest", "--activate")
    Write-Host ("pnpm: {0}" -f (Get-VersionLine "pnpm")) -ForegroundColor Green
}
function Step-Rust {
    Write-Section "7. Rust 구성"
    if (-not (Test-CommandExists "rustup")) { throw "rustup이 없습니다. 먼저 2번을 실행하세요." }
    Invoke-Native "rustup" @("toolchain", "install", "stable")
    Invoke-Native "rustup" @("default", "stable-msvc")
    Invoke-Native "rustup" @("component", "add", "rustfmt")
    Invoke-Native "rustup" @("component", "add", "clippy")
}
function Step-Tauri {
    Write-Section "8. Tauri CLI 구성"
    if (-not (Test-CommandExists "cargo")) { throw "cargo가 없습니다. 먼저 7번을 실행하세요." }
    Invoke-Native "cargo" @("install", "tauri-cli", "--locked", "--force")
}
function Step-Directories {
    Write-Section "9. 개발 디렉터리 생성"
    foreach ($dir in @((Join-Path $env:USERPROFILE "dev"), (Join-Path $env:USERPROFILE "dev\projects"), (Join-Path $env:USERPROFILE "dev\tools"), (Join-Path $env:USERPROFILE "dev\docker"))) {
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null; Write-Host "생성: $dir" }
        else { Write-Host "존재: $dir" }
    }
}
function Step-Docker {
    Write-Section "10. Docker 확인"
    if (-not (Test-CommandExists "docker")) { Write-Host "Docker 명령을 찾을 수 없습니다." -ForegroundColor DarkYellow; return }
    Write-Host ("Docker: {0}" -f (Get-VersionLine "docker"))
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & docker info 1>$null 2>$null
    $dockerExitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorActionPreference
    if ($dockerExitCode -eq 0) { Write-Host "Docker Engine: READY" -ForegroundColor Green }
    else { Write-Host "Docker CLI: READY" -ForegroundColor Green; Write-Host "Docker Engine: NOT READY - Docker Desktop을 실행하세요." -ForegroundColor DarkYellow }
}
function Step-Verify {
    Write-Section "11. 최종 확인"
    if (Test-CommandExists "dotnet") {
        Write-Host ""
        Write-Host ".NET SDK 목록" -ForegroundColor Cyan
        dotnet --list-sdks
        Write-Host ""
        Write-Host ".NET Runtime 목록" -ForegroundColor Cyan
        dotnet --list-runtimes
        Write-Host ""
        Write-Host "기본 .NET SDK: $(dotnet --version)" -ForegroundColor Green
    }
    foreach ($name in @("git", "python", "uv", "ruff", "dotnet", "node", "npm", "pnpm", "rustc", "cargo", "docker", "code")) { Write-Host ("{0,-12} {1}" -f $name, (Get-VersionLine $name)) }
}

while ($true) {
    Write-Section "Development Environment Setup - Windows PowerShell 5.1"
    Write-Host "1. 환경 점검"
    Write-Host "2. WinGet 패키지 설치"
    Write-Host "3. VS Code 확장 설치"
    Write-Host "4. uv 설치 및 확인"
    Write-Host "5. Python CLI 도구 설치"
    Write-Host "6. Node.js / pnpm 구성"
    Write-Host "7. Rust 구성"
    Write-Host "8. Tauri CLI 구성"
    Write-Host "9. 개발 디렉터리 생성"
    Write-Host "10. Docker 확인"
    Write-Host "11. 최종 확인"
    Write-Host "0. 종료"
    $choice = Read-Host "실행할 번호를 입력하세요"
    try {
        switch ($choice) {
            "1" { Step-Check }
            "2" { Step-Winget }
            "3" { Step-VSCodeExtensions }
            "4" { Step-Uv }
            "5" { Step-PythonTools }
            "6" { Step-Node }
            "7" { Step-Rust }
            "8" { Step-Tauri }
            "9" { Step-Directories }
            "10" { Step-Docker }
            "11" { Step-Verify }
            "0" { Write-Host "종료합니다."; Wait-BeforeExit 0 }
            default { Write-Host "올바른 번호를 입력하세요." -ForegroundColor Yellow }
        }
    } catch { Write-Host "`n오류: $($_.Exception.Message)" -ForegroundColor Red }
    Read-Host "계속하려면 Enter를 누르세요"
}
