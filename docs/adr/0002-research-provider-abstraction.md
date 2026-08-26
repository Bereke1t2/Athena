# ADR 0002: Research provider abstraction

- **Status:** accepted
- **Date:** 2026-08-22
- **Deciders:** Lead Architect

## Context

Athena aggregates metadata from Semantic Scholar, OpenAlex, and arXiv today;
Crossref, PubMed, and Europe PMC are expected later. Each source differs in
identifiers, pagination style, rate limits, and payload shape. Coupling use
cases to any vendor's schema would make every future provider a cross-cutting
change and would leak third-party churn into Athena's core.

## Decision

Define a `ResearchProvider` port in the domain layer; each external source is
an adapter in `internal/infrastructure/providers/<name>` that translates its
API responses into Athena's canonical models before anything else sees them.

Conceptual contract (finalized in code during Phase 1):

```go
type ResearchProvider interface {
    ID() string                                   // "semanticscholar" | "openalex" | "arxiv"
    FetchWindow(ctx, Window{From, To, Cursor}) ([]NormalizedPaper, NextCursor, error)
    SearchRemote(ctx, Query) ([]NormalizedPaper, error)   // optional capability
}
```

Rules:

1. Adapters return `domain.NormalizedPaper` — never vendor DTOs.
2. Rate limiting lives inside adapters (per-provider token bucket), so callers
   cannot exceed a provider's quota even when misused.
3. Raw payloads may be archived for audit/replay, but parsing happens once, at
   the adapter boundary.
4. New provider = new adapter package + registration; zero changes to use
   cases, normalizers shared pipeline stays intact.

Normalization & deduplication are a *shared* downstream pipeline
(`application/ingestion`), not per-provider logic:

```text
External API → Adapter → Normalizer → Deduplicator → Athena model → PostgreSQL
```

Deduplication precedence: DOI → arXiv ID → Semantic Scholar paper ID → OpenAlex
ID → PubMed ID → conservative fingerprint fallback (normalized title + year +
lead-author surname). See `docs/architecture/research-providers.md`.

## Alternatives considered

| Option | Pros | Cons | Why rejected |
|---|---|---|---|
| Direct vendor clients in use cases | Fast initial build | Vendor leakage everywhere; painful migrations | Violates dependency rule |
| Third-party aggregation APIs (e.g., Unpaywall-style brokers) | One integration | Cost, coverage gaps, single point of failure, less control over dedup | Rejected for MVP; revisit if multi-provider maintenance cost proves high |
| ETL-first (normalize on read) | No ingest pipeline needed | Slow reads, repeated transformation cost, weak dedup | Read-time normalization cannot dedupe reliably |

## Consequences

**Positive:**

- Application/domain layers are provider-agnostic and testable with fakes.
- Adding Crossref/PubMed later is additive work.
- Provider failures are isolated behind circuit breakers per adapter.

**Negative / risks:**

- Canonical model must be a superset of what providers offer; fields missing at
  a provider stay nullable.
- Fingerprint-based dedup can false-positive; mitigated by conservative
  thresholds and identifier precedence (documented risk).

**Follow-ups:**

- [ ] Phase 1: implement three adapters + contract tests against recorded fixtures.
