# Athena REST API Specification (v1)

Status: **designed in Phase 0** · implemented progressively per phase.
Base URL: `https://<host>/api/v1` · All examples relative to base.

## 1. Conventions

| Concern | Convention |
|---|---|
| Protocol/format | HTTPS, JSON bodies (`Content-Type: application/json`) |
| Field casing | `snake_case` everywhere |
| Timestamps | ISO 8601 UTC (`2026-08-22T09:30:00Z`) |
| IDs | UUID strings (server issues UUIDv7) |
| Pagination | Cursor-based: request `?cursor=&limit=`, response `meta.next_cursor`; `limit` default 20, max 100 |
| Sorting | Whitelisted enum per endpoint; unknown values → 400 |
| Errors | RFC-7807-inspired envelope (below) |
| Tracing | Every response carries `X-Request-ID` (client may supply) |
| Rate limits | `X-RateLimit-Limit/-Remaining/-Reset` headers on public endpoints |
| Idempotency | AI-generating POSTs accept `Idempotency-Key` header |
| Versioning | URI major version only (`/v1`); additive changes within v1 |

### Error envelope

```json
{
  "error": {
    "code": "not_found",            // machine-readable, stable
    "message": "paper not found",   // human-readable
    "request_id": "01J8Z...",
    "details": [ {"field": "limit", "issue": "must be <= 100"} ]
  }
}
```

Codes: `invalid_request` · `unauthorized` · `forbidden` · `not_found` ·
`conflict` · `rate_limited` · `upstream_unavailable` · `ai_unavailable` ·
`quota_exceeded` · `internal`.

HTTP status mapping: 400/401/403/404/409/429/502/503/500 respectively.

## 2. Endpoint catalog

### System

```text
GET /healthz          liveness (no deps checked)
GET /readyz           readiness (postgres, redis, queue)
GET /metrics          Prometheus scrape (internal)
```

### Research discovery

```text
GET /feed?section=trending|latest|recommended&topic={slug|slug1,slug2,…}&field={slug}&cursor=&limit=
   # topic accepts a comma-separated list; slugs OR-match (mobile interests)
```
Returns `FeedItem[]`: paper summary + `section`, `reason`
(e.g. `"because you follow Artificial Intelligence"` when personalized).
Auth required only for `recommended` (Phase 5).

```text
GET /research?topic={slug}&field={slug}&published_after=&published_before=
        &open_access=true|false&source=semanticscholar|openalex|arxiv
        &author_id=&venue=&min_citations=&sort=newest|citations|relevance
        &q=&cursor=&limit=
GET /research/{id}                       # UUID, DOI, or arXiv ID all accepted
GET /research/{id}/related?limit=
GET /research/{id}/citations?direction=out|in&cursor=   # references / cited-by
```

Paper detail response (abridged):

```json
{
  "id": "0197c0de-…",
  "title": "Scaling Laws for …",
  "abstract": "…",
  "publication_date": "2026-05-11",
  "venue": {"name": "NeurIPS", "type": "conference"},
  "publication_type": "conference_paper",
  "authors": [
    {"id": "…", "name": "J. Doe", "orcid": null, "position": 1,
     "affiliations": ["MIT"]}
  ],
  "topics": [
    {"slug": "machine-learning", "name": "Machine Learning",
     "kind": "topic", "is_primary": true}
  ],
  "open_access": {"status": "gold", "url": "https://…", "license": "cc-by"},
  "identifiers": {"doi": "10.1234/…", "arxiv": "2605.01234"},
  "citation_stats": {"cited_by": 12, "references": 64},
  "versions": [{"kind": "preprint", "url": "https://arxiv.org/abs/…"}],
  "sources": ["semanticscholar", "openalex"],
  "ai": {"tldr": "…", "summary_levels_available": ["beginner"]},
  "created_at": "2026-08-01T10:00:00Z",
  "updated_at": "2026-08-20T18:22:00Z"
}
```

List responses wrap summaries with pagination meta:

```json
{
  "items": [ { …paper summary… } ],
  "meta": {"next_cursor": "eyJvIjoxMDB9", "limit": 20, "took_ms": 34}
}
```

### Auth (Phase 5)

```text
POST /auth/register   {email, password, display_name?} → 201 {token, expires_at, user}
POST /auth/login      {email, password}                → 200 {token, expires_at, user}
POST /auth/logout     Authorization: Bearer <token>    → 204 (revokes the session)
GET  /me              Authorization: Bearer <token>    → 200 {user}
```

- Passwords: PBKDF2-SHA256 (600k iterations), self-describing encoded hash.
- Sessions are opaque 32-byte bearer tokens; only their sha256 hash is stored,
  30-day expiry. Unknown email and wrong password both return
  `401 unauthorized` ("invalid email or password"); duplicate registration
  returns `409 forbidden` with a field detail on `email`.
- All routes accept anonymous requests; guarded endpoints answer `401`.
  Invalid/expired bearer tokens degrade to anonymous rather than erroring.

### Search

```text
GET /search?q={query}
   &mode=auto|keyword|semantic|hybrid      # semantic/hybrid effective Phase 4
   &topic=&field=&published_after=&published_before=&open_access=&source=
   &sort=relevance|newest|citations&cursor=&limit=
```

Response adds search metadata:

```json
{
  "items": [ {"score": 0.87, "paper": { …summary… } } ],
  "meta": {"next_cursor": null, "mode_used": "keyword", "took_ms": 41,
           "total_estimate": 1284}
}
```

Long natural-language queries are first-class: the same endpoint serves
"research about whether consciousness can emerge from artificial systems"
(`mode_used: hybrid` once embeddings exist).

### Live federated search

Queries every configured research provider (arXiv, Semantic Scholar,
OpenAlex, Crossref) concurrently, merges duplicates across sources, ranks by
textual relevance + citation gravity + recency + source agreement, and
persists hits so every result carries a stable paper id.

```text
GET /search/live?q={query}&sort=relevance|newest|citations
   &open_access=&min_citations=&limit=
```

```json
{
  "items": [ {"score": 4.213, "paper": { …summary… } } ],
  "meta": {
    "took_ms": 1830,
    "sources": [
      {"slug": "arxiv", "ok": true, "papers": 25},
      {"slug": "semanticscholar", "ok": true, "papers": 25},
      {"slug": "openalex", "ok": true, "papers": 25},
      {"slug": "crossref", "ok": false, "papers": 0, "error": "…"}
    ]
  }
}
```

Individual provider failures never fail the request while at least one
source answers; per-source status is reported in `meta.sources`.

### Topics

```text
GET /topics?kind=field|topic&q=&parent={slug}&cursor=
GET /topics/{slug}
GET /topics/{slug}/research?sort=&cursor=       # same filters as /research
```

Topic response:

```json
{
  "slug": "philosophy-of-mind", "name": "Philosophy of Mind",
  "kind": "topic", "parent": {"slug": "philosophy", "name": "Philosophy"},
  "paper_count_estimate": 42311,
  "children": ["consciousness", "artificial-consciousness"]
}
```

### AI features (Phase 4)

```text
POST /research/{id}/summary        { "level": "beginner|intermediate|advanced|expert" }
POST /chat/sessions                { "paper_id": "uuid" }
GET  /chat/sessions/{id}/messages
POST /chat/sessions/{id}/messages  { "content": "question" }   # SSE stream
POST /admin/rag/index              { "paper_ids": ["uuid", …] }  # admin token
GET  /research/{id}/summary?level=
```

`POST` returns `200` on cache hit, `201` freshly generated, and honors
`Idempotency-Key`. Summary payload:

```json
{
  "level": "intermediate",
  "tldr": "…one or two sentences…",
  "sections": {
    "simple_explanation": "…",
    "academic_explanation": "…",
    "key_findings": ["…", "…"],
    "methodology": "…",
    "results": "…",
    "limitations": ["…"],
    "why_it_matters": "…"
  },
  "grounding": {"based_on": "abstract+full_text", "chunk_count": 14},
  "generated_at": "2026-08-22T08:00:00Z",
  "model_id": "gpt-4o-mini@2026-07",
  "prompt_version": "summary_v3"
}
```

Papers without permitted full text return `"based_on": "abstract"` — the UI
communicates reduced grounding honestly.

Chat:

```text
POST /chat/sessions                 { "paper_id": "…" }
GET  /chat/sessions?paper_id=
GET  /chat/sessions/{sid}/messages?cursor=
POST /chat/sessions/{sid}/messages  { "content": "Explain the methodology." }
     → application/json answer OR text/event-stream token stream
       (SSE events: token | citation | done | error)
```

Assistant messages embed citations:

```json
{ "role": "assistant", "content": "The researchers used…[1]",
  "citations": [
    {"index": 1, "chunk_id": "…", "section_path": "3. Methods > 3.2 Dataset",
     "quote": "We trained …"}
  ] }
```

Comparison (Phase 6):

```text
POST /research/compare   { "paper_ids": ["…","…"], "question": null,
                           "aspects": ["methodology","results","limitations"],
                           "level": "advanced" }
      → 202 { "comparison_id": "…" } ; poll GET /comparisons/{comparison_id}
```

### Personalization (Phase 5)

```text
POST /auth/register | /auth/login | /auth/refresh | POST /auth/logout
GET  /me                                    GET /me/feed-config
PUT  /me/explanation-level                  { "level": "advanced" }

GET    /bookmarks?cursor=
PUT    /bookmarks/{paper_id}                # idempotent save (body: optional note)
DELETE /bookmarks/{paper_id}

PUT    /me/topics/{slug}    { "notify": true }     # follow
DELETE /me/topics/{slug}                          # unfollow
PUT    /me/authors/{id} ; DELETE /me/authors/{id}

GET  /notifications?type=&unread_only=&cursor=
POST /notifications/read                  { "ids": [...], "all": false }
POST /devices                             # push registration (later)
```

### Admin / ingestion ops (Phase 1)

Guarded by `Authorization: Bearer $ATHENA_ADMIN_TOKEN`.

```text
POST /admin/ingestion/jobs    { "provider": "openalex",
                                "kind": "window|backfill",
                                "from": "...", "to": "..." }
GET  /admin/ingestion/jobs?status=&provider=&cursor=
GET  /admin/sources                        # sync cursors, freshness, stats
```

## 3. Cross-cutting behaviors

| Behavior | Contract |
|---|---|
| Caching | Feed/search responses may be CDN/Redis cached ≤60s; paper details support ETag revalidation |
| Rate limiting | Anonymous per-IP buckets; authenticated per-user; AI endpoints have separate stricter buckets → `429 rate_limited` |
| Unknown query params | Ignored forward-compat; unknown *values* of known params → 400 |
| Trailing slashes | 308 redirect to non-slash form |
| CORS | Configurable origin allow-list (`ATHENA_CORS_ALLOWED_ORIGINS`) |

## 4. Flutter mapping

Each mobile feature consumes exactly one slice of this surface:

| Feature | Endpoints |
|---|---|
| research | /feed, /research*, /topics/*/research |
| search | /search, /topics |
| ai_chat | /chat/*, summary endpoints |
| bookmarks | /bookmarks |
| topics | /topics* + follow endpoints |
| notifications | /notifications* |
| recommendations | /feed?section=recommended |
| profile/onboarding | /auth/*, /me* |
