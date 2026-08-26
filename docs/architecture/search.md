# Search Architecture

> Start simple; keep the seam for scale. (ADR-0005)

## 1. Staged capability plan

| Stage | Capability | Mechanism |
|---|---|---|
| 2 | Keyword / full-text | Postgres `tsvector` (title=A, abstract=B) + GIN |
| 2 | Fuzzy title matching | `pg_trgm` GIN on `title_normalized` |
| 2 | Filters/sort/pagination | SQL WHERE/ORDER + cursor |
| 4 | Semantic | pgvector HNSW over paper & chunk embeddings |
| 4 | Hybrid ranking | Reciprocal Rank Fusion (k=60) |

## 2. Query modes

- `mode=keyword` — FTS only.
- `mode=semantic` — vector similarity only (Phase 4).
- `mode=hybrid` — both, fused (Phase 4).
- `mode=auto` (default) — heuristics: ≤6 tokens without stop-words → keyword;
  otherwise hybrid when embeddings exist.

## 3. Ranking formula (Phase 2 baseline)

```text
score = ts_rank_cd(search_vector, query)          # textual relevance
      × recency_decay(published_at)               # half-life ~ 18 months
      × (1 + ln(1 + cited_by_count))              # citation gravity
```

Tuned via golden query set; weights live in config, not code.

## 4. Port boundary

```go
// domain/search
type Searcher interface {
    Search(ctx context.Context, q Query) (ResultPage, error)
    Related(ctx context.Context, paperID UUID, limit int) ([]ScoredPaper, error)
}
```

Implementation today: `pgsearcher`. Future: OpenSearch/Meilisearch adapter —
use cases unchanged. **Migration triggers** (documented in ADR-0005): p95
latency budget breach at target traffic, corpus > ~10M, multilingual stemming
needs.

## 5. Filter contract

Filters are composable and validated server-side:

```text
q, mode, topic, field, author_id, institution?, venue,
published_after, published_before, open_access=true|false,
source=semanticscholar|openalex|arxiv, min_citations,
sort=relevance|newest|citations, cursor, limit(≤100)
```

Unknown filter values → 400 `invalid_request` with field details; never
silently ignored.

## 6. Why not Elasticsearch/OpenSearch now

Sync pipeline + JVM cluster + index mapping maintenance buys relevance we
don't need below millions of documents. Transactional index consistency inside
Postgres is worth more during MVP iteration. The `Searcher` port makes the
future swap mechanical rather than architectural.

Related-work (`GET /research/:id/related`) MVP signal: shared topics +
citation overlap + embedding similarity (once available); evolves into a
connection-detection service in Phase 6.
