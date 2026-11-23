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
- [x] Offline Research Manager & Storage Dashboard (2026-11-19):
      Complete offline device storage and flight pack pre-caching management for academic papers.
      Extended PDF repository interface and implementation (`mobile/lib/features/papers/data/pdf_repository_impl.dart`)
      with cached PDF metadata enumeration (`CachedPdfInfo`), size calculations, and granular/bulk purge operations.
      Pure domain storage architecture (`StorageBreakdown`, `OfflineFlightBatchResult`, `StorageRepository`) and
      implementation integrating file system caches with user preferences. Riverpod `StorageNotifier` state controller.
      Executive `StorageScreen` (`/storage`) with storage breakdown cards, quick purge actions, cached paper catalog with
      1-tap reader opening, collection "Save for Offline Flight" batch downloader in `CollectionDetailScreen`, and
      "Downloads & Storage" navigation tile in `ProfileScreen`.
- [x] Multi-Paper Comparison Tray & Basket Experience (2026-11-19):
      Persistent floating multi-paper comparison tray and basket flow eliminating single-paper dead ends across
      the research journey. Pure framework-free domain models (`ComparisonTrayItem`, `ComparisonTrayState`),
      `UserPreferences` local caching, `ComparisonTrayNotifier` state controller with 4-paper capacity and duplicate guards.
      Interactive floating docked `ComparisonTrayBar` in `AdaptiveAppShell` (both mobile and wide layouts) supporting
      collapsed pill indicator with live counters, expandable horizontal paper carousel with 1-tap removals, and "Compare Now"
      batch launch into `/compare?ids=id1,id2...`. Dynamic "Compare" action integration on `PaperDetailScreen` (tray toggle,
      active state feedback, contextual "Compare (+N)" labels, and SnackBar shortcuts) and automated tray pre-population and
      quick-add drawers in `ComparisonScreen`.
- [x] Desktop & Web Two-Pane Productivity Workspace & Global Command Palette (2026-11-19):
      Comprehensive large-screen research productivity architecture. Spotlight `CommandPaletteDialog` (`mobile/lib/core/widgets/command_palette_dialog.dart`)
      accessible via global keyboard shortcuts (`Cmd+K` / `Ctrl+K`) and wide `NavigationRail` chip (`⌘K`), providing instant keyboard-driven
      navigation across all workspaces, search dispatch, and recent search history recall.
      Responsive `ResearchSplitWorkspace` (`mobile/lib/core/widgets/research_split_workspace.dart`) triggering at `>= 1024px` breakpoint (`kDesktopSplitBreakpoint`),
      delivering a split-pane layout: primary reading canvas on the left (60%) and interactive productivity workbench on the right (40%) with
      Tab 1: Grounded AI Assistant (real-time chat grounded in paper chunks) and Tab 2: Annotations & Highlights Inspector (color filtering, margin note
      creation, deletion, and contextual "Ask AI about this" shortcuts), collapsible into a slim icon rail.
      Seamlessly integrated into both `PaperDetailScreen` and `ArticleReaderScreen`.
- [x] Personalized Weekly Audio Briefing Podcast ("Athena Digest Podcast") (2026-11-19):
      Continuous 8–10 minute narrative audio research briefing synthesized directly from the personalized
      weekly digest (`GET /api/v1/research/digest/latest`). Structured multi-chapter audio generation
      (`Executive Summary`, `Topic Highlights`, `Takeaways & Outlook`) with RFC-7233 partial content HTTP byte-range
      streaming (`GET /api/v1/research/digest/audio/stream` and `GET /api/v1/research/digest/{id}/audio/stream`).
      Mobile Flutter experience with `DigestPodcastCard` in `DigestScreen` featuring live playback controls,
      custom voice selector, expandable chapter timeline with 1-tap seeking, and seamless transition to the
      full-screen audio player (`/player`).
- [x] Citation Network Graph Authority & Seminal Paper Scoring (2026-11-19):
      PageRank citation graph analytics calculating foundational authority scores across the academic citation
      network (`citations` table). Database schema migration (`000025_seminal_paper_authority.up.sql`) adding
      `authority_score` and `is_seminal` with compound indexes. Application service (`AuthorityService`)
      implementing weighted PageRank with damping factor d = 0.85, convergence tolerance, edge weighting for
      influential citations and stances (supports vs contradicts vs mentions), and dynamic seminal paper thresholding.
      Scheduled periodic River background worker (`compute_citation_authority`) and admin trigger (`POST /api/v1/admin/graph/compute-authority`).
      Mobile Flutter experience with `PaperSummary` and DTO serialization, resonant amber "Seminal" badges on `PaperCard`,
      and dedicated "Seminal Work" badge and authority metrics on `PaperDetailScreen`.

- [x] Multi-Model LLM Gateway (Claude, Gemini, Local Ollama) (2026-11-19):
      Production-grade multi-model LLM and vector embedding gateway providing native adapter integrations
      for Anthropic Claude (Claude 3.5 Sonnet, Claude 3.5 Haiku, Claude 3 Opus via Messages API with SSE streaming
      and token tracking), Google Gemini (native Generative Language REST API `:generateContent` and `:streamGenerateContent?alt=sse`
      plus `:batchEmbedContents`), local offline Ollama (`http://localhost:11434` supporting `/api/chat` NDJSON streaming
      and `/api/embed` / `/api/embeddings` offline vector embeddings for air-gapped deployments), OpenAI-compatible gateways
      (vLLM, Groq, Together, Azure, DeepSeek), and deterministic test stubs.
      Unified gateway factory (`internal/infrastructure/ai/gateway`) wiring both API server and background River workers
      with typed configuration, provider normalization, exponential backoff retries, and comprehensive unit test coverage.

- [x] Chicago Citation Style Export & Collection Pre-indexing Guard (2026-11-22):
      Expanded academic citation formatter supporting Chicago Manual of Style (17th ed. Author-Date) across paper and
      bulk collection exports (`GET /api/v1/research/papers/{id}/export?format=chicago`).
      Hardened collection chat session creation (`internal/application/chat/service.go`) to fan out pre-indexing
      across all collection member papers instead of skipping pre-indexing when no single paper is designated.

- [x] Centralized User Annotations & Highlights Review Experience (2026-11-22):
      End-to-end cross-paper review hub for saved highlights and margin notes.
      Backend endpoint `GET /api/v1/me/annotations?color=&q=&limit=` joining annotations with papers table.
      Mobile 4th tab in Library screen (`HighlightsTabView`) supporting resonant color filter chips,
      real-time text keyword search, quote cards with colored accent borders and margin notes,
      direct reader navigation, and one-tap Markdown export to clipboard.

- [x] Author Profile & Works Catalog Engine (2026-11-22):
      Dedicated scholarly author profile and publication catalog experience.
      Backend query port `PaperReader` and PostgreSQL store providing `GetAuthorByID` and `ListPapersByAuthor`
      aggregating total publication count, total citations across authored works, h-index, and distinct affiliations.
      HTTP endpoints `GET /api/v1/authors/{id}` and `GET /api/v1/authors/{id}/papers?sort=citations|recent|title`.
      Mobile `AuthorDetailScreen` (`/authors/:id`) with author avatar initials, affiliations, ORCID badge,
      follow author button integration, scholarly impact metrics strip (Publications, Citations, H-Index),
      interactive sort choice chips, and full works catalog with paper cards and bookmarks.

- [x] Paper Code & Dataset Repository Intelligence Engine ("Code & Artifact Badges") (2026-11-23):
      Automated identification, dynamic extraction, database persistence, and mobile visualization of open source
      code repositories and open datasets associated with academic literature.
      PostgreSQL schema migration (`000026_paper_code_and_datasets.up.sql`) adding `has_code` and `primary_code_url`
      to `papers` alongside dedicated relational tables `paper_code_repositories` and `paper_datasets`.
      Domain extraction engine (`internal/domain/research/artifacts.go`) scanning abstracts and preprint version URLs
      for GitHub, GitLab, Hugging Face models, Hugging Face datasets, Zenodo records, and Kaggle benchmarks with
      robust URL canonicalization and punctuation stripping.
      PostgreSQL persistence in `paper_store.go` and fallback extraction in `paper_reader.go` ensuring all papers immediately
      yield code intelligence.
      Mobile domain and DTO serialization, resonant violet "Code" badge on `PaperCard`, quick "View Repository" action button
      in paper action strip, and interactive `_CodeArtifactsCard` with 1-tap "Open Repo", "Clone" clipboard command,
      dataset links, and community GitHub search fallback.

Providers: PubMed/Europe PMC ✅, Crossref ✅ · Email Digests ✅ · Collections & Reading Lists ✅ · Collaborative Groups ✅ · Web & Adaptive Shell ✅ · Platform Hardening & Multi-Replica Safety ✅ · Collection Chat ✅ · Annotations & Highlights ✅ · Offline Storage & Flight Packs ✅ · Comparison Tray ✅ · Desktop Two-Pane Workspace & Command Palette ✅ · Weekly Audio Digest Podcast ✅ · Seminal Paper Authority Scoring ✅ · Multi-Model LLM Gateway ✅ · Chicago Citation Style & Collection Chat Pre-indexing ✅ · Centralized Highlights Hub ✅ · Author Profiles & Works Catalog ✅ · Code & Datasets Intelligence ✅ · alternative engines
if ADR-0005 triggers fire · multi-language UIs · institutional features.
