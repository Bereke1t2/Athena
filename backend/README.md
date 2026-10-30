# Athena Backend

Go 1.26 Clean Architecture modular monolith powering Athena's API and background ingestion workers.
See architectural details in [`docs/architecture/backend.md`](../docs/architecture/backend.md).

---

## Architecture Layout

```text
cmd/
  api/            # REST API server & composition root (HTTP, SSE chat, RFC-7233 audio)
  worker/         # River queue background worker (sync, RAG indexing, push fanout)
  migrate/        # Standalone database migration runner binary
  searchbench/    # Golden query search relevance benchmark suite
internal/
  domain/         # Pure entities & port interfaces (zero external dependencies)
    audio/        # Synthesizer & MediaStore ports, audio brief models
    notification/ # PushSender interface & notification entities
    taxonomy/     # Canonical field classifier & arXiv prefix matcher
  application/    # Use cases, RAG chunking, audio brief generation, auth logic
  infrastructure/ # Concrete adapters: PostgreSQL, Redis, River, Gemini/OpenAI, FCM, APNs
    ai/tts/       # OpenAI TTS & Mock MPEG-1 Layer 3 speech synthesis adapters
    push/         # FCM HTTP v1, APNs HTTP/2, and multi-platform router
  platform/       # Cross-cutting: config, slog structured logging, HTTP server kit, CORS
  delivery/http/  # REST handlers, SSE streaming, byte-range streaming, middleware suite
migrations/       # Numbered SQL migration pairs (golang-migrate)
```

---

## Core Capabilities

- **Federated Ingestion**: Concurrent fanout to arXiv, Semantic Scholar, OpenAlex, and Crossref with automatic taxonomy classification and deduplication.
- **Hybrid RAG & Chat**: 768-dimension vector search via `pgvector` HNSW index + FTS RRF fusion, with streaming SSE grounded Q&A and citation enforcement.
- **Audio Studio**: AI brief generation and RFC-7233 partial content HTTP audio streaming (`GET /api/v1/research/papers/{id}/audio/stream`, `Accept-Ranges: bytes`, `206 Partial Content`).
- **Push Notification Gateway**: Multi-platform delivery via Firebase Cloud Messaging (FCM HTTP v1) and Apple Push Notification service (APNs HTTP/2).
- **Security & Protocol Middlewares**: Inbound sliding-window rate limiting (`X-RateLimit-*`), `Idempotency-Key` deduplication with cached response replay (`X-Cache-Lookup: HIT`), weak ETag caching (`304 Not Modified`), and CORS handling.

---

## Local Development Commands

```bash
# Start local Postgres and Redis
make -C .. up

# Apply database migrations
make -C .. migrate-up

# Start HTTP REST API on :8080
go run ./cmd/api

# Start background River worker
go run ./cmd/worker

# Build all binaries
go build ./...

# Run unit and application tests
go test -count=1 ./...

# Run integration tests (requires Docker testcontainers)
go test -tags=integration ./tests/integration/...
```

---

## Architectural Rules

1. **Dependency Inversion**: Handlers remain thin; business rules live in `application` and `domain`.
2. **Framework-Free Domain**: `internal/domain` depends on standard library types only.
3. **Storage Isolation**: All SQL queries live in repository implementations under `internal/infrastructure/database`.
4. **Environment Parity**: Any new environment variable must be added to `.env.example`, `docs/environment.md`, and `config.go`.
