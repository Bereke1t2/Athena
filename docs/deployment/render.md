# Deploying Athena on Render with Neon PostgreSQL

Athena backend consists of:
1. **`athena-api`**: The Go REST API web service (HTTP endpoints, SSE streaming chat, auth, discovery).
2. **`athena-worker`**: The River queue background worker (ingestion pipelines, RAG indexing, digest generation, notification fanout).
3. **Database**: [Neon](https://neon.tech) Serverless PostgreSQL (supports `pgvector` out-of-the-box).
4. **Cache (Optional)**: Redis instance for search caching and rate limiting.

---

## Step 1: Create your Neon Database

1. Sign up / log in to [Neon Console](https://console.neon.tech/).
2. Create a new project (e.g. `athena`).
3. In the project dashboard under **Connection details**:
   - Select **Direct connection** (preferred for persistent workers).
   - Copy the connection string:
     ```text
     postgresql://[user]:[password]@[endpoint].neon.tech/neondb?sslmode=require
     ```
   *(Note: Neon natively supports `pgvector` and `pg_trgm`, which Athena's migrations enable automatically).*

---

## Step 2: Deploy on Render

### Method 1: Automated Blueprint Deployment (Recommended)

1. Log in to your [Render Dashboard](https://dashboard.render.com/).
2. Click **New +** and select **Blueprint**.
3. Connect your repository: `Bereke1t2/Athena`.
4. Render will parse `render.yaml` and discover:
   - Web Service (`athena-api`) with pre-deploy migrations
   - Background Worker (`athena-worker`)
5. In the configuration preview, fill in:
   - **`ATHENA_DATABASE_URL`**: Paste your Neon PostgreSQL connection string.
   - **`GEMINI_API_KEY`**: Paste your Google AI Studio API key.
   - **`OPENALEX_MAILTO`**: Your email address (e.g. `yourname@gmail.com`) for polite pool access.
6. Click **Apply**. Render will automatically run migrations via `preDeployCommand: ./bin/migrate`, build the binaries, and start both services.

---

### Method 2: Manual Web Service Setup

If you prefer configuring the Web Service manually on Render:

1. Click **New +** ➔ **Web Service**.
2. Connect the `Athena` repository.
3. Configure the fields:
   - **Root Directory**: `backend`
   - **Runtime**: `Go`
   - **Build Command**: `go build -o bin/api ./cmd/api && go build -o bin/migrate ./cmd/migrate`
   - **Start Command**: `./bin/api`
   - **Pre-Deploy Command** *(under Advanced)*: `./bin/migrate`
   - **Health Check Path** *(under Advanced)*: `/healthz`
4. Environment Variables:
   ```env
   ATHENA_APP_ENV=production
   ATHENA_LOG_LEVEL=info
   ATHENA_LOG_FORMAT=json
   ATHENA_DATABASE_URL=postgresql://[user]:[password]@[endpoint].neon.tech/neondb?sslmode=require
   ATHENA_JWT_SECRET=<32+ character random string>
   ATHENA_ADMIN_TOKEN=<random secure token>
   LLM_PROVIDER=gemini
   LLM_MODEL=gemini-3.5-flash-lite
   GEMINI_API_KEY=<your-google-ai-studio-api-key>
   EMBEDDING_PROVIDER=none
   EMBEDDING_DIM=1536
   OPENALEX_MAILTO=<your-email@example.com>
   ```

*(Repeat step 2 for a **Background Worker** with start command `./bin/worker` if you want continuous paper ingestion).*
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
