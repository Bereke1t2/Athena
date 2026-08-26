# Research Providers Architecture

> The application layer must never know which external provider supplied a
> paper. (ADR-0002)

## 1. Initial providers

| | Semantic Scholar | OpenAlex | arXiv |
|---|---|---|---|
| API | Graph API v1 (`api.semanticscholar.org`) | REST `api.openalex.org` | Atom search API + OAI-PMH |
| Auth | optional API key (recommended) | none; polite pool via `mailto` | none; UA with contact |
| Rate limit (documented) | unauth: shared 1k/5min · key: ~1 rps sustained | 100k/day, ~10 rps polite | ~1 request / 3 s courtesy |
| Pagination | offset (≤10k) / cursor (bulk) | cursor (`cursor=*` start) | startIndex/page or OAI resumptionToken |
| Incremental sync signal | publicationDate windows, sort by pub date | `from_publication_date` / `updated_date` filters | OAI-PMH datestamps |
| Strengths | citations graph, abstracts, TLDRs, influential citations | rich topics/concepts, institutions, OA locations, updated_date | preprints for CS/Physics/Math — fast, licensed for text mining |
| Weaknesses | strict rate limits without key | abstracts missing sometimes | no citation counts |

Provider selection per job is configuration-driven; Athena queries multiple
providers and merges results at the dedup layer.

## 2. Port definition

Owned by `domain/research`; implemented by adapters:

```go
type ResearchProvider interface {
    ID() string
    FetchWindow(ctx context.Context, w Window) (Page[NormalizedPaper], error)
}

// Optional capability interfaces (feature-detected via type assertion):
type RemoteSearcher interface {
    SearchRemote(ctx context.Context, q Query) ([]NormalizedPaper, error)
}
```

- Adapters own: HTTP client, retries (transport-level only), **per-provider
  token-bucket rate limiter**, circuit breaker, DTO parsing.
- Adapters return validated `NormalizedPaper`s or errors — never partial
  garbage; unknown enum values map to explicit `unknown`, not guesses.

## 3. Canonical model

```text
NormalizedPaper
├── identifiers[]        {type: doi|arxiv|semantic_scholar|openalex|pubmed|corpus_id, value}
├── title, title_normalized, fingerprint
├── abstract?            (nil when source omits/prohibits)
├── published_on (date), year
├── venue {name?, type?}, publication_type
├── authors[]            {name, normalized, orcid?, provider_author_ids{}}
├── topics[]             {name, provider_key, score?}
├── open_access          {status: gold|green|hybrid|bronze|closed|unknown, url?, license?}
├── citation_counts      {cited_by?, references?, influential?}
├── versions[]           {kind: preprint|publisher, url?, doi?, arxiv_id?, published_on?}
└── provenance           {provider_id, native_id, fetched_at, raw_fingerprint}
```

Normalization rules (shared pipeline in `application/ingestion/normalize`):

- DOIs lowercased, `https://doi.org/` prefixes stripped.
- arXiv IDs canonicalized to modern form (`2401.12345v2`, version stripped for
  identity, kept on version record).
- Author names → `normalized_name` (lowercase, diacritics folded, surname
  ordering unified) for matching; display name preserved verbatim.
- Titles → `title_normalized` (lowercase, punctuation/diacritics stripped,
  whitespace collapsed).
- Fingerprint = SHA-256(normalized title ‖ first-author surname ‖ year).

## 4. Deduplication policy

Resolution order when inserting a `NormalizedPaper`:

1. **Identifier match** against `paper_identifiers` (any known ID hits → same
   paper). Merge new information into the existing row (fill nulls; never
   overwrite non-null core fields with different values — conflicts are logged).
2. **DOI/arXiv conflict guard:** if the incoming paper carries an identifier
   that belongs to a *different* existing paper than other matches → keep both,
   log `identity_conflict` metric (conservative).
3. **Fingerprint match** (no identifiers overlap): merge as same paper only if
   DOI absent on both sides and years equal; otherwise create a separate paper
   and record a soft "similar" link for future curation.

Every accepted paper keeps **one row per contributing source** in
`paper_sources` (provenance + native ID + payload fingerprint + sync state),
so re-syncing a source touches only its rows (idempotency anchor).

## 5. Failure handling

| Failure | Behavior |
|---|---|
| 429 from provider | limiter already throttles; on leak-through → exponential backoff, job retried |
| 5xx / timeout | circuit breaker opens after threshold; jobs retry later; partial windows resume from cursor |
| Schema drift (parse failure) | job marked failed with sample payload archived; alert via metrics; other fields still ingestable if parse is field-level tolerant |
| Provider outage | breaker skips provider N minutes; others continue |

All counters exposed on `/metrics`: `{provider}_requests_total`,
`{provider}_errors_total{kind}`, `{provider}_breaker_state`,
`ingestion_papers_{created,updated,duplicates}_total`.
