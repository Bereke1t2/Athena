# ADR 0007: HTTP layer — standard library net/http router

- **Status:** accepted
- **Date:** 2026-08-22
- **Deciders:** Lead Architect

## Context

Athena's REST API is a conventional versioned resource API (`/api/v1/...`)
with path parameters, middleware (logging, recovery, request ID, CORS, rate
limiting, auth later), and SSE streaming for chat in Phase 4.

## Decision

Use the **standard library `net/http`** with Go ≥1.22 enhanced `ServeMux`
(method + wildcard patterns like `GET /api/v1/research/{id}`), plus a small
hand-written middleware chain helper in `internal/platform/httpserver`.

Rules:

- Handlers stay thin: parse/validate → call application use case → map result
  or error to response. Zero business logic.
- One shared error→response mapper produces the RFC-7807-style envelope
  defined in `docs/api/api-specification.md`.
- Middleware is `func(http.Handler) http.Handler`; ordering documented in the
  router constructor.
- Escape hatch: if requirements outgrow ServeMux (route groups at scale,
  advanced matching), adopt **chi** — it is `net/http`-compatible, so handlers
  and middleware migrate unchanged. This decision makes that swap a one-file
  change.

## Alternatives considered

| Option | Pros | Cons | Why rejected *for now* |
|---|---|---|---|
| chi | Route groups, mature middleware | One more dependency for needs we don't yet have | Documented as first upgrade path |
| gin / echo / fiber | Batteries included | Custom context types leak into handlers; heavier abstraction than needed | Handler portability lost |
| gRPC gateway | Typed contracts | Mobile client wants plain JSON REST; extra toolchain | Revisit if public API partners appear |

## Consequences

**Positive:**

- Zero framework dependencies; Go stdlib is stable across releases.
- Handlers remain plain `http.HandlerFunc` — trivially testable with
  `httptest`.

**Negative / risks:**

- We own small utilities others get for free (request ID, graceful shutdown) —
  one-time cost, kept minimal in `platform/httpserver`.
