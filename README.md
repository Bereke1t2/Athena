# Athena

> **Discover. Understand. Question. Connect.**

Athena is an AI-powered research discovery and learning platform. It helps users
discover, search, understand, discuss, and connect scientific research and
philosophical articles — with AI that is grounded in the actual content of the
papers, not speculation.

| | |
|---|---|
| **Backend** | Go (Clean Architecture, REST) |
| **Mobile** | Flutter / Dart (Clean Architecture) |
| **Database** | PostgreSQL 16 (+ pgvector for embeddings) |
| **Cache / Rate limiting** | Redis 7 |
| **Background jobs** | River (PostgreSQL-backed job queue) |
| **Research sources** | Semantic Scholar, OpenAlex, arXiv (provider-pluggable) |
| **AI** | Provider-agnostic LLM + Embedding abstractions with a RAG pipeline |

---

## Vision

Academic knowledge is abundant but inaccessible. Papers are locked behind
jargon, paywalls, and fragmented interfaces. Athena's goal is **not** to build
another search engine for PDFs. It is to build a learning companion around
research:

```text
Discover   →  see new, trending, and relevant research the moment it appears
Understand →  get explanations tuned to your level (beginner → expert)
Question   →  talk to the paper; get grounded, cited answers
Connect    →  related work, supporting and contradicting findings, citation graphs
```

Athena will eventually cover AI, computer science, physics, mathematics,
biology, medicine, psychology, neuroscience, philosophy, philosophy of mind,
cosmology, social sciences, economics, and more.

## Core Features

1. **Research discovery feed** — latest, trending, topic-based, field-based,
   personalized feeds.
2. **Search** — keyword *and* semantic search ("research about whether
   consciousness can emerge from artificial systems"), with filters (date,
   field, author, journal, open access, citations, source), sorting, relevance
   ranking, and pagination.
3. **Multi-provider aggregation** — metadata normalized and deduplicated from
   Semantic Scholar, OpenAlex, and arXiv behind a provider abstraction.
4. **AI research summaries** — TL;DR, simple explanation, academic explanation,
   key findings, methodology, results, limitations, why it matters — at four
   explanation levels.
5. **Chat with research** — grounded Q&A over a paper's actual content using
   RAG; the AI says "the paper doesn't say" instead of inventing.
6. **Paper comparison** — compare methodology, datasets, results, agreements,
   and contradictions across selected papers.
7. **Research connections** — related / builds-on / supports / contradicts
   relationships, foundation for citation graphs.
8. **Personalization** — bookmarks, followed topics/authors/fields,
   personalized feed and recommendations.
9. **Notifications** — alerts when new research appears in followed topics;
   channel architecture ready for push/email/in-app.

## Architecture

Full details live in [`docs/architecture/`](docs/architecture/overview.md).

### Backend (Go, Clean Architecture)

Strict dependency rule: `delivery → application → domain`; infrastructure
implements domain/application-defined ports. The domain layer depends on
nothing — no HTTP, no SQL, no external APIs.

```text
backend/
├── cmd/
│   ├── api/          # HTTP API server binary
│   └── worker/       # background worker binary
├── internal/
│   ├── domain/           # entities, value objects, ports (framework-free)
│   ├── application/      # use cases, orchestration, transaction boundaries
│   ├── infrastructure/   # Postgres, Redis, providers, LLM adapters, workers
│   ├── platform/         # cross-cutting: config, logging, HTTP server kit
│   └── delivery/http/    # REST handlers, middleware, DTOs
├── migrations/           # numbered SQL migrations (golang-migrate)
└── configs/
```

### Mobile (Flutter)

Feature-first Clean Architecture:

```text
mobile/lib/
├── core/               # constants, errors, network, routing, theme, utils
├── features/
│   └── <feature>/
│       ├── data/         # DTOs, API clients, repository implementations
│       ├── domain/       # entities, repository interfaces, use cases
│       └── presentation/ # screens, widgets, state (Riverpod)
└── main.dart
```

State management: Riverpod · Routing: go_router · HTTP: dio · Models:
freezed/json_serializable.

### Database

PostgreSQL is the single source of truth: canonical papers with multi-source
provenance (`paper_sources`), identifier registry for deduplication
(`paper_identifiers`), authors, hierarchical topics, citations, user data,
chat/AI artifacts, and the ingestion job queue. Schema:
[`docs/database/schema.md`](docs/database/schema.md).

### Research providers

`ResearchProvider` port in the domain layer; adapters for Semantic Scholar,
OpenAlex, and arXiv translate their payloads into Athena's internal models.
The application layer never knows which provider produced a paper.
Details: [`docs/architecture/research-providers.md`](docs/architecture/research-providers.md).

### Search

Start simple, scale later: PostgreSQL full-text search (weighted tsvector +
GIN) + trigram fuzzy matching now; pgvector embeddings for semantic search in
the AI phase; hybrid (keyword+semantic) ranking via Reciprocal Rank Fusion.
The engine sits behind a `Searcher` port so OpenSearch/Meilisearch can replace
it later without touching use cases.
Rationale: [`docs/architecture/search.md`](docs/architecture/search.md).

### AI / RAG

Provider-agnostic `LLMProvider` / `EmbeddingProvider` ports. Pipeline:
open-access text extraction → cleaning → section-aware chunking → embeddings
(pgvector) → hybrid retrieval → budgeted context assembly → grounded generation
with mandatory citations and refusal on insufficient evidence.
Details: [`docs/architecture/ai-rag.md`](docs/architecture/ai-rag.md).

### Workers

River-backed jobs on PostgreSQL: provider synchronization, enrichment,
embedding, indexing. Retry with exponential backoff, per-provider rate
limiting, circuit breakers, idempotent upserts, incremental cursors, job
status/metrics. Details:
[`docs/architecture/ingestion-pipeline.md`](docs/architecture/ingestion-pipeline.md).

## Technology Stack (and why)

| Choice | Why this, why not alternatives |
|---|---|
| **Go** | Static typing, first-class concurrency for ingestion workers, single static binaries, fast cold start. Node/Python rejected for weaker concurrency ergonomics at worker scale; Java/Kotlin for heavier footprint than needed. |
| **stdlib `net/http` router** | Go 1.22+ ServeMux covers method+wildcard routing needs of a versioned REST API with zero dependencies. chi/gin can be adopted later behind our middleware chain if needs grow (ADR-0007). |
| **PostgreSQL 16** | Relational integrity for bibliographic data, JSONB for raw provider payloads, built-in FTS/trigram, one datastore for queue + search + vectors reduces MVP operational surface (ADR-0003). |
| **pgvector** | Embeddings co-located with relational data; HNSW index scales to millions of chunks. Dedicated vector DBs (Qdrant/Milvus/Pinecone) deferred until scale demands (ADR-0005). |
| **Redis 7** | Hot-path caching (feed/search), distributed rate limiting. Not used as the primary queue (ADR-0006). |
| **River (job queue)** | Jobs enqueued *in the same Postgres transaction* as data writes — no lost enrichment jobs; retries/backoff/scheduling built in (ADR-0006). |
| **golang-migrate** | Plain SQL up/down migrations, widely used, CI-friendly (ADR-0009). |
| **log/slog** | Structured logging in the standard library; zero deps, JSON output, context propagation. |
| **Prometheus `/metrics`** | De-facto standard; workers and API expose counters/histograms for observability requirements. |
| **Flutter** | Single codebase for iOS/Android, strong typing, mature tooling; required by product constraints. |
| **Riverpod** | Compile-safe DI/state, testable without inherited widgets, scales from small to complex apps (ADR-0008). |

## Folder Structure

See [`docs/architecture/overview.md`](docs/architecture/overview.md) for the
annotated tree and the reasoning behind deviations from a generic layout.

Key directories:

```text
.
├── backend/          Go API + worker (Clean Architecture)
├── mobile/           Flutter app
├── docs/             architecture/, adr/, api/, database/, conventions/
├── docker-compose.yml  local infra + services
├── Makefile          common developer tasks
└── .env.example      template for local configuration
```

## System Data Flow

```text
Semantic Scholar   OpenAlex   arXiv            (future: Crossref, PubMed…)
        │             │          │
        └─────────────┴────┬─────┘
                 ResearchProvider adapters
                           ↓
              Fetch → Normalize → Deduplicate
                           ↓
                      PostgreSQL  ←──────── Ingestion/enrichment workers (River)
                           ↓                     ↑
              Search index (FTS + pgvector) ─────┘  (embedding pipeline)
                           ↓
                    Go REST API (/api/v1)
                           ↓
     Retrieval + LLM (RAG) for summaries & grounded chat
                           ↓
                    Flutter application
```

End-to-end flows: [`docs/architecture/data-flow.md`](docs/architecture/data-flow.md).

## Development Setup

### Requirements

- Go ≥ 1.26
- Flutter ≥ 3.41 (stable) with Dart ≥ 3.10
- Docker + Docker Compose v2
- Make (optional but recommended)

### Environment variables

Copy `.env.example` → `.env` and adjust. Every variable is documented in
[`docs/environment.md`](docs/environment.md). Never commit real secrets.

### Start infrastructure (Postgres, Redis)

```bash
make up            # or: docker compose up -d postgres redis
```

### Run database migrations

```bash
make migrate-up    # applies backend/migrations/*.up.sql via golang-migrate (dockerized)
```

### Run the backend API

```bash
cd backend
go run ./cmd/api           # serves http://localhost:8080 (GET /healthz)
```

### Run the backend worker

```bash
cd backend
go run ./cmd/worker        # Phase 1+: consumes River jobs (sync, enrich, embed)
```

### Run the Flutter app

```bash
cd mobile
flutter pub get
flutter create . --platforms=ios,android --org dev.athena   # once, to generate platform folders
flutter run
# point the app at the API with ATHENA_API_BASE_URL (see mobile/README.md)
```

## API Documentation

REST specification (resources, filters, pagination, errors, examples):
[`docs/api/api-specification.md`](docs/api/api-specification.md).

Conventions: base path `/api/v1`, JSON only, snake_case fields, cursor
pagination, RFC-7807-style error envelope, request IDs on every response.

## Testing

```bash
# Backend unit tests (no external services needed)
cd backend && go test ./...

# Backend integration tests (uses testcontainers; requires Docker)
cd backend && go test -tags=integration ./tests/integration/...

# API contract tests (httptest against the real router)
cd backend && go test ./internal/delivery/...

# Flutter tests
cd mobile && flutter test
```

Testing strategy per phase lives in
[`docs/conventions/backend-conventions.md`](docs/conventions/backend-conventions.md#testing-strategy).

## Architecture Principles

1. **Dependency rule** — domain knows nothing about delivery/infrastructure.
2. **Ports & adapters at every boundary** — providers, LLM, search, queues are interfaces owned by domain/application.
3. **Backend owns all intelligence** — search, ranking, RAG never live in Flutter.
4. **Grounded AI or no AI** — answers cite retrieved chunks; insufficient evidence ⇒ explicit refusal. Never fabricate papers, authors, results, or citations.
5. **Idempotency everywhere in ingestion** — natural-key upserts, replayable jobs, incremental cursors.
6. **Legal-first data policy** — store metadata freely; process full text only where licensed (ADR-0010).
7. **Simplest thing that satisfies requirements** — no microservices, no premature engines; documented upgrade paths instead.
8. **Observability is not optional** — structured logs, metrics, health/readiness endpoints from day one.

Engineering rules in detail:
[`docs/conventions/backend-conventions.md`](docs/conventions/backend-conventions.md) ·
[`docs/conventions/mobile-conventions.md`](docs/conventions/mobile-conventions.md)

Architecture Decision Records:
[`docs/adr/`](docs/adr/) — start at `0001-clean-architecture.md`.

## Roadmap

| Phase | Scope | Status |
|---|---|---|
| **0 — Architecture & Documentation** | Repo structure, ADRs, schema, API spec, Docker, conventions | ✅ current |
| **MVP (Phases 1–4)** | 1: Aggregation (providers→dedup→Postgres→API) · 2: Search & discovery · 3: Flutter foundation · 4: AI summaries + RAG chat | planned |
| **Phase 2 (product)** | Personalization: auth, bookmarks, follows, recommendations, notifications | planned |
| **Phase 3 (product)** | Advanced intelligence: comparison, citation graphs, support/contradiction detection, trends, digests | planned |
| **Future** | Additional providers (Crossref, PubMed, Europe PMC), alternative search engines, push/email channels, web client | vision |

Detailed roadmap with acceptance criteria:
[`docs/roadmap.md`](docs/roadmap.md).
