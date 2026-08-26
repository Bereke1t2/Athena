# Backend Conventions (Go)

## Project layout

- Follow the layer map in `docs/architecture/backend.md`. New code goes in the
  bounded context it belongs to; never create "shared/utils" grab-bags.
- Package names: short, lowercase, no underscores; singular domain concepts
  (`research`, not `researchs`).
- One `doc.go` per package stating responsibility in ≤5 lines.

## Go style

- Formatting: `gofmt`/`goimports` — non-negotiable, enforced by CI.
- Lint: `golangci-lint` with repo config (lands Phase 1): enabled sets
  `errcheck`, `govet`, `staticcheck`, `revive`, `depguard` (layer rules),
  `gocritic`.
- Errors:
  - Wrap with context: `fmt.Errorf("fetch window %s-%s: %w", from, to, err)`.
  - Sentinel errors in domain (`ErrNotFound`, `ErrInvalidInput`); delivery maps
    them centrally.
  - Never `_ = err`; never panic across package boundaries.
- Context: first parameter everywhere; use cases accept and propagate;
  handlers derive from `r.Context()`.
- Interfaces are defined **where consumed** (domain/application), implemented
  in infrastructure. Keep them small (1–3 methods) unless proven necessary.
- Constructors `NewX(...)`, returning concrete types; options pattern only
  when ≥4 optional params.
- No init() functions outside cmd wiring.

## Naming

| Thing | Rule | Example |
|---|---|---|
| Files | snake_case | `paper_repository.go` |
| Tests | same file + `_test.go` | `fingerprint_test.go` |
| DTOs | `<Resource>Request/Response` | `SearchResponse` |
| Tables/repos | plural tables, singular repos | `papers` / `PaperRepository` |

## Database access

- Hand-written SQL inside repository implementations; queries live next to
  their repo as constants or embedded `.sql` (sqlc adoption revisited at
  Phase 1 review).
- Always pass `ctx` into pgx calls.
- Writes that span tables run through `TxManager` port — never open raw tx in
  use cases.
- Migrations only via `backend/migrations` (ADR-0009). Never ALTER from app
  code.

## HTTP handlers

- Signature style: small structs per route group with deps injected; register
  via `RegisterRoutes(mux, deps)`.
- Parse → validate → call use case → respond. Handlers stay < ~60 lines;
  extract mappers when larger.
- Responses built exclusively through helpers in `delivery/http/v1/respond.go`
  so envelope/headers stay consistent.

## Configuration & secrets

- Env vars prefixed `ATHENA_` (providers keep their documented names);
  parsed once in `platform/config`.
- Secrets come only from environment; never logged, never defaulted in code.

## Logging & metrics

- `log/slog` JSON in prod, text allowed locally; logger passed explicitly or
  via context helper.
- Log user data minimally; never log tokens/keys/full abstracts at info level.
- Counters/histograms added alongside the code that emits them; metric names
  follow `athena_<area>_<thing>_<unit>`.

## Testing strategy

| Layer | Style | Tooling |
|---|---|---|
| domain | pure unit tests incl. table-driven edge cases | stdlib + testify/require |
| application | use cases against fake ports (in-memory fakes live beside tests) | testify |
| infrastructure/providers | contract tests against recorded fixtures (golden files); no live network in CI | httptest.Server replay |
| delivery/http | router-level tests: request → assert status/body envelope | httptest |
| integration | real Postgres/Redis via testcontainers; tagged `-tags=integration` | testcontainers-go |

Rules:

- Every bug fix ships with a regression test.
- Coverage target: domain/application ≥ 85%; overall informative, not gamed.
- Tests run offline; provider fixtures committed under each adapter's
  `fixtures/`.

## Git & review

- Conventional Commits: `feat(ingestion): arxiv OAI-PMH cursor sync`.
- Branches: `phaseN/<topic>` off main; PRs small (<400 LOC diff preferred).
- PR checklist: layers respected? tests? docs/ADR touched? env vars documented?

## Definition of done (per feature)

1. Implementation behind interfaces at boundaries.
2. Unit + contract/integration tests green in CI.
3. Metrics/logs for new failure modes.
4. Env vars added to `.env.example` + `docs/environment.md`.
5. Docs updated (README links, architecture pages, ADR if a decision was made).
