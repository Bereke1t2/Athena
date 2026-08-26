# Environment Variables Reference

Configuration is environment-only (12-factor). Prefix `ATHENA_` is reserved
for app settings; provider variables keep their documented names. Copy
`.env.example` → `.env` for local development. Compose injects infra vars.

## Application

| Variable | Required | Default | Description |
|---|---|---|---|
| `ATHENA_APP_ENV` | no | `development` | `development`, `staging`, `production`. Affects log format and CORS strictness. |
| `ATHENA_HTTP_ADDR` | yes | `:8080` | Listen address for the API binary. |
| `ATHENA_SHUTDOWN_TIMEOUT` | no | `15s` | Graceful drain window on SIGTERM. |
| `ATHENA_LOG_LEVEL` | no | `info` | `debug`, `info`, `warn`, `error`. |
| `ATHENA_LOG_FORMAT` | no | `text` dev / `json` prod | Log encoding. |

## PostgreSQL

| Variable | Required | Default | Description |
|---|---|---|---|
| `ATHENA_DATABASE_URL` | yes | — | DSN, e.g. `postgres://athena:pw@localhost:5432/athena?sslmode=disable`. Use `sslmode=require`+real certs outside dev. |
| `ATHENA_DB_MAX_CONNS` | no | `20` | pgxpool max connections. Worker and API should share budget ≤ Postgres `max_connections`. |
| `POSTGRES_USER` / `POSTGRES_PASSWORD` / `POSTGRES_DB` / `POSTGRES_PORT` | compose | see `.env.example` | Container bootstrap values (compose interpolation). |

## Redis

| Variable | Required | Default | Description |
|---|---|---|---|
| `ATHENA_REDIS_ADDR` | yes | `localhost:6379` | Host:port. Cache layer degrades gracefully if unreachable (logged). |

## HTTP surface

| Variable | Required | Default | Description |
|---|---|---|---|
| `ATHENA_CORS_ALLOWED_ORIGINS` | yes (prod) | localhost set | Comma-separated allow-list. |

## Research providers

| Variable | Required | Default | Description |
|---|---|---|---|
| `SEMANTICSCHOLAR_API_KEY` | recommended | empty | Raises S2 limits from shared pool to keyed tier. |
| `OPENALEX_MAILTO` | recommended | empty | Contact email → OpenAlex polite pool (faster, fair). |
| `ARXIV_USER_AGENT` | recommended | athena default | UA including contact per arXiv etiquette. |

## Ingestion workers

| Variable | Required | Default | Description |
|---|---|---|---|
| `ATHENA_WORKER_CONCURRENCY` | no | `4` | Concurrent River jobs per worker process. |
| `ATHENA_INGESTION_ENABLED` | no | `true` (worker) | Kill switch for sync scheduling without redeploying. |

## AI (Phase 4)

| Variable | Required | Default | Description |
|---|---|---|---|
| `LLM_PROVIDER` | Phase 4 | `openai_compatible` | Selects adapter. |
| `LLM_BASE_URL` / `LLM_API_KEY` / `LLM_MODEL` | Phase 4 | see example | Endpoint/auth/model for generation. |
| `EMBEDDING_PROVIDER` / `EMBEDDING_MODEL` / `EMBEDDING_DIM` | Phase 4 | openai_compatible | Embedding adapter config; dim must match migration `000002`. |

## Auth & admin (Phase 5)

| Variable | Required | Default | Description |
|---|---|---|---|
| `ATHENA_JWT_SECRET` | Phase 5 | — | ≥32 bytes; rotate via dual-secret window later. |
| `ATHENA_ADMIN_TOKEN` | Phase 1 ops | — | Bearer token guarding `/admin/*` ingestion endpoints. |

## Mobile

The app reads no env vars at runtime; build-time injection:

```bash
flutter run --dart-define=ATHENA_API_BASE_URL=http://10.0.2.2:8080/api/v1
```

(`10.0.2.2` = host loopback from Android emulator.)
