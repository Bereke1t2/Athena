# Athena — Architecture Overview

> Discover. Understand. Question. Connect.

## 1. System context

Athena is a two-application system backed by shared services:

```text
┌────────────────┐        ┌─────────────────────────────────────────────┐
│  Flutter app   │◀──REST▶│              Go Backend (/api/v1)           │
│  iOS / Android │        │  ┌─────────┐ ┌─────────┐ ┌───────────────┐  │
└────────────────┘        │  │   API   │ │ Workers │ │ AI/RAG engine │  │
                          │  └────┬────┘ └────┬────┘ └───────┬───────┘  │
                          └───────┼───────────┼──────────────┼──────────┘
                                  ▼           ▼              ▼
                            PostgreSQL     Redis      LLM/Embedding APIs
                          (system of record) (cache)   (provider-agnostic)
                                  ▲
                    Semantic Scholar · OpenAlex · arXiv   (+ future providers)
```

Design posture: **modular monolith** (ADR-0001). One Go codebase, two binaries
(`api`, `worker`), strict internal layering. No premature microservices; every
architectural boundary is an interface, so extraction later is mechanical if
scale demands it.

## 2. Bounded contexts

| Context | Owns | Notes |
|---|---|---|
| research | papers, authors, topics, citations, versions, sources | Core bibliographic domain |
| search | query parsing, ranking, hybrid retrieval | Behind `Searcher` port |
| ingestion | provider sync, normalization, dedup, jobs | Worker-side heavy lifting |
| ai | summaries, embeddings orchestration, RAG retrieval | Behind LLM/Embedding ports |
| chat | sessions, messages, grounded answer assembly | Depends on ai + research |
| recommendation | feed ranking, related-work signals | Simple heuristics → ML later |
| notification | notification records, fan-out | Channel adapters later (push/email) |
| user/bookmark | accounts (Phase 5), bookmarks, follows | Auth lands Phase 5 |

Cross-context calls go through application services or domain ports — never by
reaching into another context's storage layer.

## 3. Repository layout (annotated)

```text
Athena/
├── README.md                  Project front door
├── docker-compose.yml         postgres(pgvector), redis, api, migrate
├── .env.example               All local configuration, documented
├── Makefile                   up/down/migrate/build/test entry points
│
├── docs/
│   ├── adr/                   Architecture Decision Records (0001–0010)
│   ├── architecture/          This suite: overview/backend/mobile/providers/…
│   ├── api/                   REST specification
│   ├── database/              Schema documentation
│   ├── conventions/           Coding standards per stack
│   ├── environment.md         Every env var explained
│   └── roadmap.md             Phased delivery plan w/ acceptance criteria
│
├── backend/
│   ├── cmd/api/               HTTP API binary
│   ├── cmd/worker/            Background worker binary
│   ├── internal/
│   │   ├── domain/            Entities + ports. Zero external imports.
│   │   ├── application/       Use cases; transaction boundaries.
│   │   ├── infrastructure/    postgres, redis, providers/, ai/, workers/
│   │   ├── platform/          config, logger, httpserver kit (cross-cutting)
│   │   └── delivery/http/     v1 handlers, middleware, DTOs, error mapping
│   ├── migrations/            golang-migrate SQL pairs
│   ├── configs/               config templates
│   ├── scripts/               dev helpers
│   ├── tests/integration/     testcontainers-based integration tests
│   └── Dockerfile             multi-stage build → one image, two commands
│
└── mobile/
    ├── lib/core/              constants, error, network, routing, theme, utils
    ├── lib/features/<f>/      data/ domain/ presentation/ per feature
    ├── test/                  unit + widget tests
    └── pubspec.yaml
```

### Deviations from the originally suggested structure (and why)

1. **Added `internal/platform/`** — the suggested tree had no home for config,
   logging, and server bootstrap; without it these leak into `delivery` or
   `infrastructure` where they don't belong.
2. **`paper_identifiers` / `author_identifiers` tables instead of only columns**
   — deduplication requires a registry of *all* known external IDs per paper,
   not just the "primary" ones.
3. **Merged `paper_embeddings` into `chunk_embeddings`** keyed by
   `(chunk_id, model_id)` — supports re-embedding with new models without
   duplicating chunk text; single join path.
4. **River job queue inside Postgres instead of a separate broker** — see
   ADR-0006.
5. **`docs/conventions/` split per stack** — backend and mobile rules evolve on
   different cadences.

## 4. Key runtime flows (summary)

Full diagrams in [`data-flow.md`](data-flow.md):

- **Ingestion:** scheduler → provider adapter (rate-limited) → normalizer →
  deduplicator → Postgres transaction {upsert paper+provenance} → enqueue
  enrichment/embedding jobs → search index refresh.
- **Search:** Flutter → GET /search → Searcher port → FTS ± pgvector hybrid →
  fused ranked page.
- **AI summary:** cache check (content-hash keyed) → RAG context build →
  versioned prompt → LLM → persisted structured summary with provenance.
- **Chat:** session → question embedding → chunk retrieval (top-k) → budgeted
  context → grounded generation with citations streamed via SSE.

## 5. Cross-cutting concerns

| Concern | Approach |
|---|---|
| Configuration | Env vars only (`ATHENA_*` prefix), parsed in `platform/config`; fail fast on invalid |
| Logging | `log/slog` JSON; request ID injected by middleware; worker logs carry job IDs |
| Metrics | Prometheus `/metrics`: HTTP RED metrics, provider call counters/errors, queue depth, LLM token usage |
| Errors | Domain sentinel errors → mapped once to HTTP problem envelope at delivery edge |
| Security | Secrets never leave backend; JWT auth (Phase 5); admin endpoints behind admin token; rate limiting per IP+user |
| Testing | Unit tests per layer with fakes; integration tests via testcontainers; contract fixtures per provider |

## 6. Document map

| Document | Content |
|---|---|
| [backend.md](backend.md) | Layer-by-layer backend design |
| [mobile.md](mobile.md) | Flutter architecture |
| [research-providers.md](research-providers.md) | Provider contracts, rate limits, normalization & dedup rules |
| [ingestion-pipeline.md](ingestion-pipeline.md) | Pipeline stages, workers, idempotency, incremental sync |
| [search.md](search.md) | Search stages, ranking formula, upgrade triggers |
| [ai-rag.md](ai-rag.md) | Summaries, explanation levels, RAG, grounding policy |
| [data-flow.md](data-flow.md) | End-to-end sequence flows |
