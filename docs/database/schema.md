# PostgreSQL Schema Design

Authoritative DDL: [`backend/migrations/000001_init_schema.up.sql`](../../backend/migrations/000001_init_schema.up.sql)
(down counterpart alongside). This document explains the model and the
deviations from the original entity wish-list.

## 1. Entity relationship overview

```text
users ──< bookmarks >── papers ──< paper_sources >── sources
  │ │ │                  │  │ │ │
  │ │ └──< user_topics >─┤│ │ │  └──< paper_identifiers      (dedup registry)
  │ └────< user_authors >┤│ │ │
  │                      ││ │ └──< citations >── papers (citing/cited graph)
notifications           ││ ├──< paper_topics >── topics (self-referencing tree)
                        ││ ├──< paper_authors >── authors ──< author_identifiers
                        │├──< paper_versions
                        ││
        ai_summaries ───┘│          chat_sessions ──< chat_messages
        paper_chunks ────┘               │
        ingestion_runs                   └─ compare_paper_ids[] (Phase 6)
```

## 2. Table rationale

| Table | Purpose / key decisions |
|---|---|
| `users` | Present at baseline so FKs exist; auth fields land in a Phase 5 migration. `preferred_explanation_level` powers AI UX defaults. |
| `sources` | Registry of external providers (`semanticscholar`, `openalex`, `arxiv`). Holds **sync cursors** (`sync_cursor` JSONB) enabling incremental ingestion and freshness checks. |
| `papers` | Canonical deduplicated research work. Carries denormalized `doi`, `arxiv_id`, `fingerprint` (fast paths) *plus* the full registry below. Generated `search_vector` column feeds FTS (ADR-0005). `tldr_short` is a feed-performance cache of the latest AI TL;DR. |
| `paper_versions` | Preprint vs publisher versions of the same work; each keeps its own URL/DOI/license. |
| `paper_identifiers` | **Dedup spine**: PK `(id_type, id_value)` guarantees one paper per known DOI/arXiv/S2/OpenAlex/PubMed ID across all providers. |
| `authors`, `author_identifiers` | Author identity resolution is hard; we match conservatively (ORCID/provider IDs first, normalized-name heuristics second) and accept controlled fragmentation over wrong merges. |
| `paper_authors` | Ordered authorship (`position`) + affiliation snapshot array. |
| `topics` | Self-referencing hierarchy (`field ▸ topic`), seeded from OpenAlex taxonomy; slugs are stable public identifiers. |
| `paper_topics` | Scored classification with `assigned_by ∈ {provider, curated, classifier}` provenance. |
| `citations` | Directed edges `(citing → cited)`; foundation for citation graphs & support/contradiction detection (Phase 6). |
| `bookmarks`, `user_topics`, `user_authors` | Personalization primitives (Phase 5 UI). `user_topics.notify` gates notification fan-out. |
| `notifications` | In-app inbox rows now; `delivered_via` array records channel fan-out when push/email adapters arrive. |
| `ai_summaries` | One row per `(paper, explanation_level)`; structured `sections` JSONB; `input_content_hash` invalidates cache when source content changes; `model_id`+`prompt_template_version` give full auditability. |
| `chat_sessions`, `chat_messages` | Grounded chat history; `compare_paper_ids[]` reserved for comparison sessions (Phase 6); messages keep citation payloads for client rendering. |
| `paper_chunks` | RAG units with section path, ordering, hashes. Embeddings live in a **separate Phase 4 migration** (`chunk_embeddings(chunk_id, model_id, vector)`) so the baseline runs on vanilla Postgres and model changes never mutate chunk data. |
| `ingestion_runs` | Audit/stats per provider sync window (seen/created/updated/duplicates/errors). River's own `river_job` table remains the operational queue (ADR-0006); this table is the human-readable ledger. |

## 3. Conventions applied throughout

- UUID primary keys; application generates **UUIDv7** (time-ordered → B-tree
  locality), DB fallback `gen_random_uuid()`.
- All timestamps `timestamptz`; all times UTC.
- `citext` for emails/DOIs; native enums for closed sets;
  CHECK constraints for open sets that may grow.
- Soft delete only where product semantics need it (`deleted_at`).
- Naming: plural snake_case tables, singular columns, `_id` FKs, `_at`
  timestamps, `_count` counters, `_url` links.

## 4. Indexing strategy

| Access pattern | Index |
|---|---|
| Feed "latest" | `papers (publication_date DESC)` (+ partial on non-deleted) |
| Trending sort | `papers (cited_by_count DESC)` |
| Keyword search | GIN `search_vector`; trigram GIN `title_normalized` |
| Dedup lookup | `paper_identifiers` PK; partial uniques on `papers.doi`, `papers.arxiv_id` |
| Topic pages | `paper_topics(topic_id)`; `user_topics` PK covers follows lookup |
| Citation traversal | `citations` PK (outgoing); index on `cited_paper_id` (incoming) |
| Chat history | `(session_id, created_at)` |
| Sync freshness | `ingestion_runs(source_id, started_at DESC)` |

## 5. Migration plan by phase

| Migration | Phase | Content |
|---|---|---|
| `000001_init_schema` | 0 (this) | Everything above except vectors |
| `000002_chunk_embeddings` | 4 | `CREATE EXTENSION vector`, embeddings table, HNSW index |
| `000003_auth_tables` | 5 | credentials/OAuth identities, refresh tokens, devices |
| later | 6 | materialized connection views, trend snapshots |

Every migration ships with a verified `.down.sql`.
