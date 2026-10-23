# Deploying Athena on Render

Athena backend consists of:
1. **`athena-api`**: The Go REST API web service (HTTP endpoints, SSE streaming chat, auth, discovery).
2. **`athena-worker`**: The River queue background worker (ingestion pipelines, RAG indexing, digest generation, notification fanout).
3. **`athena-db`**: PostgreSQL 16 database with the `vector` (`pgvector`) extension enabled.
4. **`athena-redis`**: Redis instance for search caching and rate limiting.

---

## Method 1: Automated Blueprint Deployment (Recommended)

Athena includes a `render.yaml` Blueprint file at the repository root.

1. Log in to your [Render Dashboard](https://dashboard.render.com/).
2. Click **New +** and select **Blueprint**.
3. Connect your repository: `Bereke1t2/Athena`.
4. Render will parse `render.yaml` and discover:
   - PostgreSQL Database (`athena-db`)
   - Web Service (`athena-api`) with pre-deploy migrations
   - Background Worker (`athena-worker`)
5. In the configuration preview:
   - Enter your **`GEMINI_API_KEY`** (from [Google AI Studio](https://aistudio.google.com/apikey)).
   - Enter your **`OPENALEX_MAILTO`**: Literally just your email address (e.g. `yourname@gmail.com`). No registration or API key required; OpenAlex uses it to grant you polite pool access (10 req/sec) and notify you of any issues.
   - (Optional) Enter **`SEMANTICSCHOLAR_API_KEY`** if available.
6. Click **Apply**. Render will automatically provision the database, run migrations via `preDeployCommand: ./bin/migrate`, build the binaries, and start both services.

---

## Method 2: Manual Service Setup

If you prefer provisioning services manually:

### 1. PostgreSQL Database
- Click **New +** -> **PostgreSQL**.
- Name: `athena-db`
- Database: `athena`
- User: `athena`
- Version: `16`
- **Important**: Render PostgreSQL standard instances include `pgvector`. The migration scripts automatically run `CREATE EXTENSION IF NOT EXISTS vector;`.

### 2. Redis Instance
- Provision a Redis instance on Render or use an external managed Redis (e.g., Upstash or Redis Cloud).
- Note down the `host:port` address.

### 3. Web Service (`athena-api`)
- Click **New +** -> **Web Service**.
- Connect the `Athena` repository.
- Root Directory: `backend`
- Runtime: `Go`
- Build Command: `go build -o bin/api ./cmd/api && go build -o bin/migrate ./cmd/migrate`
- Pre-Deploy Command: `./bin/migrate`
- Start Command: `./bin/api`
- Health Check Path: `/healthz`
- Environment Variables:
  ```env
  ATHENA_APP_ENV=production
  ATHENA_LOG_LEVEL=info
  ATHENA_LOG_FORMAT=json
  ATHENA_DATABASE_URL=<Internal Database URL from athena-db>
  ATHENA_REDIS_ADDR=<Redis host:port>
  ATHENA_JWT_SECRET=<32+ character random string>
  ATHENA_ADMIN_TOKEN=<random secure token>
  LLM_PROVIDER=gemini
  LLM_MODEL=gemini-2.0-flash
  GEMINI_API_KEY=<your-google-ai-studio-api-key>
  EMBEDDING_PROVIDER=none
  EMBEDDING_DIM=1536
  OPENALEX_MAILTO=<your-email@example.com>
  ```
  *(Note: Render automatically sets `$PORT`. The Athena config automatically binds to `:$PORT` when `ATHENA_HTTP_ADDR` is omitted).*

### 4. Background Worker (`athena-worker`)
- Click **New +** -> **Background Worker**.
- Connect the `Athena` repository.
- Root Directory: `backend`
- Runtime: `Go`
- Build Command: `go build -o bin/worker ./cmd/worker`
- Start Command: `./bin/worker`
- Environment Variables:
  - Same `ATHENA_DATABASE_URL`, `ATHENA_REDIS_ADDR`, `OPENAI_API_KEY`, etc.
  - Set `ATHENA_WORKER_CONCURRENCY=4` and `ATHENA_INGESTION_ENABLED=true`.

---

## Verifying Deployment

Once deployed:
- Test the health endpoint: `https://<your-service>.onrender.com/healthz` (should return `{"status":"ok"}`).
- Test the readiness endpoint: `https://<your-service>.onrender.com/readyz` (verifies DB & Redis connections).
- Point your mobile app to the backend URL via:
  ```bash
  flutter run --dart-define=ATHENA_API_BASE_URL=https://<your-service>.onrender.com/api/v1
  ```
