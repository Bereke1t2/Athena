# ADR 0006: Background jobs on River (PostgreSQL-backed queue)

- **Status:** accepted
- **Date:** 2026-08-22
- **Deciders:** Lead Architect

## Context

Ingestion requires background work: scheduled provider syncs, enrichment,
embeddings, indexing. Requirements: retries with exponential backoff, rate
limiting, fault tolerance, observability, job status visibility, idempotency,
incremental sync. Candidate transports: Redis-backed queues (asynq/celery
style), RabbitMQ/SQS, or a Postgres-backed queue.

## Decision

Use **River** (riverqueue.com) — a Postgres-native job queue for Go.

Rationale: ingestion jobs are born in the same transaction that writes papers
(`INSERT paper ... ; INSERT river_job enqueue embed(paper)`). A Postgres queue
makes that atomic, eliminating the classic lost-job/dirty-write failure mode of
dual-store setups. Redis remains in the stack for caching/rate limiting, not as
the queue of record.

Worker rules:

- Job args are small and carry IDs/params, never payloads (payloads live in DB).
- Every worker is idempotent (natural-key upserts; re-running is always safe).
- Retry policy: exponential backoff with jitter; max attempts per job type;
  dead-letter state visible via `river_job` inspection + metrics.
- Periodic jobs (provider sync scheduling) registered as River periodic tasks.
- Per-provider rate limiting enforced inside provider adapters (token bucket),
  independent of the queue.
- Worker binary (`cmd/worker`) runs N concurrent workers, graceful drain on
  SIGTERM.

## Alternatives considered

| Option | Pros | Cons | Why rejected |
|---|---|---|---|
| asynq (Redis) | Mature, popular | Dual-store consistency problem with paper writes; second system to operate for queue semantics | Transactional enqueue wins |
| SQS/PubSub | Managed scale | Cloud lock-in at MVP stage; same dual-store issue | Deferred to scale phase |
| Hand-rolled `jobs` table | Full control | Rebuilding retries/scheduling/priority poorly | River gives us this without bespoke code |

## Consequences

**Positive:**

- Exactly-once *enforcement point*: data + job commit together.
- One fewer stateful service to run/monitor/back up.
- Job history queryable with SQL during incident triage.

**Negative / risks:**

- Queue throughput bounded by Postgres write capacity — fine at our job rates
  (thousands/hour); revisit if fan-out grows 100×.
- Younger project than asynq — mitigated by its focused scope and our ability
  to swap transports behind an enqueuer interface if ever needed.

**Follow-ups:**

- [ ] Phase 1: wire River into `cmd/worker`, define first four job types:
      `sync_provider_window`, `enrich_paper`, `embed_chunks` (Phase 4),
      `reindex_search`.
