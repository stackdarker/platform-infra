platform-infra

Local infrastructure for the platform (databases, caches, etc.).

Services included
- Postgres (auth-db)
- Redis

Quickstart (Git Bash)
1) cp .env.example .env
2) docker compose --env-file .env up -d
3) docker compose ps

Stop
- docker compose --env-file .env down

Reset data (DANGEROUS: deletes volumes)
- docker compose --env-file .env down -v
