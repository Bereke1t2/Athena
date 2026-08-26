# System Data Flows

## 1. End-to-end architecture flow

```text
Semantic Scholar   OpenAlex   arXiv          (future: Crossref, PubMed, Europe PMC)
        │             │          │
        └─────────────┴────┬─────┘
                  ResearchProvider adapters
        (rate limit → fetch → DTO validate)
                           ↓
              Normalize (shared pipeline)
                           ↓
              Deduplicate (DOI ▸ arXiv ▸ S2 ▸ OpenAlex ▸ fingerprint)
                           ↓
        PostgreSQL  ◀── transactional upsert + River job enqueue
             │
             ├─▶ Workers: enrich · embed(Phase 4) · reindex(Phase 2)
             ├─▶ Search substrates: FTS tsvector · pgvector HNSW
             ▼
        Go REST API (/api/v1)  ── Redis cache (feed/search hot paths)
             │
             ├─▶ RAG retrieval + versioned prompts ──▶ LLM/Embedding providers
             ▼
        Flutter application (feed · search · reader · chat · library)
```

## 2. Ingestion sequence

```text
Scheduler            Worker(adapter)         Normalizer/Dedup        Postgres
   │ sync_window job      │                        │                    │
   ├─────────────────────▶│ GET /works?filter=...  │                    │
   │                      │──── page of raw DTOs ─▶│ map+validate       │
   │                      │                        ├─ resolve identity ─▶ upsert paper*
   │                      │                        │                    │ insert paper_sources row
   │                      │◀─── next cursor ───────┤                    │ enqueue enrich jobs
   │◀─ success(stats) ────┤                        │                    │
```
*paper = papers + paper_identifiers + paper_authors + paper_topics (+citations)

Failure at any arrow ⇒ job retry with backoff; window resumes from stored
cursor; nothing is double-counted thanks to natural-key upserts.

## 3. Search request flow

```text
Flutter ──GET /api/v1/search?q=…&mode=auto──▶ API handler
    → SearchService: parse/validate → cache probe (Redis, 60s TTL on hot queries)
    → Searcher.Search:
        keyword:  websearch_to_tsquery + GIN scan
        hybrid:   ANN top-k ∪ FTS top-k → RRF fusion
    → filters/sort applied → cursor page
    → response {items[], next_cursor, mode_used, took_ms}
```

## 4. AI summary flow (Phase 4)

```text
POST /research/{id}/summary {level}
  → authz/quota check → cache lookup ai_summaries(paper, level, content_hash)
     hit → return 200
     miss → assemble context (abstract ± permitted chunks)
          → prompt(level template vN) → LLMProvider.GenerateJSON
          → persist structured sections + provenance → 201
```

## 5. Grounded chat flow (Phase 4)

```text
POST /chat/sessions/{sid}/messages {content}      (Accept: text/event-stream)
  → embed question → retrieve top-k chunks (paper-scoped) [+ FTS fallback]
  → budget context = metadata card + chunks + history summary
  → stream tokens via SSE; validate citation indices post-hoc
  → persist user & assistant messages with citations JSONB
  Insufficient evidence → assistant states so explicitly (no fabrication).
```

## 6. Notification fan-out (Phase 5)

```text
ingestion commits new papers for topic T
  → notification worker batches per subscribed users (user_topics.notify)
  → notifications rows created (in-app inbox)
  → delivered_via tracks channels; push/email adapters plug in later
```
