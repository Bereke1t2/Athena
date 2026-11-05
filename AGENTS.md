# AGENTS.md — working notes for AI agents on Athena

Last updated: 2026-11-05 (AI conversation completeness, dual-stream elimination, citation regex flexibility & /chat route). Read this first.

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

1. **AI Conversation Completeness & RAG Dialogue Repair (2026-11-05)**:
   - **Scope**: Fixed broken and incomplete AI chat responses, streaming concatenation bugs, harsh refusal loops, and navigation routing for the conversational AI research assistant.
   - **Root Causes**:
     - *Dual-Stream Contamination*: When citation validation failed on the initial stream, `service.go` re-called `groundedAnswerStrict(..., onDelta)` with the live SSE callback. This streamed a second answer directly appended onto the first answer in the client's single buffer, producing repetitive, jumbled, or cutoff responses.
     - *Overwritten Responses on Strict Fallback*: If the LLM failed to include `[chunk N]` tags on the second pass, the backend discarded the generated answer and replaced `message.content` with `RefusalSentence` ("The provided material does not contain enough evidence to answer this."), completely wiping out good answers the user watched stream in.
     - *Hyper-Restrictive Citation Regex*: `chunkRefRe` previously only matched `[chunk N]` or `[source N]`. Standard numbered citations `[1]`, `[2]` or external bibliography brackets like `[2024]` caused `citedChunkIndices` to fail or invalidate the entire response.
     - *Prompt Refusal Forcing*: Grounding prompts ended with an imperative `"reply exactly: The provided material does not contain enough evidence to answer this."`, which caused instruction-tuned models (Gemini 3.5) to treat the refusal sentence as the expected output for general queries or methodology summaries.
     - *Unregistered `/chat` Route & Dummy Paper UUID*: Tapping the chat icon on `FeedScreen` or typing in `FloatingResearchPromptBar` previously failed or routed to search because `/chat` was missing in `app_router.dart`. Additionally, `ChatScreen` defaulted to a non-existent dummy UUID (`00000000-0000-0000-0000-000000000001`), violating the database foreign key constraint and throwing 400/500 errors.
   - **Core Deliverables**:
     - *Eliminated Dual Streaming* ([`chat/service.go`](file:///home/bereket/startup/Athena/backend/internal/application/chat/service.go)): Passed `nil` for `onDelta` during strict regeneration, protecting the SSE stream from duplicated text.
     - *Flexible Citation Extraction* ([`chat/service.go`](file:///home/bereket/startup/Athena/backend/internal/application/chat/service.go)): Updated `chunkRefRe` and `citedChunkIndices` to recognize standard `[1]`, `[2]`, `[chunk 1]`, and `[source 1]`, while safely ignoring external bibliography brackets.
     - *Balanced Grounding Prompts* ([`service.go`](file:///home/bereket/startup/Athena/backend/internal/application/ai/service.go), [`chat/service.go`](file:///home/bereket/startup/Athena/backend/internal/application/chat/service.go)): Instructed the model to answer thoroughly, clearly, and factually, reserving refusals strictly for queries completely outside the paper's scope.
     - *Warm Conversational Handling* ([`chat/service.go`](file:///home/bereket/startup/Athena/backend/internal/application/chat/service.go)): Expanded `handleGreeting` to handle help and introductory queries without citation refusal.
     - *Routing & Paper Resolution* ([`app_router.dart`](file:///home/bereket/startup/Athena/mobile/lib/core/router/app_router.dart), [`chat_screen.dart`](file:///home/bereket/startup/Athena/mobile/lib/features/ai/presentation/chat_screen.dart), [`floating_research_prompt_bar.dart`](file:///home/bereket/startup/Athena/mobile/lib/core/widgets/floating_research_prompt_bar.dart)): Registered `/chat` route, linked floating prompt bar to `/chat?q=...`, and resolved active papers reactively without dummy foreign key violations.
     - *Digest Navigation Icon Semantic Polish* ([`app_router.dart`](file:///home/bereket/startup/Athena/mobile/lib/core/router/app_router.dart)): Changed Digest tab icon from chat bubble to `Icons.auto_stories_outlined` (`auto_stories_rounded`), preventing confusion between editorial research digests and conversational AI chat.
   - **Verification**: Go backend tests 100% green (`go test -count=1 ./...`); Flutter tests 77 passed, 1 skipped (`flutter test`); static analysis clean (`dart analyze`, 0 issues).

2. **Platform Consistency & Branch Reconciliation (2026-11-04)**:
   - **Scope**: Reconciled unmerged branches (`feat/audio-studio-tts-engine`, `fix/ai-paper-chat-and-mobile-overflows`, `feat/platform-enhancements-and-phase5`), verified roadmap acceptance criteria for Phases 5 and 6, and synchronized test suites across both Go backend and Flutter mobile.
   - **Reconciliation Audit**:
     - *`feat/audio-studio-tts-engine`*: Commit `b8c52fd` documentation updates (`README.md`, `backend/README.md`, `mobile/README.md`) verified 100% identical and present on `main`.
     - *`fix/ai-paper-chat-and-mobile-overflows`*: Subtoken wildcard extraction, topic pattern synonyms (`ai`, `ml`, `llm`), feed zero-result widen guard, `gemini-3.5-flash-lite` config, and `activeTopicFilterProvider` verified 100% incorporated on `main`.
     - *`feat/platform-enhancements-and-phase5`*: Older snapshot verified fully superseded by Phase 5 and Phase 6 PR implementations (`/comparison`, `/citations`, `/audio`, and `weekly_digest.go`).
   - **Verification**: Go backend tests 100% green (`go test -count=1 ./...`); Flutter tests 76 passed, 1 skipped (`flutter test`); static analysis clean (`dart analyze`, 0 issues).

2. **Full-Text Paper RAG & Deep AI Conversation Engine (2026-11-02)**:
   - **Scope**: Fixed the root causes preventing full-text academic papers from being chunked, embedded, and retrieved in paper conversations (`ChatScreen`) and structured summaries (`POST /research/papers/{id}/summary`), which previously forced responses into "Based on only the abstract...".
   - **Root Causes**:
     - *Premature Context Cancellation in `HTTPFetcher.Fetch`*: In [`rag.go`](file:///home/bereket/startup/Athena/backend/internal/application/ai/rag.go), `defer cancel()` was placed inside `Fetch()` right after creating a timeout context. Because `resp.Body` is returned as a live stream, `defer cancel()` canceled the context before the caller could read the stream, causing `io.ReadAll` to fail with `read document stream: context canceled` on 100% of PDF/HTML fetches.
     - *Gemini Embedding 404 Endpoint Mismatch*: Configured model was `text-embedding-004`. Gemini's OpenAI-compatible endpoint (`/v1beta/openai/embeddings`) rejected this with HTTP 404. Gemini's active embedding model is `gemini-embedding-001` (with `dimensions: 768`).
     - *Academic Bot Blocking & Missing Citation PDF Resolution*: Publisher servers rejected `athena/0.1` user-agent with HTTP 403. Also, article landing pages contain `<meta name="citation_pdf_url" content="...">` and `<link rel="alternate" type="application/pdf" href="...">`, which were ignored.
     - *First-Turn Latency*: Ingestion only ran lazily on the first prompt in `Ask()`.
   - **Core Deliverables**:
     - *Stream Lifecycle & Realistic Headers* ([`rag.go`](file:///home/bereket/startup/Athena/backend/internal/application/ai/rag.go)): Wrapped `resp.Body` in a `cancelCloser` executing `cancel()` strictly upon `Close()`. Added realistic academic browser `User-Agent`, `Accept`, and `Accept-Language` headers.
     - *HTML Citation Metadata Discovery* ([`rag.go`](file:///home/bereket/startup/Athena/backend/internal/application/ai/rag.go)): Added `extractCitationPDFURL` scanning `<meta name="citation_pdf_url">` and alternate PDF links to download the full-text PDF directly when landing pages are encountered.
     - *Gemini Embedding Model Alignment* ([`config.go`](file:///home/bereket/startup/Athena/backend/internal/platform/config/config.go), [`.env`](file:///home/bereket/startup/Athena/.env)): Configured `gemini-embedding-001` with `dimensions: 768`, matching PostgreSQL's `vector(768)` schema.
     - *Background Pre-Indexing* ([`chat/service.go`](file:///home/bereket/startup/Athena/backend/internal/application/chat/service.go)): Triggered background indexing upon `CreateSession` so full-text chunks and embeddings are prepared ahead of the user's first prompt.
   - **Verification**: `go test -v -count=1 ./internal/application/ai/... ./internal/application/chat/...` 100% green; `go test -count=1 ./...` 100% green across all packages; `make build-backend` clean.

1. **AI Weekly Research Digest & Followed Topics Synthesis (2026-11-02)**:
   - **Scope**: Upgraded the Research Digest with recency-first paper queries published during the week, an overarching AI weekly executive briefing synthesizing what happened across followed topics, dynamic empirical takeaways, guest personalization via followed topic parameters, and explicit paper publication date badges.
   - **Root Causes**:
     - *Historical Paper Sorting*: Backend `appdigest.Service` previously queried `Sort: research.SortCitations` with no date boundaries, surfacing papers from years ago rather than research published during the current week.
     - *Missing Generative AI Narrative*: The briefing had no overarching generative synthesis explaining what occurred during the week across followed topics; `top_takeaways` were hardcoded boilerplate strings (`"Compiled %d relevant papers..."`).
     - *Guest User Topic Silo*: Unauthenticated users defaulted to a generic "Trending Across Athena" briefing because the API did not accept followed topics as query parameters, ignoring guest selections from onboarding.
   - **Core Deliverables**:
     - *Recency-First Ingestion & Resilient Fallback* ([`service.go`](file:///home/bereket/startup/Athena/backend/internal/application/digest/service.go)): Queries papers published during the last 7 days (`SortNewest` + `PublishedAfter: now - 7d`) per topic, with an automated fallback to newest papers if the strict 7-day cutoff contains fewer than 2 papers, guaranteeing relevant, newest research is always present.
     - *AI Weekly Synthesis Engine* ([`service.go`](file:///home/bereket/startup/Athena/backend/internal/application/digest/service.go)): Wired `domainai.LLMProvider` (Gemini / OpenAI-compat / offline stub) into `appdigest.NewService`. Formulates structured prompts feeding weekly papers, abstracts, and followed topics to generate:
       1. `ai_summary`: Cohesive 2-3 paragraph executive weekly briefing explaining what occurred this week across followed topics.
       2. `top_takeaways`: Specific empirical breakthroughs and methodological discoveries from actual papers.
       3. `topic_themes`: Dynamic momentum themes for `TopicPulse.KeyThemes`.
       Includes resilient deterministic fallback if LLM is offline or in stub mode.
     - *Database Persistence* ([`000019_digest_ai_summary.up.sql`](file:///home/bereket/startup/Athena/backend/migrations/000019_digest_ai_summary.up.sql), [`digest_store.go`](file:///home/bereket/startup/Athena/backend/internal/infrastructure/database/digest_store.go)): Added `ai_summary` column to `user_digests` table with automated scanning and saving.
     - *Topic Query Delivery* ([`digest.go`](file:///home/bereket/startup/Athena/backend/internal/delivery/http/v1/digest.go)): Updated `GET /api/v1/research/digest/latest` and `POST /research/digest/generate` to accept `?topics=slug1,slug2` query parameters and JSON body, allowing guests with local follows to receive fully tailored briefings.
     - *Mobile UI Overhaul* ([`digest_screen.dart`](file:///home/bereket/startup/Athena/mobile/lib/features/digest/presentation/digest_screen.dart)):
       - Added **✨ ATHENA AI · WEEKLY RESEARCH SYNTHESIS** card with coral aperture badge, grounded indicator, multi-paragraph synthesis, and topic chips.
       - Added calendar publication date badge (e.g. `12 Aug 2026`) to every paper card.
       - Upgraded guest banner informing users that their briefing is personalized to their followed topics.
       - Connected `followsNotifierProvider` to `DigestNotifier` to pass active followed topics automatically.
   - **Verification**: `dart analyze` clean (0 issues); `flutter test` 76 passed, 1 skipped (100% green); Go tests 100% green across all packages; Go binaries (`api`, `worker`) build cleanly.

1. **AI Chat UX Declutter & Input Visibility Enhancement (2026-11-01)**:
   - **Scope**: Eliminated unnecessary controls (model chooser capsule, non-functional paperclip and mic icons) from the chat prompt bar and dramatically increased input field width and text visibility.
   - **Root Causes**:
     - *Severely Constrained Input Width*: The docked prompt bar squeezed a paperclip button (34px), voice mic button (34px), model selector capsule (86px), and circular send button (36px) alongside the `TextField`. On standard mobile screens (~360dp), the text field was choked to an ~82px sliver, causing typed text to truncate and appear virtually invisible.
     - *Unnecessary Controls*: The bottom-sheet model picker was redundant as the backend manages inference models automatically.
   - **Core Deliverables**:
     - *Full-Width Input Field* ([`chat_screen.dart`](file:///home/bereket/startup/Athena/mobile/lib/features/ai/presentation/chat_screen.dart)): Removed the paperclip icon, mic icon, and model selector capsule, giving the `TextField` the entire width of the prompt card (~260px+). Increased font size to 15.0 with high-contrast text (`#FFFFFF` in dark mode, `#111827` in light mode), `cursorColor: AppTheme.coral`, and clear auto-expanding multi-line support.
     - *Dynamic Send & Clear Actions*: Added real-time text listener with a one-tap clear button (`✕`) when text is present, and an upward send button that lights up in vibrant `AppTheme.coral` as soon as text is typed.
     - *High-Contrast Message Bubbles*: Upgraded user speech bubbles to `#1E222D` with subtle coral border accent (`Border.all(color: AppTheme.coral.withValues(alpha: 0.45), width: 1.2)`) and crisp white `#F9FAFB` typography for instant, effortless legibility.
     - *Shared Floating Bar Streamlined* ([`floating_research_prompt_bar.dart`](file:///home/bereket/startup/Athena/mobile/lib/core/widgets/floating_research_prompt_bar.dart)): Cleaned model selector and non-functional attachments to maintain consistent minimalist editorial UX across all screens.
   - **Verification**: `dart analyze` clean (0 issues); `flutter test` 76 passed, 1 skipped (100% green); debug APK compiled cleanly.

1. **Topic Discovery & Profile Followed Topics Resolution (2026-11-01)**:
   - **Scope**: Resolved the missing followed topics in Profile and enhanced the Topics discovery experience across mobile.
   - **Root Causes**:
     - *Profile Missing Followed UI*: [`ProfileScreen`](file:///home/bereket/startup/Athena/mobile/lib/features/profile/presentation/profile_screen.dart) previously only had a navigation tile to `/topics` without displaying active topic chips, count badges, or quick-management actions.
     - *Topics Screen Lacked Following View*: [`TopicsScreen`](file:///home/bereket/startup/Athena/mobile/lib/features/topics/presentation/topics_screen.dart) only provided `[All]`, `[Fields]`, `[Topics]` segments with no way to filter by followed topics and no inline follow buttons on topic cards.
     - *Guest Follow Silo*: [`FollowsNotifier`](file:///home/bereket/startup/Athena/mobile/lib/features/follows/presentation/follows_notifier.dart) previously returned immediately for unauthenticated users, isolating onboarding topics in local storage without exposing them to the follow system.
     - *Detail Screen Wall*: [`TopicDetailScreen`](file:///home/bereket/startup/Athena/mobile/lib/features/topics/presentation/topic_detail_screen.dart) blocked guests with an abrupt redirect to `/login`.
   - **Core Deliverables**:
     - *Unified Follows Provider*: Enhanced [`FollowsNotifier`](file:///home/bereket/startup/Athena/mobile/lib/features/follows/presentation/follows_notifier.dart) to seamlessly support both guests (backed by `selectedTopicsProvider` and `UserPreferences`) and authenticated users (backed by `FollowsRepository`), with automatic backend synchronization when signing in.
     - *Profile Followed Topics Section*: Implemented `_FollowedTopicsCard` in [`ProfileScreen`](file:///home/bereket/startup/Athena/mobile/lib/features/profile/presentation/profile_screen.dart) displaying active hashtag chips (`# ${topic.topicName}`), live counter badge, one-tap navigation, quick unfollow `✕` action, and clean empty state with an "Explore Topics" CTA.
     - *Topics Screen Following Segment & Inline Follows*: Added `[Following]` segment to [`TopicsScreen`](file:///home/bereket/startup/Athena/mobile/lib/features/topics/presentation/topics_screen.dart) and added one-tap `_FollowTopicButton` (`+ Follow` / `✓ Following` pill) to every topic card for instant follow toggling directly from the list. Supported `/topics?filter=following` routing via [`app_router.dart`](file:///home/bereket/startup/Athena/mobile/lib/core/router/app_router.dart).
     - *Frictionless Topic Detail Screen*: Updated [`TopicDetailScreen`](file:///home/bereket/startup/Athena/mobile/lib/features/topics/presentation/topic_detail_screen.dart) to allow guest researchers to follow topics locally without being blocked.
   - **Verification**: `dart analyze` 0 issues (clean); `flutter test` 76 passed, 1 skipped (100% green); Go tests 100% green across all packages.

1. **App Opening Logo Spin & Aperture Animation, Obsidian Dark Default (2026-11-01)**:
   - **Scope**: Implemented animated app opening logo with fast-to-slow rotational deceleration and iris aperture opening reveal, and switched default app appearance to obsidian black (`ThemeMode.dark`).
   - **Core Deliverables**:
     - *Decelerating & Iris-Opening Emblem*: Implemented [`AthenaLaunchSplash`](file:///home/bereket/startup/Athena/mobile/lib/core/widgets/athena_launch_splash.dart) and [`AthenaAnimatedOpeningLogo`](file:///home/bereket/startup/Athena/mobile/lib/core/widgets/athena_launch_splash.dart) driven by an animation choreography:
       - Phase 1 (0 to ~1500ms): Rapid 3-revolution spin (1080°) that sharply decelerates via `Cubic(0.08, 0.82, 0.15, 1.0)` ease-out curve into level upright posture.
       - Phase 2 (1400ms to 1950ms): "And then open" aperture expansion where the 4 quarter shields slide outward along their diagonal axes (iris blades separating), the emerald central lens emits a radial pulse, and haptic feedback triggers.
       - Phase 3 (1850ms to 2200ms): Scale-up curtain dissolve (1.0 -> 1.25, opacity 1.0 -> 0.0) smoothly unveiling the loaded home screen beneath without layout shift or flicker. Tapping anywhere instantly skips to home.
     - *Dedicated Route & Root Gate*: Added `SplashScreen` in [`splash_screen.dart`](file:///home/bereket/startup/Athena/mobile/lib/features/splash/presentation/splash_screen.dart) and registered `/splash` route in [`app_router.dart`](file:///home/bereket/startup/Athena/mobile/lib/core/router/app_router.dart). Mounted `AthenaLaunchSplash` into `MaterialApp.router(builder: ...)` in [`main.dart`](file:///home/bereket/startup/Athena/mobile/lib/main.dart) so cold start animates seamlessly with zero overhead once finished.
     - *Default Black (Obsidian Dark Mode)*: Updated [`AppThemeModeNotifier`](file:///home/bereket/startup/Athena/mobile/lib/core/prefs/prefs_providers.dart) to default to `ThemeMode.dark` (obsidian `#101216`), persisting preference dynamically via [`UserPreferences.setThemeMode`](file:///home/bereket/startup/Athena/mobile/lib/core/prefs/user_preferences.dart).
   - **Verification**: `dart analyze` 0 issues (clean); `flutter test` 76 passed, 1 skipped (100% green); Go tests 100% green across all packages.

1. **Mobile UI Consistency & Design System Unification (2026-11-01)**:
   - **Scope**: Unified all 19 screens across Athena mobile to the Resarc editorial design system.
   - **Core Deliverables**:
     - *Universal Top Bar*: Implemented [`AthenaTopBar`](file:///home/bereket/startup/Athena/mobile/lib/core/widgets/athena_top_bar.dart) and [`AthenaCircularIconButton`](file:///home/bereket/startup/Athena/mobile/lib/core/widgets/athena_top_bar.dart) (`PreferredSizeWidget`) with circular outline actions, subtle borders, brandmark support, and safe pop handling across Navigator and GoRouter contexts.
     - *Universal Canvas*: Wrapped all screens in [`DotGridBackground`](file:///home/bereket/startup/Athena/mobile/lib/core/widgets/dot_grid_background.dart) on `AppTheme.lightBg` (`#FBFBFB`) and `AppTheme.deepDark` (`#101216`).
     - *State Views Overhaul*: Redesigned [`EmptyView`](file:///home/bereket/startup/Athena/mobile/lib/core/widgets/state_views.dart) and [`ErrorView`](file:///home/bereket/startup/Athena/mobile/lib/core/widgets/state_views.dart) with circular outline containers, coral accents, and pill-shaped retry buttons.
     - *Palette & Token Purity*: Eradicated all remaining legacy `canaryYellow` token references across `mobile/lib/`, migrating all accent badges, progress indicators, sparks, and pills to vibrant Resarc coral (`AppTheme.coral`). Replaced ad-hoc blue gradients in Digest with monochromatic card surfaces.
     - *Auth & Onboarding Polish*: Upgraded [`LoginScreen`](file:///home/bereket/startup/Athena/mobile/lib/features/auth/presentation/login_screen.dart) and [`RegisterScreen`](file:///home/bereket/startup/Athena/mobile/lib/features/auth/presentation/register_screen.dart) with [`AthenaArcEmblem`](file:///home/bereket/startup/Athena/mobile/lib/core/widgets/athena_branding.dart), rounded pill inputs/buttons, and updated [`OnboardingScreen`](file:///home/bereket/startup/Athena/mobile/lib/features/onboarding/presentation/onboarding_screen.dart) with coral pill selection.
     - *Screen Alignment*: Upgraded `SearchScreen`, `TopicsScreen`, `TopicDetailScreen`, `SavedScreen`, `DigestScreen`, `ProfileScreen`, `NotificationsScreen`, `ComparisonScreen`, `CreateAudioScreen`, and `PdfViewerScreen`.
   - **Verification**: `dart analyze` 0 issues (clean); `flutter test` 62 passed, 1 skipped; `go test -count=1 ./...` 100% green across all packages.

2. **Research Digest Error Resolution & Resilient Architecture (2026-11-01)**:
   - **Root Causes**:
     - *Wire Format Mismatch*: Backend directly serialized domain `UserDigest` using `WriteJSON(w, ..., d)`. Raw `DigestSection.Papers` (`research.PaperSummary` domain struct) was emitted in PascalCase (`ID`, `Title`, `Year`, `VenueName`, `IsOpenAccess`, `CitedByCount`). Mobile `PaperSummaryDto.fromJson` threw a fatal `TypeError` / `CheckedFromJsonException`.
     - *Missing Error Boundary*: `DigestRepositoryImpl` leaked raw `DioException` and `TypeError` straight into `DigestNotifier`, causing `ErrorView` to dump massive multi-line debug exceptions across the screen.
     - *Guest 401 Wall*: `/research/digest/latest` was mounted behind `RequireAuth`. Guest users navigating to the 4th tab received HTTP 401 Unauthorized, crashing the screen.
   - **Backend Fixes**:
     - Introduced `userDigestDTO` and `digestSectionDTO` in `backend/internal/delivery/http/v1/digest.go` with `newDigestDTO()` mapping all papers via `newSummaryDTO()` to standard snake_case `paperSummaryDTO` wire format.
     - Updated `appdigest.Service.GenerateDigest` and `GetLatestDigest` to support `userID == uuid.Nil`, generating dynamic trending science briefings for guest researchers without requiring database persistence.
     - Changed `GET /api/v1/research/digest/latest` in `httpserver/server.go` to use `WithAuth` (optional auth): authenticated users receive personalized briefings, while guests receive trending science briefings. Kept `POST /api/v1/research/digest/generate` protected by `RequireAuth`.
   - **Mobile Hardening**:
     - Updated `DigestRepositoryImpl` with `failureFromDio()` try/catch wrapping and defensive normalization in `_parseDigest()` (supporting snake_case, legacy/PascalCase keys, and skipping corrupt items without crashing).
     - Enhanced `DigestNotifier` to watch `authNotifierProvider` and automatically reload personalized briefings when users sign in.
     - Sanitized `ErrorView` in `core/widgets/state_views.dart` to prevent raw exception dumps from ever appearing in the UI.
     - Upgraded `DigestScreen` with `DotGridBackground`, Resarc editorial typography, guest callout banner with one-tap Sign In, and `RefreshIndicator` for pull-to-refresh.
   - **Verification**: `go test -count=1 ./...` 100% green; `dart analyze` clean (0 issues); `flutter test` 62 passed (1 skipped); Go binaries (`api`, `worker`, `migrate`) build cleanly.

2. **Topic Papers Sort Resolution & Newest/Citations Sorting (2026-10-31)**:
   - **Root Cause**: `TopicsRepositoryImpl.listResearch` and `TopicPapersNotifier` defaulted to `sort: 'relevance'`. The backend `research.go` handler rejected `relevance` with HTTP 400 `unknown sort sort: must be newest|citations`.
   - **Backend Hardening**: Updated `backend/internal/delivery/http/v1/research.go` to support `relevance` per `api-specification.md §2`, gracefully mapping relevance to citation ranking when no query text is supplied, and updated error detail whitelist to `must be newest|citations|relevance`.
   - **Mobile Topic Screen Enhancement**: Updated default sort to `newest` across `TopicsRepositoryImpl`, `TopicPapersNotifier`, and `_FakeTopicsRepository`. Enhanced `TopicDetailScreen` into a `ConsumerStatefulWidget` with interactive `[Newest]` / `[Most Cited]` ChoiceChips for dynamic paper sorting.
   - **Verification**: `go test -count=1 ./...` 100% green; `dart analyze` clean (0 issues); `flutter test` 58 passed (1 skipped).

2. **AI Conversation Screen Redesign (Resarc Aesthetic, 2026-10-31)**:
   - **AI Conversation Architecture**: Redesigned `ChatScreen` (`features/ai/presentation/chat_screen.dart`) into the full Resarc conversational research assistant:
     - Technical dot-grid canvas (`DotGridBackground`) covering the entire screen.
     - Editorial top bar: circular outline back button `←`, centered `ATHENA` brandmark with coral aperture emblem, and circular new session button `🔄`.
     - RAG Grounding banner with coral verified badge and active paper grounding context.
     - **Empty State Hero View**: Dynamic greeting ("Good Evening, Agnes / Scholar"), hero headline ("What are we exploring today?"), prominent `SuggestedPromptCard` with one-tap query trigger, and "EXPLORE SCHOLARLY INQUIRIES" quick prompt pills.
     - **Active Conversation Thread**: High-contrast right-aligned user bubbles and left-aligned assistant cards with `ATHENA arc-1a` coral branding, `GROUNDED` pill, streaming markdown formatting, and interactive citation chips with source excerpt modal sheet.
     - **Docked Floating Input Bar**: Integrated `FloatingResearchPromptBar` at the bottom with attachment, mic, `arc-1a` model selector capsule, and upward send button.
   - **Home Screen Alignment**: Removed the floating research prompt bar from the bottom of `FeedScreen` (`feed_screen.dart`) so the feed and 5-tab navigation shell scroll cleanly and unobstructed. Connected the top-bar Research Chat icon and `SuggestedPromptCard.onTap` to navigate directly into `ChatScreen`.
   - **Verification**: `dart analyze` clean (0 issues); `flutter test` 52 passed (1 skipped); live verified on phone `itel A667L` (Android 14) over wireless ADB.

2. **Search Engine & Topics Discovery Architecture (2026-10-31)**:
   - **Backend Pipeline & Provider Seeding**:
     - Added migration `000018_seed_crossref_source_and_backfill_topics` (`.up.sql` and `.down.sql`) seeding `crossref` into PostgreSQL `sources` table and retroactively attaching unparented topics to canonical field nodes.
     - Updated `PaperStore.upsertIdentifiers` and `ResolveCitationEdges` with catalog check `to_regclass('public.paper_references')` to safeguard transactions against missing reference table state.
   - **Mobile Two-Tier Search System**:
     - Added `isLive` flag to `SearchFilters` in `domain/search.dart` and implemented two-tier routing in `search_repository_impl.dart` (`/search` instant corpus vs `/search/live` federated web).
     - Wired router query parameters `/search?q=...` from `FloatingResearchPromptBar` to `SearchScreen(initialQuery: ...)`.
     - Added dual mode selector chips (`[Corpus]` / `[Live Web]`) and automated fallback button when corpus returns 0 results.
   - **Topics Search & Taxonomy Hierarchy**:
     - Converted `TopicsScreen` into stateful consumer with top `SearchBar` and debounced real-time search connected to `TopicListNotifier.search(query)`.
     - Added parent field badges to topic cards and resilient fallback hierarchy to `_TopicTaxonomyGraphCard`.
   - **Verification**: `go test -count=1 ./...` 100% green; `dart analyze` clean (0 issues); `flutter test` 57 passed (1 skipped).

2. **Editorial Research Assistant UI Redesign (Resarc Aesthetic, 2026-10-31)**:
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
