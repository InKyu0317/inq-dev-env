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
$RemoveDockerDesktop = $false
$RemoveVisualStudioBuildTools = $false

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
        winget uninstall --id $Id --exact --source winget --accept-source-agreements --silent
    }
}
function Remove-UserPathEntry { param([string]$Directory)
    $userPath = [Environment]::GetEnvironmentVariable("Path","User")
    if (-not $userPath) { return }
    $parts = $userPath -split ";" | Where-Object { $_ -and $_ -ne $Directory }
    [Environment]::SetEnvironmentVariable("Path",($parts -join ";"),"User")
}

Write-Section "Development Environment Removal"
Write-Host "This removes tools from the manifests."
Write-Host "It will NOT delete ~/dev, source code, Docker volumes, or PostgreSQL data."
if ((Read-Host "Type REMOVE to continue") -ne "REMOVE") {
    Write-Host "Cancelled."
    Wait-BeforeExit 0
}

if (-not (Test-CommandExists "winget")) { throw "winget is required." }

Write-Section "Lite XL Plugins"
if (Test-CommandExists "lpm") {
    foreach ($plugin in (Read-Manifest (Join-Path $ManifestDir "lpm-plugins.txt"))) {
        lpm uninstall $plugin --assume-yes
    }
}

Write-Section "Python CLI Tools"
if (Test-CommandExists "uv") {
    foreach ($tool in (Read-Manifest (Join-Path $ManifestDir "python-tools.txt"))) {
        uv tool uninstall $tool
    }
}

Write-Section "Tauri CLI"
if (Test-CommandExists "cargo") { cargo uninstall tauri-cli 2>$null }

Write-Section "pnpm"
if (Test-CommandExists "corepack") { try { corepack disable } catch {} }

Write-Section "LPM"
$lpmDir = Join-Path $env:LOCALAPPDATA "Programs\lpm"
if (Test-Path $lpmDir) { Remove-Item $lpmDir -Recurse -Force }
Remove-UserPathEntry $lpmDir

Write-Section "WinGet Packages"
foreach ($package in (Read-Manifest (Join-Path $ManifestDir "winget-packages.txt"))) {
    if ($package -eq "Docker.DockerDesktop" -and -not $RemoveDockerDesktop) { continue }
    if ($package -eq "Microsoft.VisualStudio.2022.BuildTools" -and -not $RemoveVisualStudioBuildTools) { continue }
    Remove-WingetPackage $package
}

Write-Section "Rustup"
if ((Read-Host "Remove Rust toolchains and ~/.cargo too? [y/N]") -match "^[Yy]$") {
    $rustup = Join-Path $env:USERPROFILE ".cargo\bin\rustup.exe"
    if (Test-Path $rustup) { & $rustup self uninstall -y }
}

Write-Section "Done"
Write-Host "Development tools removed. Project files and Docker/PostgreSQL data were preserved." -ForegroundColor Green
Wait-BeforeExit 0
