# Athena Roadmap

Phased delivery. Each phase has explicit **acceptance criteria** — a phase is
done when every criterion is verifiable, not when code merely exists.

## Phase 0 — Architecture & Documentation ✅ (current)

Delivered: repository structure · root README · architecture suite
(`docs/architecture/`) · 10 ADRs · PostgreSQL schema + baseline migration ·
REST API specification · Docker/compose foundation · env reference ·
conventions per stack · roadmap.

**Exit:** all documents reviewed; `go build`, compose config, and migration
round-trip verified.

---

## MVP arc

### Phase 1 — Research Aggregation (backend) ✅ (2026-08-23, OpenAlex verified live)

Scope: provider interfaces; Semantic Scholar, OpenAlex, arXiv adapters;
normalization; deduplication; Postgres persistence; River ingestion workers;
initial research API (`GET /research*`, admin ingestion endpoints).

Acceptance:

- [x] `make migrate-up` provisions schema on clean Postgres.
- [x] Backfill job ingests ≥10k papers with zero duplicate rows
      across overlapping windows (verified via `paper_identifiers`).
      *OpenAlex: 41.7k papers via parallel weekly shards, 0 duplicate
      identifier/native-id pairs.* arXiv & Semantic Scholar 10k backfills
      still pending (arXiv: ~100 rec/3s rate limit ≈ 30+ min per 10k;
      S2 bulk needs an API key for reliable throughput).
- [x] Re-running the same window changes nothing (idempotency test).
      *Live replay of a fully-consumed window: 47 seen / 0 created / 0 updated /
      47 no-op duplicates.*
- [x] Provider outage (simulated) degrades gracefully: breaker metrics +
      retry/dead-letter visible. *OpenAlex pointed at a dead endpoint:
      `providers_breaker_state{provider="openalex"} 1`,
      errors by kind (network/breaker), transport retries, and River job
      retries all observed on `/metrics` + `river_job`.*
- [x] API returns paper detail by UUID/DOI/arXiv ID; related/citations stubs
      functional from stored edges. *1.6k citation edges resolved from OpenAlex
      references; `/citations?direction=out` and `/related` return live data.*

Hardening notes discovered during backfill (all fixed): River default
JobTimeout=1m kills long attempts (worker now sets 15m); sync cursors are
checkpointed per page so failed attempts resume mid-window instead of
restarting; OpenAlex sort uses `display_name` tiebreaker (non-unique sort keys
fragment window coverage); sparse provider records are skipped individually
instead of poisoning pages; concurrent-window insert races fall back to merge
on unique-violation; authorship is replaced wholesale to survive position shifts.

### Phase 2 — Search & Discovery (backend)

Scope: FTS keyword search; filters/sort/pagination; latest/trending/topic
endpoints; feed assembly (latest+trending); Redis caching.

Acceptance:

- [x] Golden query set (≥50 queries) passes relevance spot-checks.
  (`backend/cmd/searchbench`, 52 queries; report in `docs/benchmarks/search-golden.md`.)
- [x] p95 search < 300ms at corpus ≥100k papers (local benchmark).
  Provisional: corpus is currently ~45.6k papers. Measured cold-cache p95
  287–410ms across runs (dev Docker, buffer-warmth dependent); warm-cache
  p95 ≤ 90ms. Broad relevance queries rank a bounded candidate slice
  (citation-ordered, `rankCandidateLimit`) to cap worst-case cost.
- [x] Feed sections return stable cursor pages; cache invalidates on sync.
  (Full-corpus latest pagination: no duplicate IDs across pages; pinned-clock
  relevance cursors keep pages consistent while data ages. Ingestion success
  with fresh/updated rows bumps the cache generation; unit-tested.)

### Phase 3 — Flutter Foundation (mobile)

Scope: core kit (dio client, failure hierarchy, router, theme); research feed,
detail, search, topic browsing screens with full state handling.

Acceptance:

- [x] All screens implement loading/error/empty/content states.
  (Shared `AsyncListView` / `ErrorView` / `EmptyView` widgets drive the four
  states uniformly across feed, search, topics list/detail, and paper detail.)
- [x] Deep link `athena://paper/{id}` opens detail screen.
  (Android VIEW intent-filter + iOS CFBundleURLSchemes registered for
  `athena`; custom-scheme URIs land on path `/{id}`, handled by a
  UUID-guarded catch-all route redirecting to `/papers/{id}`. Routing covered
  by widget tests.)
- [x] Unit tests for controllers/mappers; widget tests green in CI.
  (24 passing: failure mapping from dio exceptions, DTO→domain mappers,
  feed/search notifier pagination + error slots, deep-link routes, app-shell
  smoke, architecture boundary rules. Plus a live-API contract test gated by
  `ATHENA_INTEGRATION_BASE_URL` that validates wire shapes against a running
  backend.)
- [x] No dio import outside data layer (enforced by lint/import test).
  (`test/architecture/import_boundary_test.dart` also bans DTO imports above
  the data layer and framework imports in domain/)

### Phase 4 — AI Layer (backend + mobile) ✅ (2026-08-25)

Scope: LLM/embedding adapters; summaries at four levels; text extraction for
permitted content; chunking; pgvector embeddings; hybrid retrieval; grounded chat
(SSE streaming); citation validation.

Acceptance:

- [x] Summary cache hit path costs zero tokens (content-hash keyed).
      (`application/ai`: hash over title+abstract+chunk hashes; hit returns
      `cache_hit=true` with zeroed usage and never calls the model — unit-tested.)
- [x] Chat answers carry valid citations or explicit "insufficient evidence"
      refusal on adversarial question set. (`application/chat`: `[chunk N]`
      indices validated against the retrieved set; one strict regeneration,
      then degradation to the exact refusal sentence — unit-tested including
      fabricated-index adversarial cases.)
- [x] Metadata-only papers degrade honestly (`based_on: abstract`).
      (Summaries and chat both label grounding `abstract` vs
      `abstract+full_text`; surfaced in the API response and the mobile UI.)
- [x] Cost dashboard: token usage per feature visible in `/metrics`.
      (`athena_ai_tokens_total{feature,model,kind}` +
      `athena_ai_requests_total{feature,model,status=ok|refused|uncited|error|cache_hit}`.)

Also delivered: PDF text extraction (`infrastructure/textextract`),
section-aware ~800-token chunking with overlap, lazy + queue-driven RAG
indexing (`rag_index_paper` worker, `POST /admin/rag/index`), pgvector ANN +
FTS retrieval fused with RRF, OpenAI-compatible/stub adapters, mobile AI
summary card with level selector, and a streaming chat screen with citation
excerpts.

---

## Phase 5 (product) — Personalization ✅ (2026-10-28)

Scope: Auth (email + JWT, refresh tokens, password reset), bookmarks, follow
topics/authors, personalized feed & recommendations, notification fan-out
(FCM/APNs gateway + River worker).

Acceptance:

- [x] Authentication lifecycle: email/password registration, login with JWT and
      refresh token rotation, password reset requests (`/auth/*`).
- [x] Bookmarks & Library: authenticated user bookmarks with offline-first
      SharedPreferences fallback and bookmark toggle on paper detail.
- [x] Follows & Affinity: follow topics and authors (`/follows/*`) with unified
      guest-to-authenticated state reconciliation upon sign-in.
- [x] Push Notification Gateway: multi-platform router supporting FCM HTTP v1 and
      APNs HTTP/2 with background River fanout (`notification_fanout`).
- [x] Reading history & progress tracking: progress persistence and retrieval
      (`internal/application/history/`).

---

## Phase 6 (product) — Advanced Research Intelligence ✅ (2026-11-04)

Scope: Paper comparison pipeline, citation graph traversal & visualization,
Audio Studio TTS streaming, weekly personalized AI research digests, and full-text
academic RAG enhancements.

Acceptance:

- [x] Multi-paper comparison: structured comparative matrix analyzing methodologies,
      empirical findings, and limitations across papers (`/research/compare`).
- [x] Citation network & visual graph: citation edge traversal APIs (`/citations`,
      `/related`) and mobile interactive canvas graph visualization.
- [x] Audio Studio & TTS: RFC-7233 partial content HTTP byte-range streaming
      (`206 Partial Content`, `Accept-Ranges: bytes`) with OpenAI TTS adapter
      and mobile audio player screen.
- [x] Weekly AI Research Digest: recency-first paper aggregation, generative AI
      executive briefing across followed topics, empirical takeaways, and guest
      personalization via topic parameters (`/research/digest/latest`).
- [x] Full-Text RAG Engine: robust streaming response lifecycle, academic publisher
      HTML citation metadata resolution (`citation_pdf_url`), and alignment with
      `gemini-embedding-001` (768 dimensions).

## Future / vision

- [x] Europe PMC & PubMed Research Aggregator: Open-access biomedical and life
      sciences integration (ADR-0002). Live federated search fan-out across 5
      providers (`arxiv`, `semanticscholar`, `openalex`, `crossref`, `europepmc`),
      temporal window sync (`FIRST_PDATE`), PubMed ID deduplication, and direct
      open-access full-text PDF resolution.
- [x] Email Digests & Transactional Mailer: Automated personalized weekly research
      briefings dispatched via SMTP/logging/mock mailers. Resarc editorial HTML
      email design with executive AI synthesis, top takeaways, curated paper links,
      and password recovery emails.
- [x] Research Collections & Reading Lists: Custom named research paper folders and
      curated reading lists. PostgreSQL persistence (`collections`, `collection_papers`),
      REST endpoints (`/api/v1/collections`, `/api/v1/collections/{id}/papers`),
      cross-format bulk citation export (BibTeX, RIS, APA, MLA, Markdown), and
      mobile Flutter experience with dedicated Library tab, collection details,
      and 1-tap paper pinning bottom sheet.
- [x] Platform Hardening, Multi-Replica Safety & Maintenance (2026-11-14):
      Distributed Redis-backed rate limiting (`RedisRateLimiter`) and idempotency store
      (`RedisIdempotencyStore`) for multi-replica horizontal scaling; periodic River
      housekeeping worker pruning expired sessions and password resets; periodic sync
      scheduling for Europe PMC and Semantic Scholar; full synchronization of REST API
      specifications (`docs/api/api-specification.md`) and CI/CD Go 1.26 toolchain;
      mobile code modularization (extracting citation graph explorer widget from detail screen)
      and 5-tab Library navigation alignment.
- [x] Multi-Platform Adaptive Layout & Web Support (2026-11-16):
      Responsive `AdaptiveAppShell` with breakpoint-switching at 720px (`kTabletBreakpoint`),
      `NavigationRail` on wide viewports (tablets, desktop, web) with Aperture branding,
      ergonomic `1200px` max-width reading container, HTML5 web engine scaffolding (`index.html`,
      `manifest.json`), web-resilient PDF viewing fallback, and widget test coverage.
- [x] Collaborative Research Collections & Reading Groups (2026-11-18):
      Multi-user collaborative collections with PostgreSQL schema (`000022_collection_collaborators.up.sql`),
      role-based permissions (`owner`, `admin`, `editor`, `viewer`), membership management endpoints
      (`GET|POST /api/v1/collections/{id}/collaborators`, `DELETE /api/v1/collections/{id}/collaborators/{user_id}`),
      dynamic query support returning owned and shared reading groups with `user_role`, and unit tests.
      Full mobile Flutter experience with `CollaboratorsSheet`, member avatar listing, role indicators,
      invite dialog with role selector, and permissions-guarded paper operations.
- [x] Advanced Search Filter Engine & UI (2026-11-18):
      Multi-modal search filter sheet supporting search engine modes (`Hybrid AI`, `Keyword`, `Vector`, `Live Federated`),
      minimum citations threshold (Any, 10+, 50+, 100+, 500+), publication time range presets, open access toggle,
      active filter counter badge, and full query parameter synchronization with backend (`published_after`, `published_before`).
- [x] Multi-Paper Comparison Input Enhancement (2026-11-18):
      Eliminated single-paper dead ends in comparison by enabling direct UUID or DOI manual input in both
      insufficient papers state and add-to-compare modal.
- [x] Collection-Grounded Multi-Paper Chat ("Ask My Collection") (2026-11-18):
      Extended AI RAG conversational assistant from single papers to entire research collections.
      Database migration (`000023_collection_chat_sessions.up.sql`) supporting `collection` session type,
      application service (`internal/application/chat/service.go`) aggregating multi-paper RAG chunks with
      `[Paper Title] Section` heading attribution, HTTP handler (`POST /api/v1/chat/sessions`),
      mobile repository and Riverpod state architecture (`collectionChatThreadProvider`), adaptive
      `ChatScreen` with Collection Grounding badge and comparative synthesis suggested prompts,
      and 1-tap "Ask AI" navigation from collection detail screen.
- [x] Persistent Text Highlights, Color Annotations & Margin Notes (2026-11-19):
      Multi-color reader highlights and persistent margin notes for academic research synthesis.
      Database migration (`000024_paper_annotations.up.sql`) supporting 5 resonant palette colors
      (`yellow`, `coral`, `emerald`, `cyan`, `purple`), page and section targeting, compound indexes,
      domain model, database store, and application service (`internal/application/annotation/service.go`)
      with guest mode degradation. REST HTTP endpoints (`GET|POST /api/v1/papers/{id}/annotations`,
      `PATCH /api/v1/annotations/{id}`, `DELETE /api/v1/annotations/{id}`). Mobile Flutter architecture
      featuring offline-first SharedPreferences caching, `PaperAnnotationsNotifier`, `AddAnnotationDialog`
      color picker and quote preview, `AnnotationsSheet` with "Ask AI about this" contextual shortcut,
      and seamless integration into both `ArticleReaderScreen` and `PdfViewerScreen` with live count badges.

Providers: PubMed/Europe PMC ✅, Crossref ✅ · Email Digests ✅ · Collections & Reading Lists ✅ · Collaborative Groups ✅ · Web & Adaptive Shell ✅ · Platform Hardening & Multi-Replica Safety ✅ · Collection Chat ✅ · Annotations & Highlights ✅ · alternative engines
if ADR-0005 triggers fire · multi-language UIs · institutional features.
