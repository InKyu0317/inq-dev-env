# Windows Development Environment

Reproducible Windows development environment for ASP.NET, Rust, Python,
web development, AI/ML, and local infrastructure.

## Toolchain

- Python 3.11
- ASP.NET / .NET SDK 6, 8, 10
- Rust stable-msvc
- Node.js LTS
- Git
- uv (WinGet: `astral-sh.uv`)
- Tauri CLI
- Docker Desktop
- Visual Studio 2022 Build Tools
- Visual Studio Code Stable

## Python CLI tools

Defined in `manifest/python-tools.txt`:

- ruff
- pytest
- ipython
- pre-commit

Project libraries are deliberately not installed globally.

For a project:

```powershell
uv init
uv python pin 3.11
uv add glasspy
uv add numpy scipy pandas
uv add torch
uv sync
```

Commit `pyproject.toml` and `uv.lock`.

For projects that must use a specific .NET SDK, add `global.json` to the
project root:

```json
{
  "sdk": {
    "version": "6.0.4xx",
    "rollForward": "latestFeature"
  }
}
```

The development environment installs .NET SDK 6, 8, and 10 side by side.
Use `global.json` when a project must build with a specific SDK family.

## Setup

Run Windows PowerShell 5.1 as Administrator:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\dev_env_setup.ps1
```

The script can be rerun. If a package is already installed, WinGet may check
for or apply an available upgrade. A message such as `No available upgrade
found` is a normal result and does not indicate a failure.

The setup menu runs these steps independently:

```text
1.  Environment check
2.  WinGet package installation and PATH registration
3.  VS Code extensions
4.  uv installation and verification
5.  Python CLI tools
6.  Node.js / pnpm
7.  Rust
8.  Tauri CLI
9.  Development directories
10. Docker check
11. .NET SDK and runtime listing
0.  Exit
```

The WinGet step installs Visual Studio Code Stable and registers its command
line directory in the user PATH. Open a new PowerShell window after setup,
then run:

```powershell
code .
```

The VS Code extension step installs the extensions listed in
`manifest/vscode-extensions.txt`. Python uses Pylance for language analysis;
BasedPyright and the Pyright CLI are not installed by this environment.

## Visual Studio Code editions

For this environment, the standard Visual Studio Code Stable build is used.
VS Code also provides User setup, System setup, and ZIP/portable installation
methods. The User setup is intended for one Windows account and usually does
not require administrator privileges. The System setup is for all users and
requires administrator privileges.

Visual Studio Code Insiders is a separate preview build with daily updates.
It can be installed alongside Stable, but it is not included in this setup.

## Remove

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\dev_env_remove.ps1
```

The script requires typing `REMOVE`.

It does not delete:

- `~/dev`
- source code
- Python virtual environments

Docker Desktop and Visual Studio Build Tools are removed by default by the
current script settings.

The removal script also removes VS Code user data by default:

- `%USERPROFILE%\.vscode`
- `%APPDATA%\Code\User`

This removes extensions, VS Code CLI data, settings, keybindings, and
snippets. Project-level `.vscode` folders inside source repositories are not
removed.

Warning: uninstalling Docker Desktop can destroy local containers, images,
named volumes, and other Docker data. Back up important volumes before
running the removal script. The script does not run `docker compose down -v`
directly, but Docker Desktop uninstallation itself can remove Docker data.

The removal script also removes `uv`, `uvx`, and `uvw` binaries from
the standard Windows locations `%USERPROFILE%\.local\bin`,
`%USERPROFILE%\.cargo\bin`, and the WinGet links directory. It also removes uv
cache data, uv-managed Python installations, and uv tool environments. Project
`.venv` directories are not removed.

## Docker / local infrastructure

Compose templates are provided for:

- PostgreSQL 17
- Redis 8
- MinIO

Create the local Docker environment file from the example:

```powershell
Copy-Item docker/.env.example docker/.env
```

Change the local passwords in `docker/.env` before starting the services.
The file is ignored by Git.

Start PostgreSQL:

```powershell
docker compose --env-file docker/.env -f docker/postgres/compose.yml up -d
```

Stop it without deleting data:

```powershell
docker compose --env-file docker/.env -f docker/postgres/compose.yml down
```

PostgreSQL connection:

```text
Host=localhost
Port=5432
Database=dev
Username=postgres
Password=the value of POSTGRES_PASSWORD in docker/.env
```

Start Redis:

```powershell
docker compose --env-file docker/.env -f docker/redis/compose.yml up -d
```

Redis uses the password stored in `REDIS_PASSWORD` in `docker/.env`.

Start MinIO:

```powershell
docker compose --env-file docker/.env -f docker/minio/compose.yml up -d
```

MinIO endpoints:

```text
S3 API: http://localhost:9000
Console: http://localhost:9001
Username: the value of MINIO_ROOT_USER in docker/.env
Password: the value of MINIO_ROOT_PASSWORD in docker/.env
```

For ASP.NET/.NET:

```text
ASP.NET Core
     |
EF Core / Dapper
     |
   Npgsql
     |
PostgreSQL
```

## Possible application architectures

The environment intentionally supports multiple future choices.

### C# + Python

```text
ASP.NET Core / Blazor
        |
        +-- C# services
        +-- Device Manager
        +-- PostgreSQL / Npgsql
        |
        +-- IPC
              |
              +-- Python worker
                    +-- GlassPy
                    +-- PyTorch
```

### Rust + Python

```text
Tauri
  |
  +-- Rust application
  |
  +-- IPC
        |
        +-- Python worker
              +-- GlassPy
              +-- PyTorch
```

Both toolchains are installed intentionally so the architecture can be
chosen later without rebuilding the development machine.

## GlassPy

GlassPy is intentionally not a machine-wide package.

The current GlassPy release requires Python 3.11 or later, so GlassPy
projects should use Python 3.11 or newer in their project environment.

Install it only in projects that need it:

```powershell
uv add glasspy
uv sync
```

This keeps project dependencies and GlassPy's licensing concerns separate
from the base development environment.

## Docker data policy

The removal script does not directly run `docker compose down -v`.
However, the current removal settings uninstall Docker Desktop, and Docker
Desktop uninstallation can remove local containers, images, and volumes.
Back up PostgreSQL, Redis, and MinIO data before running the removal script.
