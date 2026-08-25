# Windows Development Environment

Reproducible Windows development environment for ASP.NET, Rust, Python,
web development, AI/ML, and local infrastructure.

## Toolchain

- Python 3.11
- ASP.NET / .NET SDK 6, 8, 10
- Rust stable-msvc
- Node.js LTS
- Git
- uv
- Tauri CLI
- Docker Desktop
- Visual Studio 2022 Build Tools
- Lite XL
- LPM

## Python CLI tools

Defined in `manifest/python-tools.txt`:

- ruff
- pyright
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
for or apply an available upgrade.

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
- Docker volumes
- PostgreSQL data

Docker Desktop and Visual Studio Build Tools are kept by default.

The separately installed `uv` executable is not removed by this script.

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

The environment removal script never runs `docker compose down -v`.
PostgreSQL, Redis, and MinIO volumes are considered project data rather than
machine-wide tool installations.
