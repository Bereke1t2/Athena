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
- **Topics**: migration `000009_seed_fields` seeds canonical `kind='field'` nodes; reader rolls up paper counts over children. Ingestion still creates parentless `topic` rows only — future work: map new topics to fields during ingestion.
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

1. **Final verification complete (2026-08-26)** — `flutter analyze` clean, `flutter test` all green (26 passed, 1 skipped integration). Gotcha discovered: `WisdomBannerCard`/`AthenaOwlCrest` (core/widgets/athena_branding.dart) repeats an AnimationController forever, so any test booting the app shell must use bounded `tester.pump(duration)` calls instead of `pumpAndSettle`. Feed header is now "ATHENA" branding (widget_test asserts this).
2. Widget/deep-link tests need `SharedPreferences.setMockInitialValues({'athena.onboarding.complete': true})` + `UserPreferences.instance.load()` in setUpAll (already present in widget_test.dart and deep_link_test.dart).
3. **Phase 5 in progress — auth slice DONE (2026-08-26)**: email+password
   accounts + opaque bearer sessions. Migration `000010_auth`
   (`users.password_hash`, `sessions` table, sha256-token-hash only). Layers:
   `domain/user` (ports + sentinels) → `application/auth` (Service; unknown-email
   and wrong-password both return ErrInvalidCredentials, real KDF run keeps
   timing uniform) → `infrastructure/auth` (stdlib crypto/pbkdf2 hasher,
   600k iters, self-describing hash format) + `infrastructure/database.UserStore`
   (implements BOTH user and session ports) → `delivery/http/v1/auth.go`
   (register/login/logout/me + WithAuth middleware that degrades bad tokens to
   anonymous). Routes registered only when Auth handlers non-nil. Verified live:
   register 201 / login 200 / bad login 401 / me 200 / logout 204→401 / dup 409.
   Next Phase 5 steps: server-side bookmarks (`bookmarks` table already exists),
   follow topics/authors, personalized `recommended` feed section
   (feed service still returns ErrNotImplemented for it), notification fan-out.
4. Future roadmap: Phase 5 remainder (above), Phase 6 comparison/digests. New ingested topics need field mapping (see above).
5. Pre-existing noise: some backend files fail gofmt (research/*, pgsearch.go, providers) — historical; format only files you touch. One info-level lint may remain in prefs files.
6. arXiv backfill rate limit (~100 rec/3s) and S2 bulk without API key are slow — documented in roadmap Phase 1 notes.
7. Dev API restart needs env vars exported manually (zsh can't source .env due to a parse error on line 32): ATHENA_HTTP_ADDR/:8080, ATHENA_DATABASE_URL (:5433), ATHENA_REDIS_ADDR (:6380), LLM_PROVIDER=stub.

## Style

- Backend: strict delivery→application→domain; ports in domain, adapters in infrastructure; snake_case wire DTOs; RFC-7807-ish error envelope; X-Request-ID everywhere.
- No comments unless explaining non-obvious invariants; keep the existing doc-comment style when adding files.
- Never commit unless asked; secrets stay out of git (.env is gitignored).
