# Backend Architecture (Go)

## 1. Layer contract

```text
            ┌──────────────────────────────────────────────┐
            │                delivery/http                 │  DTOs, middleware,
            │   (parse → usecase call → respond)           │  error mapping
            └──────────────────┬───────────────────────────┘
                               ▼
            ┌──────────────────────────────────────────────┐
            │                application                   │  Use cases, tx
            │   (orchestration; owns ports usage)          │  boundaries
            └──────────────────┬───────────────────────────┘
                               ▼
            ┌──────────────────────────────────────────────┐
            │                  domain                      │  Entities, value
            │   (pure Go; defines ports it needs)          │  objects, errors
            └──────────────────────────────────────────────┘
                               ▲ implements ports
            ┌──────────────────────────────────────────────┐
            │               infrastructure                 │  postgres, redis,
            │                                              │  providers/, ai/,
            └──────────────────────────────────────────────┘  workers/
```

Hard rules:

1. `domain` imports nothing from other layers — only stdlib.
2. `application` imports `domain` only.
3. `infrastructure` may import `domain`/`application` (to implement their
   ports); never the reverse.
4. `delivery` may import `application`; never `infrastructure`.
5. Wiring happens once in `cmd/*/main.go` (composition root).

## 2. Domain packages

| Package | Key types (finalized Phase 1+) |
|---|---|
| `domain/research` | `Paper`, `AuthorRef`, `Version`, `SourceRecord`, `CitationEdge`, `ResearchProvider`, `PaperRepository`, dedup fingerprint logic |
| `domain/author` | `Author`, identity-resolution policy |
| `domain/topic` | `Topic` hierarchy, slug rules |
| `domain/search` | `Query`, `QueryMode`, `ResultPage`, `Searcher`, `Filters` |
| `domain/ai` | `SummaryRequest/Result`, `ExplanationLevel`, `LLMProvider`, `EmbeddingProvider`, `ChunkRepository` |
| `domain/user`, `domain/bookmark` | accounts, bookmarks, follows (Phase 5 types now, implemented later) |
| `domain/notification` | `Notification`, channel port |

Domain errors are sentinel values (`var ErrNotFound = errors.New("research: not found")`)
so delivery maps them centrally without type assertions sprinkled around.

## 3. Application services

One service per context action cluster, constructor-injected with interfaces:

```go
type SearchService struct {
    papers domain.PaperRepository
    searcher domain.Searcher
    cache CachePort
}
func (s *SearchService) Handle(ctx context.Context, q domain.Query) (domain.ResultPage, error)
```

Responsibilities: validation beyond syntactic checks, orchestration,
transaction boundaries (`TxManager` port), cache strategy, emitting metrics.
No SQL, no HTTP, no provider URLs.

## 4. Infrastructure packages

| Package | Contents |
|---|---|
| `infrastructure/database` | pgx pool wiring, `TxManager`, repositories per context, migration runner helper |
| `infrastructure/cache` | Redis client, key builders, TTL policies, graceful no-op fallback |
| `infrastructure/providers/<name>` | HTTP client + DTO structs + normalizer per vendor; token-bucket limiter; circuit breaker |
| `infrastructure/ai/openaicompat` | LLM/embedding adapters (ADR-0004) |
| `infrastructure/workers` | River job definitions & handlers: sync windows, enrichment, embedding, reindex |

Provider adapter shape:

```text
providers/openalex/
├── client.go      # transport, auth/polite pool, retries, rate limit
├── dto.go         # wire structs with json tags mirroring OpenAlex
├── normalizer.go  # dto → domain.NormalizedPaper (validation included)
└── fixtures/      # recorded responses for contract tests
```

## 5. Delivery layer

- Router built in `delivery/http/router.go`: `/healthz`, `/readyz`, `/metrics`,
  `/api/v1/*` groups.
- Middleware order: RequestID → RealIP → Logger → Recoverer → CORS → RateLimit
  → Auth (Phase 5) → handler.
- Handlers receive plain request structs, return `(any, error)` via small
  helpers; a single `httperror.Map(err)` renders the error envelope.
- DTOs are explicit structs (no reflection magic), validated before calling
  application.

## 6. Configuration & lifecycle

- `platform/config`: env-only, typed, defaults for dev, strict parse.
- Graceful shutdown: SIGTERM → stop accepting → drain in-flight (timeout
  `ATHENA_SHUTDOWN_TIMEOUT`) → close pool/cache/queue.
- Health: `/healthz` liveness (process up), `/readyz` readiness (DB ping,
  Redis ping, queue reachable).
