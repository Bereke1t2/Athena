# Research Ingestion Pipeline

> Idempotent · Retryable · Rate-limit aware · Fault tolerant · Observable ·
> Incremental

## 1. Pipeline stages

```text
Scheduler (River periodic tasks)
      ↓  enqueue sync_provider_window{provider, from, to, cursor}
Provider Fetcher (adapter: rate limit + breaker + retries)
      ↓
Raw snapshot (payload fingerprint; archived on parse failure)
      ↓
Normalizer (shared pipeline → domain.NormalizedPaper)
      ↓
Deduplicator (identifier precedence → fingerprint fallback)
      ↓
PostgreSQL transaction:
    upsert paper / identifiers / authors / topics / sources / citations
    + enqueue enrichment jobs            ← atomic with the writes (ADR-0006)
      ↓
Enrichment workers
    ├── enrich_paper:     backfill citations, related, OA locations
    ├── embed_chunks:     Phase 4 (extract→chunk→embed→store)
    └── reindex_search:   Phase 2 (refresh FTS/semantic artifacts if any)
```

## 2. Incremental synchronization

Each source stores durable state in `sources.sync_cursor` JSONB, e.g.:

```json
{ "last_watermark": "2026-08-22T00:00:00Z", "resumption_token": "..." }
```

- Windows are small (1–24h) and overlapping by a safety margin.
- Jobs carry `(window_from, window_to)` and are **naturally idempotent** —
  re-running a window re-upserts identical rows (content-fingerprint compared;
  unchanged rows skip write amplification).
- Backfill jobs (`sync_provider_backfill`) walk history in bounded windows,
  resumable from cursor after crash.

## 3. Job semantics (River)

| Job type | Trigger | Retry policy |
|---|---|---|
| `sync_provider_window` | periodic schedule per provider (staggered) | exp backoff ×5 attempts → dead |
| `sync_provider_backfill` | manual/admin trigger | checkpointed via cursor |
| `enrich_paper` | after insert/update with new content hash | exp backoff ×8 |
| `embed_chunks` | Phase 4, after full text acquired | exp backoff ×8 |
| `reindex_search` | Phase 2, batched after sync | at-least-once |

Rules:

- Job args = IDs + parameters only (no payloads).
- Every handler is safe to run twice (upserts everywhere).
- Concurrency bounded per job type; provider adapters additionally self-limit.
- Dead-lettered jobs surface in `/metrics` (`river_job_dead_total`) and are
  inspectable in SQL.

## 4. Change detection & write economy

- `paper_sources.content_fingerprint` (SHA-256 of normalized payload) skips
  no-op updates.
- `papers.updated_at` bumps only when meaningful fields changed → downstream
  embedding/index jobs keyed off content hashes, not timestamps alone.
- Citation-count refreshes are bulk `UPDATE`s batched post-window, not per-paper.

## 5. Observability & operations

| Signal | Source |
|---|---|
| Papers created/updated/duplicates per window | ingestion metrics |
| Provider request/error/breaker counters | adapter middleware |
| Queue depth & oldest-job age | River stats → `/metrics` |
| Sync freshness per source | `sources.last_synced_at` → readiness warning if stale > threshold |
| Structured logs | every stage logs with `{job_id, provider, window}` correlation |

Admin endpoints (Phase 1): `POST /api/v1/admin/ingestion/jobs` (trigger
window/backfill), `GET /api/v1/admin/ingestion/jobs?status=` — guarded by
admin token.

## 6. Legal gating inside the pipeline

Before any full-text acquisition (Phase 4), `enrich_fulltext` checks
`oa_status`/`license` per ADR-0010; closed papers never proceed past metadata.
