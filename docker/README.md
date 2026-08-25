# Local Docker Services

Docker Desktop is installed by the main setup script. These compose files
provide optional local services.

From the repository root, create the local environment file first:

```powershell
Copy-Item docker/.env.example docker/.env
```

Change the passwords in `docker/.env` before starting the services. The
`docker/.env` file is ignored by Git.

## PostgreSQL

```powershell
docker compose --env-file docker/.env -f docker/postgres/compose.yml up -d
```

Connection:

```text
Host=localhost
Port=5432
Database=dev
Username=postgres
Password=the value of POSTGRES_PASSWORD in docker/.env
```

Stop without deleting data:

```powershell
docker compose --env-file docker/.env -f docker/postgres/compose.yml down
```

Delete data intentionally:

```powershell
docker compose --env-file docker/.env -f docker/postgres/compose.yml down -v
```

## Redis

```powershell
docker compose --env-file docker/.env -f docker/redis/compose.yml up -d
```

Redis password: the value of `REDIS_PASSWORD` in `docker/.env`.

## MinIO

```powershell
docker compose --env-file docker/.env -f docker/minio/compose.yml up -d
```

S3 API: http://localhost:9000
Console: http://localhost:9001

Username: the value of `MINIO_ROOT_USER` in `docker/.env`  
Password: the value of `MINIO_ROOT_PASSWORD` in `docker/.env`

Do not use `down -v` unless the data should be deleted.
