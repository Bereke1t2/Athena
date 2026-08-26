# ADR 0001: Clean Architecture as a modular monolith

- **Status:** accepted
- **Date:** 2026-08-22
- **Deciders:** Lead Architect

## Context

Athena has several distinct concerns from day one: research ingestion,
search/discovery, AI/RAG, personalization, and notifications. The product must
evolve quickly through an MVP while staying maintainable long-term. The team is
small; operational simplicity matters more than horizontal service isolation.

## Decision

Athena's backend is a **modular monolith** built with Clean Architecture:

```text
delivery/http ──▶ application ──▶ domain
                     ▲              ▲
infrastructure ──────┘──────────────┘   (implements ports defined inward)
```

- `internal/domain/*` — entities, value objects, domain errors, and **ports**
  (repository/service interfaces). Depends on nothing but the standard library.
- `internal/application/*` — use cases orchestrating domain logic; owns
  transaction boundaries and depends only on domain ports.
- `internal/infrastructure/*` — implementations of ports: PostgreSQL repos,
  Redis cache, research providers, LLM adapters, River workers.
- `internal/delivery/http` — REST handlers, DTOs, middleware. No business
  logic.
- `internal/platform` — cross-cutting kit (config, logger, HTTP server) usable
  by all outer layers, never imported by domain.

Two binaries (`cmd/api`, `cmd/worker`) share `internal/`; both are deployed
from the same image with different commands. Module boundaries follow bounded
contexts (research, search, ingestion, ai, chat, recommendation,
notification); cross-context calls go through application services, not by
reaching into another context's repository.

Dependency direction is enforced in code review now and via `depguard` rules
in `.golangci.yml` when linting lands (Phase 1).

## Alternatives considered

| Option | Pros | Cons | Why rejected |
|---|---|---|---|
| Microservices from day one | Independent scaling/deploy | Distributed transactions, ops burden, premature for unknown load | Violates "avoid premature microservices"; extraction later remains possible because contexts are modular |
| Layered MVC (no domain layer) | Familiar, fast start | Business logic leaks to handlers/models; untestable core | Fails SOLID and testing goals |
| DDD tactical patterns (aggregates, events everywhere) | Rigor | Heavy for MVP; bibliographic domain is CRUD+pipeline shaped | Use DDD *strategic* boundaries only; tactical where justified |

## Consequences

**Positive:**

- Domain logic unit-testable without DB/HTTP mocks beyond interfaces.
- Swapping providers/AI vendors/search engines touches one layer only.
- Single deployable image; two process types cover API + workers.

**Negative / risks:**

- More files/interfaces than naive MVC; boilerplate at boundaries.
- Discipline required to keep handlers thin — enforced by review/lint.

**Follow-ups:**

- [ ] Phase 1: add `depguard` import rules codifying the dependency rule.
