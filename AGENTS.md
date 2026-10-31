# AGENTS.md — working notes for AI agents on Athena

Last updated: 2026-08-25 (end of a multi-feature session). Read this first.

## Stack & layout

- `backend/` Go 1.26 clean-architecture modular monolith (stdlib mux, pgx, River queue, Redis cache, Prometheus). Routes wired in `internal/platform/httpserver/server.go`; composition root `cmd/api/main.go` + `cmd/worker/main.go`.
- `mobile/` Flutter + Riverpod (codegen via riverpod_annotation), go_router, dio, freezed/json_serializable. DI in `lib/core/di.dart`. Run `dart run build_runner build --delete-conflicting-outputs` after touching annotated code.
- Docs live in `docs/` (roadmap.md tracks phase status; api/api-specification.md kept roughly current).

## Environment gotchas

- `.env`: DB = local Docker Postgres `localhost:5433`, Redis = `localhost:6380` (6379 belongs to another project!). A previously-running API instance predates this fix — restart `make api` + worker after config changes.
- Mobile hits `http://10.0.2.2:8080/api/v1` (Android emulator) via `--dart-define=ATHENA_API_BASE_URL`.
- Semantic Scholar circuit-breaks without `SEMANTICSCHOLAR_API_KEY`; federated search degrades gracefully per-provider (`meta.sources`).
- Live search takes 9–40s; mobile uses a 60s receive timeout for `/search/live`.

## Feature map (what exists now)

- **Federated live search** `GET /api/v1/search/live`: fans out to arXiv/S2/OpenAlex/Crossref concurrently (adapters have both `FetchWindow` ingestion and `Search()` live methods), merges duplicates (DOI > arXiv ID > title fingerprint), ranks relevance+gravity+recency+agreement, upserts into Postgres so results get UUIDs. Service: `backend/internal/application/discover/`.
- **Feed**: `/feed?topic=slug1,slug2` OR-matches topics. Topic filters match names case-insensitively (dashes→wildcards); zero-result first pages fall back to unfiltered with a `~`-prefixed cursor that skips topic filtering on continuation. See `application/feed/service.go`.
- **Topics**: migration `000009_seed_fields` seeds canonical `kind='field'` nodes; reader rolls up paper counts over children. Automated classifier (`domain/taxonomy/classifier.go`) and single-pass upsert (`database/paper_store.go`) dynamically map new topics to their canonical field parent during ingestion, retrofitting existing parentless topics.
- **Onboarding**: first launch → topic picker (`features/onboarding/`), stored in SharedPreferences via `UserPreferences`; router redirect gates everything. Feed watches `selectedTopicsProvider`.
- **AI layer (Phase 4, complete)**:
  - Summaries `POST /research/papers/{id}/summary {level}` — content-hash keyed cache, hits cost zero tokens (`cache_hit=true`, zeroed usage). Honest grounding labels: `abstract` vs `abstract+full_text`.
  - Chat `POST /chat/sessions`, `GET|POST /chat/sessions/{id}/messages` (SSE: delta/done/error events). Citation validation: `[chunk N]` indices must exist in retrieved set → one strict regeneration → forced refusal sentence ("The provided material does not contain enough evidence to answer this.").
  - RAG: PDF extract (`infrastructure/textextract`) → clean/chunk (~800 tok, overlap, section-aware; `application/ai/chunker.go`) → embed → pgvector HNSW. Retrieval = ANN + FTS fused via RRF. Lazy indexing on first summary/chat + `POST /admin/rag/index` (River job `rag_index_paper`, queue "ai").
  - Metrics: `athena_ai_tokens_total{feature,model,kind}`, `athena_ai_requests_total{feature,model,status=ok|refused|uncited|error|cache_hit}`.
  - LLM adapters: `openai_compatible` or deterministic `stub` (set `LLM_PROVIDER=stub` for offline dev).
- **Mobile extras**: saved-papers library (SharedPreferences JSON, `SavedPapers.prime()` in main, `/saved` route, bookmark toggle on paper detail), in-app PDF viewer (`flutter_pdfview`, dio download w/ progress to temp dir, `/papers/:id/pdf?url=&title=`), opt-in AI summary card (no auto-fetch — avoids surprise token spend AND test pumpAndSettle hangs).

## Architecture rules enforced by tests (don't break them)

- dio imports ONLY in `core/network` + data layers (`test/architecture/import_boundary_test.dart`). PDF download logic lives in `features/papers/data/pdf_repository_impl.dart`; pure URL resolution helper lives in domain (`pdf_repository.dart`).
- Domain layer stays framework-free; DTOs never leak above data layer.
- Feed notifier test fakes implement the `topics` param signature.

## Unfinished / verify next session

1. **Editorial Research Assistant UI Redesign (Resarc Aesthetic, 2026-10-31)**:
   - **Theme & Brand Tokens**: Upgraded `AppTheme` to the clean editorial aesthetic with vibrant coral primary accent (`#FF5238`), pristine off-white canvas (`#FBFBFB`), delicate borders (`#E5E7EB`), and jet black action accents (`#111827`). Added backwards-compatible token mapping for existing kit tokens.
   - **Brand & Visual Identity**: Added `AthenaArcEmblem` (quartered disc/aperture icon) and `AthenaEditorialBrandMark` (`ATHENA` wordmark + coral emblem) to `athena_branding.dart`.
   - **Canvas Background**: Created `DotGridBackground` and `DotGridPainter` in `core/widgets/dot_grid_background.dart` rendering the subtle technical ideation grid.
   - **Universal Floating AI Research Prompt Bar**: Implemented `FloatingResearchPromptBar` in `core/widgets/floating_research_prompt_bar.dart` matching the closeup mockup ("Curious? Ask and dive into scholarly insights", circular paperclip, circular voice mic, `arc-1a` model selector capsule, and black circular upward send button).
   - **Home / Exploration Screen**: Redesigned `FeedScreen` with double-line menu icon, `AthenaEditorialBrandMark`, hero greeting ("Good Evening, Agnes / Scholar. What are we exploring today?"), `SuggestedPromptCard`, and pinned floating AI prompt bar.
   - **Research Report / Reader Screen**: Redesigned `ArticleReaderScreen` into the editorial **"Research Report"** layout: circular close `✕` button, circular more `⋮` button, carousel progress dots (`· · · 🔴 ·`), date stamp, bold research question headline, lead takeaway paragraph, uppercase coral headers (`ABSTRACT`, `METHOD ∨` collapsible), and docked floating prompt bar.
   - **Minimalist Navigation Shell**: Enhanced `_HomeShell` in `app_router.dart` with 5 clean outline tabs (Feed, Search, Topics, Digest, Saved) with coral active indicator.
   - **Verification**: `flutter test` 52 passed (1 skipped); `dart analyze` clean (0 issues); `go test -count=1 ./...` 100% green.

2. **Citation Network Graph Pipeline & Visual Graph System (2026-10-31)**:
   - **Backend Pipeline & Two-Way Resolution**:
     - Added migration `000017_paper_references` (`.up.sql` and `.down.sql`) establishing raw reference staging.
     - Updated `PaperStore.ResolveCitationEdges` and `upsertIdentifiers` in `database/paper_store.go` to persist extracted raw references and resolve bidirectional citation edges across DOIs, ArXiv IDs, and external IDs whenever cited papers arrive in the system.
     - Updated `crossref.go` and `s2.go` provider adapters to query and parse reference lists alongside OpenAlex during ingestion and search.
     - Updated `PaperReader.GetCitationGraph`, `ListCitations`, and `ListCitationDetails` in `database/paper_reader.go` with an automated topic-connected research network fallback when explicit citation edges are 0.
   - **Mobile Graph Visualizations**:
     - **Interactive Citation Network Canvas** (`paper_detail_screen.dart`): Replaced list-only view with interactive 60fps canvas (`_InteractiveCitationGraphCanvas`, `_CitationGraphPainter`) featuring radial concentric orbits (Seed center, Hop-1 inner ring, Hop-2 outer ring), pinch-to-zoom/pan (`InteractiveViewer`), stance-colored edges (supports, contradicts, mentions), directional pulse indicators, glow rings, node citation-count scaling, and tap-to-inspect docked detail sheet with deep navigation. Dual-mode toggle (`[Visual Graph]` / `[List View]`).
     - **Topic Taxonomy Knowledge Graph** (`topic_detail_screen.dart`): Added `_TopicTaxonomyGraphCard` and `_TopicTaxonomyPainter` visualizing parent academic field, central topic node, and subtopics with bidirectional branch connectors and tap navigation.
     - **Research Digest Velocity Sparklines** (`digest_screen.dart`): Added `_VelocitySparklinePainter` rendering dynamic cubic Bezier trend curves with gradient fill and crest dots for topic velocity pulses.
   - **Verification**: `go test -count=1 ./...` 100% green; `dart analyze` clean (0 issues); `flutter test` 52 passed (1 skipped); binaries `bin/api`, `bin/worker`, and `bin/migrate` build cleanly.

2. **Audio Studio Physical TTS Generation & HTTP Audio Streaming (2026-10-30)**:
   - **TTS Synthesizer & Media Storage**: Added `domain/audio` interfaces (`Synthesizer`, `MediaStore`), implemented `infrastructure/ai/tts` adapters (`OpenAISynthesizer`, `MockSynthesizer` generating valid MPEG-1 Layer 3 frames, and thread-safe in-memory `MemoryMediaStore`).
   - **Byte-Range Streaming**: Implemented `GET /api/v1/research/papers/{id}/audio/stream` with standard RFC-7233 byte-range seeking (`Accept-Ranges: bytes`, `206 Partial Content`) via `http.ServeContent` and lazy synthesis fallback.
   - **Configuration & Wiring**: Wired `TTSProvider` (`mock`, `openai`, `nop`) in `config.go`, composition root `cmd/api/main.go`, and updated mobile `AudioTrack.audioUrl`.
   - **Verification**: `go test -count=1 ./...` 100% green; `cd mobile && flutter test` 50 passed (1 skipped); `dart analyze` clean (0 issues); all binaries compile cleanly.

2. **Ingestion Topic-to-Field Classifier & Taxonomy Mapping (2026-10-30)**:
   - **Domain Classifier**: Implemented `backend/internal/domain/taxonomy/classifier.go` with fast-path arXiv taxonomy prefix resolution (`cs.*`, `math.*`, `physics.*`, `q-bio.*`, `econ.*`, `eess.*`), exact field matching, and ordered regex rules matching `000009_seed_fields` with cross-domain negative guardrails.
   - **Database Store Resolution**: Updated `PaperStore.resolveFieldID` with thread-safe RWMutex in-memory caching of canonical `field` UUIDs; upgraded `upsertTopics` to a single atomic `INSERT ... ON CONFLICT (slug) DO UPDATE` with `parent_id` attachment and retrofitting of unparented legacy topics.
   - **Verification**: `go test -count=1 ./...` 100% green; all binaries (`api`, `worker`, `migrate`) build cleanly.

2. **Concrete Push Notification Gateway (2026-10-30)**:
   - **Infrastructure Gateway**: Implemented `backend/internal/infrastructure/push/` featuring `FCMClient` (Firebase Cloud Messaging HTTP v1), `APNSClient` (Apple Push Notification service HTTP/2 alert envelope), `Router` (multi-platform dispatch to iOS/Android/Web), and `MockSender` / `LoggingSender` / `NopSender`.
   - **Token Invalidation & Auto-Unregister**: Added `domainnotification.ErrDeviceUnregistered` mapping HTTP 404/410/UNREGISTERED/BadDeviceToken; automatic stale device token cleanup wired into both `notification.Service` and `NotificationFanoutWorker`.
   - **Worker & Server Wiring**: Wired `push.New(cfg, log)` in both `cmd/api/main.go` and `cmd/worker/main.go` with configurable environment variables (`ATHENA_PUSH_PROVIDER`, `FCM_PROJECT_ID`, `APNS_KEY_ID`, etc.).
   - **Verification**: All Go unit tests passing 100% green across all packages; `bin/api`, `bin/worker`, and `bin/migrate` compiled cleanly.

2. **Protocol, Security & Mobile Experience Hardening (2026-10-29)**:
   - **Password Reset Flow**: Added migration `000015_password_resets`, implemented `RequestPasswordReset` and `ResetPassword` on domain user store and auth service. Exposed `POST /api/v1/auth/forgot-password` and `POST /api/v1/auth/reset-password` on Go backend. Added "Forgot Password?" dialog and repository/notifier dispatch in Flutter `LoginScreen`.
   - **Push Device Registration & Seam**: Added migration `000016_user_devices`, implemented `RegisterDevice`, `UnregisterDevice`, and `ListDevicesByUser` on PostgreSQL `NotificationStore`. Exposed `POST /api/v1/devices` and `DELETE /api/v1/devices/{token}`. Connected push dispatch seam to `NotificationFanoutWorker`.
   - **Idempotency-Key Deduplication**: Implemented `v1.WithIdempotency` middleware with in-memory TTL caching and replaying of responses with `X-Cache-Lookup: HIT` for duplicate requests.
   - **ETag / If-None-Match Conditional Caching**: Added weak ETag calculation and `304 Not Modified` empty response handling on `GET /api/v1/research/papers/{id}`, and exposed `ETag` in CORS.
   - **Mobile Audio Studio & Paper Linking**: Connected `CreateAudioScreen` to backend `POST /api/v1/research/papers/{id}/audio` with parameter extraction (`paperId`), and added "Generate Audio Brief" CTA and AppBar actions in `PaperDetailScreen`.
   - **Full Verification**: Go backend tests `go test -count=1 ./...` 100% green (all packages); Flutter `dart analyze` clean (0 issues); `flutter test` green (50 passed, 1 skipped); binaries `bin/api`, `bin/worker`, `bin/migrate` compiled cleanly.

2. **Inbound Rate Limiting & Account Lifecycle (2026-10-28)**:
   - **Inbound Rate Limiter**: Implemented `v1.WithRateLimit` and `MemoryRateLimiter` sliding window; emits `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`, and `Retry-After` on 429 `rate_limited` responses per `api-specification.md §1`. Supports 300 req/min authenticated, 60 req/min anonymous, 10 req/min live search, and 20 req/min generative AI. Exposed via CORS headers.
   - **Account Deletion (App Store Guideline 5.1.1(v))**: Implemented `DELETE /api/v1/me` in Go backend (soft-deletes account, cascades session revocations) and added "Delete Account" confirmation dialog and repository/notifier action in Flutter `ProfileScreen`.
   - **Session Refresh & Explanation Preference**: Added `POST /api/v1/auth/refresh` and `PUT /api/v1/me/explanation-level`, reading and updating PostgreSQL `users.preferred_explanation_level`.
   - **Verification**: `go test -count=1 ./...` 100% green (all packages); `dart analyze` clean (0 issues); `flutter test` green (49 tests passed).

2. **Core Architecture Alignment & Hardening (2026-10-28)**:
   - **Schema Migration 000012 (pgvector 768 dims)**: Added `000012_embedding_dim_768` (`.up.sql` and `.down.sql`) to migrate `chunk_embeddings.embedding` to `vector(768)` and `dim` default to `768`, aligning with Google Gemini `text-embedding-004`.
   - **Config & Default Dimension**: Updated `config.go`, `config.example.env`, `.env.example`, `.env`, and `render.yaml` to default `EMBEDDING_DIM=768` and `EMBEDDING_MODEL=text-embedding-004` when `EMBEDDING_PROVIDER=gemini`.
   - **OpenAI-Compatible Dimensions Support**: Updated `openaicompat.Embedder` to support explicit `Dimensions` on request payloads for models supporting Matryoshka reduction (e.g. `text-embedding-3-small` at 768 dims).
   - **Stub Embedder**: Updated `stubai.NewEmbedder` fallback dimension to 768.
   - **Schema Migration 000013 (Digest Persistence)**: Created `000013_user_digests` (`.up.sql` and `.down.sql`) and PostgreSQL `database.DigestStore` implementing `domaindigest.DigestRepository`; wired `DigestStore` into `cmd/api` and `cmd/worker` composition roots.
   - **CORS Middleware**: Implemented standard CORS middleware in `httpserver/server.go` honoring `ATHENA_CORS_ALLOWED_ORIGINS` with full preflight handling and unit tests.
   - **CI/CD & Docker Compose Worker**: Created `.github/workflows/ci.yml` (automated Go vet, Go test, Go build, Flutter analyze, Flutter test) and added `athena-worker` container to `docker-compose.yml`.

2. **Gemini 3.5 Migration & Feed Topic Chips (2026-10-26)**:
   - **Google Gemini Model Upgrade**: Switched default LLM provider model to `gemini-3.5-flash-lite` across `config.go`, `render.yaml`, and `.env.example` following upstream deprecation of `gemini-2.0-flash`.
   - **Database Topic Reader**: Enhanced `topicNamePatterns` with tokenization and domain synonym expansion (`ai`, `ml`, `llm`, length >= 4 subtokens); enabled name pattern resolution on single-topic queries in `ListPapers`.
   - **Mobile Home Feed**: Added interactive `_TopicFilterChip` bar to `FeedScreen` (`All Papers`, `AI & Tech`, `Quantum`, `Neuroscience`, `Biotech`, `Climate`); defaulted to `all` so feed delivers continuous discovery without 4-paper starvation.
   - **Verification**: `go test -count=1 ./...` 100% green; `flutter analyze` clean; `flutter test` green (47 tests passed).
2. **Full Verification Complete (2026-10-24)**:
   - **Render Production Deployment**: Live and healthy at `https://athena-r3uq.onrender.com/`. Probes `/healthz` and `/readyz` returning `200 OK`.
   - **Neon PostgreSQL**: Migrated through version 11 (`red-flower-69685834`, Oregon) with auto-migration on boot.
   - **Corpus & Paper Seeding**: 34 research papers ingested across AI, Quantum Computing, Neuroscience, Climate Change, and Biotechnology with full metadata, topics, and DOI/OA links.
   - **Mobile Default Wiring**: Default API URL in `app_constants.dart` wired to `https://athena-r3uq.onrender.com/api/v1`.
   - **Tests**: `flutter analyze` clean (0 issues), `flutter test` green (46 unit/widget tests + live contract integration test passed), `go test -count=1 ./...` 100% green.
2. **Phase 5 & 6 Milestone Completed & Hardened (2026-10-20)**:
   - **Backend Reading History**: Migration `000011_reading_history`, PostgreSQL `HistoryStore`, API routes `/api/v1/me/history`.
   - **Mobile Reading History**: Domain models, `HistoryRepositoryImpl`, `HistoryNotifier`, Dual-Tab Library screen (`Saved` + `Reading History`), debounced progress hooks in `ArticleReaderScreen` and `PdfViewerScreen`.
   - **Server-Side Bookmarks Synchronization**: `BookmarksRepositoryImpl`, `SavedPapers` cloud sync when authenticated with offline fallback, and login/register auto-sync.
   - **Research Digest Mobile Experience**: `DigestRepositoryImpl`, `DigestNotifier`, `/digest` screen with topic velocity pulses, key breakthroughs, and curated sections, plus notification direct-routing.
   - **River Ingestion & Notification Fanout**: `NotificationFanoutWorker` fanning out ingestion alerts to topic and author subscribers via River queue `"notifications"`.
   - **Multi-Paper Comparison Matrix**: Side-by-side comparison screen (`/compare`), consensus/divergence cards, and dynamic paper selection.
   - **Citation & Export**: Multi-format export modal sheet (BibTeX, APA, MLA, Chicago, RIS, Markdown) and Citation network explorer cards.
   - **Database Integrity & DevEx**: Added `000002_add_paper_sources.down.sql`, sanitized `.env` `ARXIV_USER_AGENT` to eliminate shell parse error on source.
3. Dev API restart: ATHENA_HTTP_ADDR/:8080, ATHENA_DATABASE_URL (:5433), ATHENA_REDIS_ADDR (:6380), LLM_PROVIDER=stub.


## Style

- Backend: strict delivery→application→domain; ports in domain, adapters in infrastructure; snake_case wire DTOs; RFC-7807-ish error envelope; X-Request-ID everywhere.
- No comments unless explaining non-obvious invariants; keep the existing doc-comment style when adding files.
- Never commit unless asked; secrets stay out of git (.env is gitignored).
