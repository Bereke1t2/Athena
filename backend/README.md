# Athena Backend

Go API + worker implementing Clean Architecture (see
[`docs/architecture/backend.md`](../docs/architecture/backend.md)).

## Layout

```text
cmd/api        HTTP server binary          cmd/worker      background jobs binary
internal/
  domain/        entities + ports (no external imports)
  application/   use cases, transaction boundaries
  infrastructure/ postgres · redis · providers/ · ai/ · workers/
  platform/      config · logger · httpserver kit
  delivery/http/ v1 handlers, middleware
migrations/    golang-migrate SQL pairs (ADR-0009)
```

## Commands

```bash
go run ./cmd/api            # start API on :8080 → GET /healthz
go run ./cmd/worker         # worker process (jobs land Phase 1)
make -C .. up               # postgres + redis via compose
make -C .. migrate-up       # apply migrations (dockerized migrate)
go build ./... && go vet ./...
go test ./...               # unit tests
go test -tags=integration ./tests/integration/...   # needs Docker
```

## Rules of the road

1. Handlers stay thin; business logic lives in application/domain only.
2. Domain imports nothing from other layers — enforced by review and `depguard`
   once lint config lands.
3. All SQL lives in repository implementations under `infrastructure/database`.
4. New env var ⇒ update `.env.example` **and** `docs/environment.md` in the
   same PR.
