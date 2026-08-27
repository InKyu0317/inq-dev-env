# Windows / macOS 개발환경 설치·제거 가이드

Windows와 macOS에서 개발 도구를 한 단계씩 설치하고 검증하며, 필요할 때 안전하게 제거하기 위한 수동 가이드입니다.

이 저장소는 시스템 전체를 자동으로 변경하는 설치·제거 스크립트를 제공하지 않습니다. 사용자가 직접 명령을 확인하여 실행하거나, 코딩 에이전트가 이 문서를 기준으로 단계별 작업을 수행하는 방식을 권장합니다.

> 문서 기준일: 2026-08-27<br>
> 기준 환경: Windows x64 또는 macOS Apple Silicon/Intel<br>
> 핵심 버전: Python 3.11, Windows용 .NET SDK 10

## 목차

- [1. 기본 원칙](#1-기본-원칙)
- [2. 설치 대상](#2-설치-대상)
- [3. 운영체제별 주요 차이](#3-운영체제별-주요-차이)
- [4. Windows 설치](#4-windows-설치)
- [5. macOS 설치](#5-macos-설치)
- [6. 공통 설치 검증](#6-공통-설치-검증)
- [7. 프로젝트 환경 생성](#7-프로젝트-환경-생성)
- [8. Windows 제거](#8-windows-제거)
- [9. macOS 제거](#9-macos-제거)
- [10. 문제 해결](#10-문제-해결)
- [11. 코딩 에이전트용 프롬프트](#11-코딩-에이전트용-프롬프트)
- [12. 공식 참고 자료](#12-공식-참고-자료)
- [13. 저장소 이력](#13-저장소-이력)

## 1. 기본 원칙

- 먼저 현재 상태를 확인하고 없는 도구만 설치합니다.
- 명령은 한 번에 하나씩 실행하고 바로 검증합니다.
- 실패하면 다음 단계로 넘어가지 않습니다.
- 기존 Python, Conda, pyenv, .NET Runtime, Docker 데이터, VS Code 설정을 임의로 삭제하지 않습니다.
- Python 3.11은 운영체제 전역 설치보다 `uv` 관리 환경을 우선합니다.
- 프로젝트 패키지는 전역 설치 대신 `.venv`와 lock file로 관리합니다.
- 관리자 권한, 재부팅, 라이선스 동의, PATH 변경, 데이터 삭제 전에는 사용자 확인이 필요합니다.
- 이 문서보다 공식 문서의 현재 지원 조건을 우선합니다.

## 2. 설치 대상

| 영역 | Windows | macOS | 버전 정책 |
|---|---|---|---|
| Python 관리 | uv | uv | 최신 안정 버전 |
| Python | uv 관리 CPython | uv 관리 CPython | 3.11.x |
| ASP.NET | .NET SDK | 설치하지 않음 | Windows 10.x LTS |
| JS 패키지 | pnpm | pnpm | 최신 안정 버전 |
| Rust | rustup + stable-msvc | rustup + stable | 최신 stable |
| 네이티브 빌드 | Visual Studio Build Tools | Xcode Command Line Tools | OS 지원 버전 |
| 컨테이너 | Docker Desktop + WSL 2 | Docker Desktop | OS 지원 버전 |
| 편집기 | VS Code Stable | VS Code Stable | 최신 안정 버전 |

Windows에서 `.NET SDK 10`을 설치하면 같은 버전의 .NET Runtime과 ASP.NET Core Runtime도 함께 설치됩니다. 해당 런타임을 별도로 중복 설치할 필요가 없습니다.

Python 3.11의 python.org 전통적 Windows/macOS 바이너리 설치 프로그램은 3.11.9가 마지막입니다. 여기서는 최신 3.11.x를 일관되게 사용하기 위해 `uv python install 3.11`을 사용합니다.

## 3. 운영체제별 주요 차이

| 항목 | Windows | macOS |
|---|---|---|
| 패키지 관리자 | WinGet | Homebrew |
| 기본 셸 | PowerShell | zsh |
| CPU 확인 | `$env:PROCESSOR_ARCHITECTURE` | `uname -m` |
| Python 실행 | `uv run python` | `uv run python` |
| 가상환경 활성화 | `.venv\Scripts\Activate.ps1` | `source .venv/bin/activate` |
| Rust target | `*-pc-windows-msvc` | `*-apple-darwin` |
| 네이티브 빌드 | MSVC + Windows SDK | clang + macOS SDK |
| Docker 기반 | WSL 2 권장 | Docker Desktop Linux VM |
| PATH 관리 | 사용자/시스템 환경변수 | `~/.zprofile`, `~/.zshrc` |

---

## 4. Windows 설치

### 4.1 요구사항

- Windows 10 22H2 또는 지원 중인 Windows 11 64-bit 권장
- Windows PowerShell 5.1 또는 PowerShell 7
- App Installer와 WinGet
- Docker 사용 시 BIOS/UEFI 가상화와 WSL 2
- 인터넷 연결

Docker Desktop 요구사항은 일반 CLI 도구보다 엄격하고 변경될 수 있습니다. 설치 전에 [Docker Desktop for Windows](https://docs.docker.com/desktop/setup/install/windows-install/)를 확인합니다.

### 4.2 설치 전 점검

일반 권한 PowerShell에서 한 줄씩 실행합니다. 찾을 수 없는 명령은 해당 도구가 없거나 현재 PowerShell의 PATH가 갱신되지 않은 상태입니다.

```powershell
Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion, OsArchitecture
$env:PROCESSOR_ARCHITECTURE
winget --version
uv --version
dotnet --list-sdks
pnpm --version
rustup --version
rustc --version
cargo --version
docker version
code --version
```

현재 명령 위치도 기록해 두면 나중에 제거 검증에 도움이 됩니다.

```powershell
Get-Command uv, dotnet, pnpm, rustup, rustc, cargo, docker, code -ErrorAction SilentlyContinue
```

### 4.3 WinGet 준비

```powershell
winget source update
```

WinGet이 없다면 Microsoft Store의 **App Installer** 또는 [Microsoft WinGet 안내](https://learn.microsoft.com/windows/package-manager/winget/)를 사용합니다.

### 4.4 기본 패키지

다음 명령을 한 번에 하나씩 실행합니다.

```powershell
winget install --id astral-sh.uv --exact --source winget
winget install --id Microsoft.DotNet.SDK.10 --exact --source winget
winget install --id pnpm.pnpm --exact --source winget
winget install --id Rustlang.Rustup --exact --source winget
winget install --id Microsoft.VisualStudioCode --exact --source winget
```

`No available upgrade found`는 설치 실패가 아니라 적용할 업데이트가 없다는 의미입니다. 설치 후 PowerShell을 완전히 닫고 새 창을 엽니다.

### 4.5 Visual C++ Build Tools

Windows의 Rust MSVC와 Tauri 빌드에는 `link.exe`, MSVC toolchain, Windows SDK가 필요합니다. VS Code만으로는 제공되지 않습니다.

```powershell
winget install --id Microsoft.VisualStudio.2022.BuildTools --exact --source winget
```

설치 후 Visual Studio Installer를 열어 다음 항목을 확인합니다.

- **Desktop development with C++** workload
- MSVC x64/x86 build tools
- Windows SDK
- CMake tools for Windows

에이전트가 workload까지 명령행으로 설치할 때만 관리자 PowerShell에서 다음을 사용합니다.

```powershell
winget install --id Microsoft.VisualStudio.2022.BuildTools --exact --source winget --override "--wait --passive --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
```

검증:

```powershell
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
& $vswhere -products Microsoft.VisualStudio.Product.BuildTools -all -property installationPath
Get-ChildItem "${env:ProgramFiles(x86)}\Microsoft Visual Studio" -Filter link.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 5 FullName
```

### 4.6 Python 3.11

```powershell
uv python install 3.11
uv python list
uv run --python 3.11 python --version
```

프로젝트에 적용:

```powershell
Set-Location C:\path\to\project
uv python pin 3.11
uv venv
.venv\Scripts\Activate.ps1
python --version
```

기존 `pyproject.toml`과 `uv.lock`이 있다면 다음으로 복원합니다.

```powershell
uv sync
uv run python --version
```

가상환경 활성화가 실행 정책에 막혀도 `uv run`과 `uv sync`는 활성화 없이 사용할 수 있습니다.

### 4.7 .NET SDK 10

```powershell
dotnet --version
dotnet --list-sdks
dotnet --list-runtimes
```

`dotnet`은 실행되지만 SDK 목록이 비어 있으면 host/runtime만 있는 상태입니다. `Microsoft.DotNet.SDK.10` 설치 여부를 다시 확인합니다.

### 4.8 pnpm, Rust

```powershell
pnpm --version
rustup default stable-msvc
rustup update stable
rustup show
rustc --version
cargo --version
```

`link.exe not found`가 나오면 Rust를 재설치하기 전에 Visual C++ workload와 Windows SDK부터 확인합니다.

### 4.9 Docker Desktop

```powershell
wsl --status
wsl --version
```

WSL이 없거나 오래된 경우 관리자 PowerShell에서 설치·업데이트하고, 안내가 나오면 재부팅합니다.

```powershell
wsl --install
wsl --update
```

Docker Desktop 설치:

```powershell
winget install --id Docker.DockerDesktop --exact --source winget
```

Docker Desktop 앱을 직접 실행하여 초기 설정과 이용약관을 확인한 다음 검증합니다.

```powershell
docker desktop status
docker context ls
docker info
```

`docker --version`은 CLI만 확인합니다. `docker info`에 Server 정보가 없으면 Docker 엔진이 준비되지 않은 것입니다.

### 4.10 VS Code 확장

```powershell
code --install-extension ms-python.python
code --install-extension ms-python.vscode-pylance
code --install-extension ms-python.debugpy
code --install-extension charliermarsh.ruff
code --install-extension ms-dotnettools.csdevkit
code --install-extension rust-lang.rust-analyzer
code --install-extension ms-azuretools.vscode-docker
code --install-extension redhat.vscode-yaml
code --install-extension tamasfe.even-better-toml
code --install-extension ms-vscode.powershell
code --list-extensions
```

---

## 5. macOS 설치

macOS에서는 이 개발환경의 `.NET SDK`를 설치하지 않습니다.

### 5.1 요구사항과 아키텍처

- macOS 14 Sonoma 이상 권장
- 관리자 암호를 사용할 수 있는 사용자
- 인터넷 연결

```zsh
sw_vers
uname -m
xcode-select -p
brew --version
uv --version
pnpm --version
rustup --version
rustc --version
cargo --version
docker version
code --version
```

- `arm64`: Apple Silicon용 도구를 사용합니다.
- `x86_64`: Intel용 도구를 사용합니다.

Apple Silicon에서는 특별한 Intel 전용 의존성이 없다면 Rosetta와 x64 도구를 추가하지 않습니다.

### 5.2 Xcode Command Line Tools

```zsh
xcode-select --install
xcode-select -p
clang --version
```

설치 창이 열리면 완료될 때까지 기다리고 Terminal을 새로 엽니다.

### 5.3 Homebrew

[Homebrew 공식 설치 페이지](https://brew.sh/)의 명령을 사용합니다.

```zsh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

설치 마지막의 `Next steps`를 그대로 실행합니다. 일반적인 prefix는 Apple Silicon의 `/opt/homebrew`, Intel의 `/usr/local`입니다.

현재 Terminal에 적용:

```zsh
# Apple Silicon
eval "$(/opt/homebrew/bin/brew shellenv)"

# Intel에서는 위 명령 대신 사용
eval "$(/usr/local/bin/brew shellenv)"
```

```zsh
brew update
brew doctor
```

### 5.4 기본 패키지

```zsh
brew install uv
brew install pnpm
```

### 5.5 Python 3.11

```zsh
uv python install 3.11
uv python list
uv run --python 3.11 python --version
```

프로젝트에 적용:

```zsh
cd /path/to/project
uv python pin 3.11
uv venv
source .venv/bin/activate
python --version
```

기존 프로젝트:

```zsh
uv sync
uv run python --version
```

### 5.6 pnpm, Rust

```zsh
pnpm --version
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source "$HOME/.cargo/env"
rustup default stable
rustup update stable
rustup show
rustc --version
cargo --version
```

### 5.7 Docker Desktop

```zsh
brew install --cask docker-desktop
```

Applications에서 Docker Desktop을 처음 실행하고 권한, 네트워크, 이용약관을 확인합니다.

```zsh
docker context ls
docker info
```

현재 macOS 지원 범위와 라이선스는 [Docker Desktop for macOS](https://docs.docker.com/desktop/setup/install/mac-install/)에서 확인합니다.

### 5.8 VS Code와 확장

```zsh
brew install --cask visual-studio-code
```

VS Code의 Command Palette에서 **Shell Command: Install 'code' command in PATH**를 실행한 다음 설치합니다.

```zsh
code --install-extension ms-python.python
code --install-extension ms-python.vscode-pylance
code --install-extension ms-python.debugpy
code --install-extension charliermarsh.ruff
code --install-extension rust-lang.rust-analyzer
code --install-extension ms-azuretools.vscode-docker
code --install-extension redhat.vscode-yaml
code --install-extension tamasfe.even-better-toml
code --list-extensions
```

---

## 6. 공통 설치 검증

새 PowerShell 또는 Terminal에서 확인합니다. macOS에서는 `dotnet` 항목을 제외합니다.

```text
uv --version
uv run --python 3.11 python --version
dotnet --version               # Windows only
dotnet --list-sdks             # Windows only
pnpm --version
rustup --version
rustc --version
cargo --version
docker version
code --version
```

정상 기준:

- Python은 `3.11.x`입니다.
- Windows의 SDK 목록에는 `10.x`가 있습니다.
- Rust target은 Windows에서 `stable-*-pc-windows-msvc`, macOS에서 `stable-*-apple-darwin`입니다.
- Docker는 Client와 Server 정보를 모두 표시합니다.

다음 smoke test는 이미지를 다운로드하므로 사용자 동의 후 실행합니다.

```text
docker run --rm hello-world
```

## 7. 프로젝트 환경 생성

Python 프로젝트:

```text
uv init
uv python pin 3.11
uv venv
uv add pytest ruff
uv run pytest
```

`pyproject.toml`과 `uv.lock`은 Git에 커밋하고 `.venv`는 제외합니다.

Windows ASP.NET Core 프로젝트:

```text
dotnet new webapi -n SampleApi
dotnet build SampleApi
dotnet run --project SampleApi
```

Node.js 프로젝트:

```text
pnpm init
pnpm install
```

Rust 프로젝트:

```text
cargo new sample-rust
cargo check --manifest-path sample-rust/Cargo.toml
```

---

## 8. Windows 제거

### 8.1 제거 전 기록과 백업

다음 결과를 저장하거나 화면에서 확인합니다.

```powershell
winget list
dotnet --list-sdks
dotnet --list-runtimes
uv python list
uv tool list
code --list-extensions
docker context ls
docker volume ls
Get-Command git, uv, dotnet, node, npm, pnpm, rustup, rustc, cargo, docker, code -ErrorAction SilentlyContinue
[Environment]::GetEnvironmentVariable('Path', 'User')
[Environment]::GetEnvironmentVariable('Path', 'Machine')
```

Docker volume과 데이터베이스가 필요하면 제거 전에 별도 백업합니다. `docker compose down -v`, `docker volume rm`, `wsl --unregister`는 데이터를 영구 삭제할 수 있으므로 백업 없이 실행하지 않습니다.

### 8.2 VS Code 확장과 사용자 설정

설치한 확장만 제거하려면 각각 실행합니다.

```powershell
code --uninstall-extension ms-python.python
code --uninstall-extension ms-python.vscode-pylance
code --uninstall-extension ms-python.debugpy
code --uninstall-extension charliermarsh.ruff
code --uninstall-extension ms-dotnettools.csdevkit
code --uninstall-extension rust-lang.rust-analyzer
code --uninstall-extension ms-azuretools.vscode-docker
code --uninstall-extension redhat.vscode-yaml
code --uninstall-extension tamasfe.even-better-toml
code --uninstall-extension ms-vscode.powershell
```

VS Code 제거:

```powershell
winget uninstall --id Microsoft.VisualStudioCode --exact --source winget
```

사용자 설정과 모든 확장까지 완전히 삭제하려는 경우 VS Code와 관련 프로세스를 모두 종료하고 다음 경로를 먼저 확인합니다.

```powershell
Get-Process code -ErrorAction SilentlyContinue
Get-ChildItem "$env:APPDATA\Code" -Force -ErrorAction SilentlyContinue
Get-ChildItem "$env:USERPROFILE\.vscode" -Force -ErrorAction SilentlyContinue
Get-ChildItem "$env:LOCALAPPDATA\Programs\Microsoft VS Code" -Force -ErrorAction SilentlyContinue
```

다음 경로 삭제는 설정, extension, snippet, profile을 복구할 수 없게 만듭니다. 필요한 파일을 백업한 뒤 정확한 경로를 하나씩 삭제합니다.

```powershell
Remove-Item -LiteralPath "$env:APPDATA\Code" -Recurse -Force
Remove-Item -LiteralPath "$env:USERPROFILE\.vscode" -Recurse -Force
Remove-Item -LiteralPath "$env:LOCALAPPDATA\Programs\Microsoft VS Code" -Recurse -Force
```

### 8.3 uv와 Python 3.11

uv가 관리한 위치를 먼저 확인합니다.

```powershell
uv cache dir
uv python dir
uv tool dir
uv python list
uv tool list
```

프로젝트 `.venv`는 각 프로젝트 폴더 안에 있으므로 전역 제거와 별개입니다. 필요 없는 프로젝트의 `.venv`만 해당 프로젝트에서 삭제합니다.

```powershell
uv cache clean
uv python uninstall 3.11
winget uninstall --id astral-sh.uv --exact --source winget
```

제거 후 확인:

```powershell
where.exe uv
Get-Command uv, uvx -ErrorAction SilentlyContinue
Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Links" -Filter "uv*" -Force -ErrorAction SilentlyContinue
```

WinGet의 `Links` 폴더 전체를 삭제하지 않습니다. `uv.exe`, `uvx.exe`, `uvw.exe`처럼 제거한 패키지의 고아 링크만 남았고 대상이 존재하지 않는 것이 확인될 때만 해당 링크 하나를 정리합니다.

WindowsApps의 `python.exe`와 `python3.exe`는 App Installer 실행 별칭입니다. 파일을 직접 지우지 말고 **설정 → 앱 → 고급 앱 설정 → 앱 실행 별칭**에서 Python 별칭을 끕니다.

### 8.4 Rust

```powershell
rustup self uninstall
winget uninstall --id Rustlang.Rustup --exact --source winget
```

제거 후 확인:

```powershell
where.exe rustup
where.exe rustc
where.exe cargo
Get-ChildItem "$env:USERPROFILE\.cargo" -Force -ErrorAction SilentlyContinue
Get-ChildItem "$env:USERPROFILE\.rustup" -Force -ErrorAction SilentlyContinue
```

다른 Rust 프로젝트의 cache와 설치 도구가 필요 없다면 확인 후 `%USERPROFILE%\.cargo`와 `%USERPROFILE%\.rustup`을 개별 삭제합니다. `.cargo\bin` PATH 항목도 환경변수 편집기에서 제거합니다.

### 8.5 Node.js와 pnpm

```powershell
winget uninstall --id pnpm.pnpm --exact --source winget
winget uninstall --id OpenJS.NodeJS.LTS --exact --source winget
```

잔여 위치와 환경변수를 확인합니다.

```powershell
where.exe node
where.exe npm
where.exe pnpm
[Environment]::GetEnvironmentVariable('PNPM_HOME', 'User')
Get-ChildItem "$env:APPDATA\npm" -Force -ErrorAction SilentlyContinue
Get-ChildItem "$env:LOCALAPPDATA\pnpm" -Force -ErrorAction SilentlyContinue
Get-ChildItem "$env:LOCALAPPDATA\pnpm-cache" -Force -ErrorAction SilentlyContinue
```

다른 global npm/pnpm 패키지가 필요하지 않은 경우에만 해당 데이터 폴더와 사용자 `PNPM_HOME`을 제거하고, PATH에서 정확히 같은 pnpm 경로를 삭제합니다.

### 8.6 .NET SDK와 Runtime

먼저 어떤 SDK와 Runtime이 다른 애플리케이션에 필요한지 확인합니다.

```powershell
dotnet --list-sdks
dotnet --list-runtimes
winget list --id Microsoft.DotNet.SDK.10 --exact
```

SDK 10 제거:

```powershell
winget uninstall --id Microsoft.DotNet.SDK.10 --exact --source winget
```

SDK 제거 후에도 별도로 설치한 10.x Runtime 패키지가 있고 더 이상 필요한 애플리케이션이 없을 때만 각각 제거합니다.

```powershell
winget uninstall --id Microsoft.DotNet.DesktopRuntime.10 --exact --source winget
winget uninstall --id Microsoft.DotNet.AspNetCore.10 --exact --source winget
winget uninstall --id Microsoft.DotNet.Runtime.10 --exact --source winget
```

다른 앱이 사용하는 .NET 6/8 Runtime과 Windows App Runtime, .NET Native Runtime, VCLibs, WebView2 Runtime은 이 환경의 제거 대상으로 간주하지 않습니다.

### 8.7 Visual Studio Build Tools

Visual Studio Installer에서 Build Tools 인스턴스를 선택하여 제거하는 방법을 우선합니다. 다른 Visual Studio 제품과 workload가 함께 설치되어 있으면 WinGet 제거 전에 Installer에서 구성요소를 확인합니다.

```powershell
winget uninstall --id Microsoft.VisualStudio.2022.BuildTools --exact --source winget
```

```powershell
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
& $vswhere -products Microsoft.VisualStudio.Product.BuildTools -all -property installationPath
```

등록이 사라졌다고 해서 `C:\Program Files (x86)\Microsoft Visual Studio` 전체를 삭제해서는 안 됩니다. 다른 Visual Studio 제품과 공용 Installer가 있을 수 있습니다.

### 8.8 Docker Desktop

Docker Desktop을 종료하고 필요한 volume을 백업한 뒤 제거합니다.

```powershell
docker desktop stop
winget uninstall --id Docker.DockerDesktop --exact --source winget
```

잔여 상태 확인:

```powershell
wsl --list --verbose
Get-ChildItem "$env:APPDATA\Docker" -Force -ErrorAction SilentlyContinue
Get-ChildItem "$env:LOCALAPPDATA\Docker" -Force -ErrorAction SilentlyContinue
Get-ChildItem "$env:USERPROFILE\.docker" -Force -ErrorAction SilentlyContinue
Get-ChildItem "$env:PROGRAMDATA\DockerDesktop" -Force -ErrorAction SilentlyContinue
```

완전 초기화를 원하는 경우에만 Docker 공식 제거 문서에서 현재 버전의 잔여 경로와 WSL 배포판 이름을 확인합니다. `wsl --unregister <배포판>`은 해당 가상 디스크의 image, container, volume을 영구 삭제하므로 이름과 백업을 확인하기 전에는 실행하지 않습니다.

### 8.9 Git과 PATH 최종 정리

```powershell
winget uninstall --id Git.Git --exact --source winget
```

사용자와 시스템 PATH를 확인합니다.

```powershell
[Environment]::GetEnvironmentVariable('Path', 'User') -split ';'
[Environment]::GetEnvironmentVariable('Path', 'Machine') -split ';'
```

**시스템 속성 → 고급 → 환경 변수**에서 제거된 도구와 정확히 일치하는 항목만 삭제합니다. 대표적인 후보는 다음과 같습니다.

```text
%USERPROFILE%\.cargo\bin
%LOCALAPPDATA%\pnpm
%LOCALAPPDATA%\Programs\Microsoft VS Code\bin
C:\Program Files\nodejs
C:\Program Files\dotnet
```

`C:\Program Files\dotnet`은 다른 Runtime이 남아 있으면 PATH에서 제거하지 않습니다. `%LOCALAPPDATA%\Microsoft\WindowsApps`와 `%LOCALAPPDATA%\Microsoft\WinGet\Links` 폴더 자체도 제거하지 않습니다.

새 PowerShell을 열고 최종 확인합니다.

```powershell
Get-Command git, uv, dotnet, node, npm, pnpm, rustup, rustc, cargo, docker, code -ErrorAction SilentlyContinue
```

---

## 9. macOS 제거

### 9.1 제거 전 기록과 백업

```zsh
brew list --formula
brew list --cask
uv python list
uv tool list
rustup show
code --list-extensions
docker context ls
docker volume ls
command -v git uv node npm pnpm rustup rustc cargo docker code
printf '%s\n' "$PATH" | tr ':' '\n'
```

Docker volume, 데이터베이스, VS Code 설정이 필요하면 먼저 백업합니다.

### 9.2 VS Code

```zsh
code --list-extensions
brew uninstall --cask visual-studio-code
```

설정과 모든 확장까지 삭제하려면 VS Code를 종료하고 먼저 확인합니다.

```zsh
ls -la "$HOME/Library/Application Support/Code"
ls -la "$HOME/.vscode"
ls -l /usr/local/bin/code
```

백업 후 다음 두 사용자 데이터 경로를 개별 삭제할 수 있습니다.

```zsh
rm -rf "$HOME/Library/Application Support/Code"
rm -rf "$HOME/.vscode"
```

Command Palette가 만든 `/usr/local/bin/code` 심볼릭 링크는 `ls -l` 결과가 제거된 Visual Studio Code 앱을 가리킬 때만 해당 링크 하나를 삭제합니다. `/usr/local/bin` 전체를 삭제하지 않습니다.

### 9.3 uv와 Python 3.11

```zsh
uv cache dir
uv python dir
uv tool dir
uv cache clean
uv python uninstall 3.11
brew uninstall uv
command -v uv
```

`uv python dir`와 `uv tool dir` 결과를 기록한 뒤 다른 uv Python과 도구가 없을 때만 해당 디렉터리를 삭제합니다. 각 프로젝트의 `.venv`는 프로젝트별로 별도 정리합니다.

### 9.4 Rust

```zsh
rustup self uninstall
command -v rustup rustc cargo
ls -la "$HOME/.cargo"
ls -la "$HOME/.rustup"
```

다른 Rust 도구와 cache가 필요 없을 때만 `~/.cargo`와 `~/.rustup`을 제거합니다. `~/.zprofile`, `~/.zshrc`에서 `source "$HOME/.cargo/env"` 또는 `.cargo/bin` PATH 줄도 정확히 찾아 삭제합니다.

### 9.5 Node.js와 pnpm

```zsh
brew uninstall pnpm
brew uninstall node@24
brew cleanup
command -v node npm pnpm
```

`~/.zshrc`에 직접 추가했던 다음 형태의 줄을 제거합니다.

```text
export PATH="$(brew --prefix node@24)/bin:$PATH"
```

다른 global package가 필요 없는 경우에만 `npm config get prefix`, `pnpm store path`로 경로를 확인하고 해당 cache/store를 정리합니다.

### 9.6 Docker Desktop

Docker Desktop을 종료하고 volume을 백업한 뒤 제거합니다.

```zsh
brew uninstall --cask docker-desktop
```

잔여 데이터 후보를 먼저 확인합니다.

```zsh
ls -la "$HOME/.docker"
ls -la "$HOME/Library/Containers/com.docker.docker"
ls -la "$HOME/Library/Group Containers/group.com.docker"
ls -la "$HOME/Library/Application Support/Docker Desktop"
```

이 경로에는 image, container, volume, credential 설정이 포함될 수 있습니다. 완전 초기화가 필요한 경우에만 [Docker Desktop for macOS 제거 안내](https://docs.docker.com/desktop/uninstall/)의 현재 경로를 확인하고 삭제합니다.

### 9.7 Git, Homebrew, Xcode CLT

Homebrew로 설치한 Git 제거:

```zsh
brew uninstall git
```

Homebrew와 Xcode Command Line Tools는 다른 프로그램도 사용할 수 있으므로 기본적으로 보존합니다.

Homebrew를 이 개발환경에서만 사용했고 모든 formula/cask와 cache를 제거하려는 경우에만 [Homebrew FAQ의 공식 제거 절차](https://docs.brew.sh/FAQ#how-do-i-uninstall-homebrew)를 사용합니다. 실행 전에 `brew list --formula`와 `brew list --cask`를 반드시 검토합니다.

Xcode Command Line Tools도 다른 빌드 도구가 사용합니다. 단순히 Git이나 Rust를 제거하기 위해 CLT 전체를 삭제하지 않습니다. 완전 제거가 필요하면 `/Library/Developer/CommandLineTools`가 실제 선택 경로인지 `xcode-select -p`로 확인한 뒤 Apple 지원 절차를 따릅니다.

### 9.8 shell profile, PATH, 환경변수, 링크

수정 전에 profile을 백업합니다.

```zsh
cp "$HOME/.zprofile" "$HOME/.zprofile.backup" 2>/dev/null || true
cp "$HOME/.zshrc" "$HOME/.zshrc.backup" 2>/dev/null || true
grep -nE 'homebrew|node@24|cargo|rustup|uv|docker|Visual Studio Code' "$HOME/.zprofile" "$HOME/.zshrc" 2>/dev/null
```

다음과 같이 이 문서를 따라 추가한 줄만 편집기로 제거합니다.

```text
eval "$(/opt/homebrew/bin/brew shellenv)"
eval "$(/usr/local/bin/brew shellenv)"
export PATH="$(brew --prefix node@24)/bin:$PATH"
source "$HOME/.cargo/env"
```

Homebrew를 유지한다면 Homebrew `shellenv` 줄도 유지합니다. 다른 설정을 함께 지우지 않습니다.

심볼릭 링크 확인:

```zsh
find /usr/local/bin -maxdepth 1 -type l -lname '*Visual Studio Code*' -print 2>/dev/null
find /opt/homebrew/bin -maxdepth 1 -type l \( -name 'node*' -o -name 'pnpm*' -o -name 'uv*' \) -print 2>/dev/null
```

Homebrew가 관리하는 링크는 `brew uninstall`이 정리하게 둡니다. 대상이 없는 고아 링크임을 `ls -l`로 확인한 경우에만 링크 하나를 삭제합니다.

새 Terminal에서 최종 확인합니다.

```zsh
command -v git uv node npm pnpm rustup rustc cargo docker code
printf '%s\n' "$PATH" | tr ':' '\n'
```

---

## 10. 문제 해결

### 설치 후 명령을 찾지 못함

Terminal/PowerShell을 닫고 새로 연 뒤 실제 명령 위치와 PATH를 확인합니다. 설치 프로그램의 PATH 변경은 이미 열린 셸에 바로 반영되지 않을 수 있습니다.

### Windows에서 `python`이 Microsoft Store를 엶

Windows App Execution Alias나 기존 pyenv/Conda가 `python`을 가로챌 수 있습니다. 시스템 파일을 삭제하지 말고 프로젝트에서는 uv가 선택한 Python을 사용합니다.

```powershell
uv run --python 3.11 python --version
uv python find 3.11
```

### Docker API 연결 오류

CLI 설치와 Docker 엔진 실행은 별개입니다. Docker Desktop 앱을 시작한 후 `docker info`의 Server 정보를 확인합니다.

### macOS의 Arm64/x64 혼합

```zsh
uname -m
file "$(command -v node)"
file "$(command -v uv)"
```

Apple Silicon에서는 특별한 이유 없이 Intel Homebrew(`/usr/local`)와 Apple Silicon Homebrew(`/opt/homebrew`)를 동시에 사용하지 않습니다.

---

## 11. 코딩 에이전트용 프롬프트

```text
이 저장소의 README.md를 개발환경 설치와 제거의 유일한 기준으로 사용하세요.

1. 먼저 운영체제, 버전, CPU 아키텍처, 설치 도구, 실제 명령 경로, PATH를 읽기 전용으로 확인하세요.
2. Windows와 macOS 중 현재 운영체제의 섹션만 사용하세요. macOS에는 .NET을 설치하지 마세요.
3. 이미 정상 설치된 도구는 제거하거나 재설치하지 마세요.
4. 명령은 한 번에 하나씩 실행하고 매 단계 버전과 종료 결과를 보고하세요.
5. 실패하면 즉시 중단하고 원인과 안전한 다음 조치를 설명하세요.
6. 관리자 권한, 재부팅, 라이선스 동의, PATH 또는 shell profile 변경, 데이터 삭제 전에 사용자 승인을 받으세요.
7. 기존 Python, Conda, pyenv, .NET Runtime, Docker 데이터, VS Code 사용자 데이터를 임의로 삭제하지 마세요.
8. Python 프로젝트는 uv와 Python 3.11을 사용하고 전역 pip 설치를 피하세요.
9. 공식 문서의 현재 요구사항이 README 기준일 이후 변경되었는지 확인하고 차이가 있으면 실행 전에 알리세요.
10. 제거할 때는 package manager 제거, 잔여 경로 확인, PATH/profile/link 확인 순서를 지키세요.
11. 디렉터리나 Docker/WSL 데이터를 재귀 삭제하기 전에 정확한 절대 경로와 백업 여부를 사용자에게 보여주고 다시 승인받으세요.
12. 상태를 변경하는 smoke test는 별도 승인을 받은 뒤 실행하세요.
```

## 12. 공식 참고 자료

- [Microsoft WinGet](https://learn.microsoft.com/windows/package-manager/winget/)
- [.NET on Windows](https://learn.microsoft.com/dotnet/core/install/windows)
- [Visual Studio workload and component IDs](https://learn.microsoft.com/visualstudio/install/workload-and-component-ids?view=visualstudio)
- [Python downloads](https://www.python.org/downloads/)
- [uv installation](https://docs.astral.sh/uv/getting-started/installation/)
- [uv environments](https://docs.astral.sh/uv/pip/environments/)
- [pnpm installation](https://pnpm.io/installation)
- [Rust installation](https://rust-lang.org/tools/install/)
- [Docker Desktop for Windows](https://docs.docker.com/desktop/setup/install/windows-install/)
- [Docker Desktop for macOS](https://docs.docker.com/desktop/setup/install/mac-install/)
- [Docker Desktop uninstall](https://docs.docker.com/desktop/uninstall/)
- [VS Code CLI](https://code.visualstudio.com/docs/configure/command-line)
- [Homebrew](https://brew.sh/)
- [Homebrew Formulae](https://formulae.brew.sh/)

## 13. 저장소 이력

기존 자동 설치·제거 스크립트 실험본은 로컬 Git 브랜치 `archive/script-automation-2026-08-26`의 커밋 `e4a1d7a`에 보관했습니다. 현재 `main`은 이 문서만 관리합니다.
