# ADR 0005: Search strategy — PostgreSQL-first

- **Status:** accepted
- **Date:** 2026-08-22
- **Deciders:** Lead Architect

## Context

Athena needs keyword search ("large language models"), semantic search
("research about whether consciousness can emerge from artificial systems"),
filters, sorting, relevance ranking, and pagination. Scale at MVP launch is
unknown but realistically ≤ millions of papers. Requirement: do not introduce
unnecessary infrastructure prematurely.

## Decision

Search runs inside PostgreSQL behind a `Searcher` port owned by the domain
layer. Staged capability growth:

1. **Phase 2 (keyword):** weighted `tsvector` generated column
   (title=A, abstract=B) + GIN index; `websearch_to_tsquery` for
   natural queries; trigram (pg_trgm) fallback for fuzzy title matching;
   ranking = `ts_rank_cd` × recency decay × log-scaled citation boost.
2. **Phase 4 (semantic):** paper/chunk embeddings in pgvector with HNSW index;
   cosine similarity retrieval.
3. **Hybrid:** run both retrievers, fuse with Reciprocal Rank Fusion
   (k=60), then apply filters/facets. Query mode `auto` escalates:
   short keyword-ish query → keyword; long natural-language query → hybrid.

The engine is isolated:

```text
application/search ──▶ domain.Searcher (port)
                          ▲
        infrastructure/database/pgsearcher (now) | opensearch/meilisearch (later)
```

**Migration triggers** to a dedicated engine (documented, not assumed):
sustained p95 search latency > budget at target traffic, corpus > ~10M papers,
need for advanced analyzers/aggregations or multi-language stemming quality
Postgres cannot deliver.

## Alternatives considered

| Option | Pros | Cons | Why rejected *for now* |
|---|---|---|---|
| Elasticsearch/OpenSearch immediately | Best-in-class relevance/analytics | Heavy ops (JVM cluster), index-sync pipeline, premature | Revisit at documented triggers |
| Meilisearch | Excellent typo tolerance, simple ops | Weaker semantic story; second datastore to sync | Same triggers; port makes swap mechanical |
| Typesense | Fast, simple | Similar tradeoffs as Meilisearch | Same |

## Consequences

**Positive:**

- Zero extra infrastructure; indexes update transactionally with data.
- One query language for filters + ranking during MVP iteration speed.

**Negative / risks:**

- Postgres FTS stemming/multilingual quality below dedicated engines (accepted
  for MVP; mostly English corpus initially).
- RRF fusion logic is ours to own and tune.

**Follow-ups:**

- [ ] Phase 2: benchmark suite with representative queries + golden result sets.
- [ ] Phase 4: embedding backfill job design (see ingestion pipeline).
