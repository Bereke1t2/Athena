# Athena

> **Discover. Understand. Question. Connect.**

Athena is an AI-powered research discovery and learning platform. It helps users
discover, search, understand, discuss, and connect scientific research and
philosophical articles — with AI that is strictly grounded in the actual content of the
papers, not speculation.

| Component | Technology / Architecture |
|---|---|
| **Backend** | Go 1.26 (Clean Architecture modular monolith, standard library router) |
| **Mobile** | Flutter / Dart (Clean Architecture, Riverpod, go_router, Dio) |
| **Database** | PostgreSQL 16 + `pgvector` (768-dimension HNSW vector embeddings) |
| **Cache & Rate Limiting** | Redis 7 & Sliding-Window In-Memory Rate Limiter (`X-RateLimit-*`) |
| **Background Jobs** | River (PostgreSQL-backed transactional queue with retry and backoff) |
| **Research Sources** | Semantic Scholar, OpenAlex, arXiv, Crossref (provider-pluggable) |
| **AI & RAG** | Provider-agnostic LLM (Gemini 3.5, OpenAI, Stub) + RAG pipeline with citation validation |
| **Audio Studio** | LLM Brief Synthesis + TTS (OpenAI, Mock) with RFC-7233 byte-range HTTP streaming |
| **Push Notifications** | Multi-platform gateway router (Firebase Cloud Messaging HTTP v1, Apple Push Notification service HTTP/2) |

---

## Vision

Academic knowledge is abundant but inaccessible. Papers are locked behind
jargon, paywalls, and fragmented interfaces. Athena's goal is **not** to build
another search engine for PDFs. It is to build a learning companion around
research:

```text
Discover   →  see new, trending, and relevant research the moment it appears
Understand →  get explanations tuned to your level (beginner → expert) & listen to audio briefs
Question   →  talk to the paper; get grounded, cited answers via streaming RAG
Connect    →  explore citations, supporting/contradicting findings, and comparison matrices
```

Athena covers AI, computer science, physics, mathematics, biology, medicine,
psychology, neuroscience, philosophy, cosmology, social sciences, economics,
and more.

---

## Core Features

1. **Research Discovery Feed**
   - Latest and trending feeds with multi-topic OR filtering, canonical field rollups, and zero-result continuation fallback.
   - Interactive topic filter chips (`All Papers`, `AI & Tech`, `Quantum`, `Neuroscience`, `Biotech`, `Climate`).
   - Personalized recommendation feed driven by authenticated user topic-affinity scoring.

2. **Federated Live & Hybrid Search**
   - Keyword search using PostgreSQL weighted `tsvector` full-text search and trigram fuzzy matching.
   - Semantic search with 768-dimension pgvector embeddings (Gemini `text-embedding-004` / OpenAI `text-embedding-3-small`).
   - Federated live search (`GET /api/v1/search/live`) fanning out concurrently across arXiv, Semantic Scholar, OpenAlex, and Crossref with DOI/arXiv fingerprint deduplication and multi-signal ranking.

3. **Multi-Provider Ingestion & Taxonomy Mapping**
   - Pluggable provider adapters normalizing disparate metadata into unified bibliographic records.
   - Domain taxonomy classifier (`domain/taxonomy/classifier.go`) that dynamically resolves arXiv categories (`cs.*`, `math.*`, `physics.*`, etc.) and subtopics to canonical field parents (`000009_seed_fields`) during single-pass upserts.
   - Background River workers for continuous ingestion, metadata enrichment, and text chunk indexing.

4. **AI Research Summaries**
   - Four distinct explanation levels (Beginner, High School, Undergrad, Expert) breaking down key findings, methodology, results, and limitations.
   - Content-hash keyed caching ensuring cache hits cost zero tokens (`cache_hit=true`).
   - Honest grounding transparency labeling whether summaries are derived from `abstract` or `abstract+full_text`.
   - On-demand, opt-in card in the mobile client to avoid unnecessary token consumption.

5. **Grounded RAG Chat with Research**
   - Interactive Q&A grounded over chunked full-text representations using Server-Sent Events (SSE) streaming (`delta`, `done`, `error`).
   - Strict citation validation requiring assistant responses to embed valid retrieved chunk citations (`[chunk N]`).
   - One-shot regeneration and graceful refusal degradation ("The provided material does not contain enough evidence to answer this.") to prevent hallucinations.

6. **Audio Studio & RFC-7233 Byte-Range Streaming**
   - AI-synthesized research audio briefs (`POST /api/v1/research/papers/{id}/audio`) summarizing paper highlights in natural voice.
   - Open-standard RFC-7233 partial content HTTP audio streaming (`GET /api/v1/research/papers/{id}/audio/stream`, `Accept-Ranges: bytes`, `206 Partial Content`) supporting arbitrary seeking and fast buffer resumption.
   - Pluggable TTS adapters: OpenAI speech synthesis (`alloy`, `echo`, `fable`, `onyx`, `nova`, `shimmer`) and deterministic MPEG-1 Layer 3 frame mock generator.
   - Seamless mobile integration with generation actions on paper details and dedicated audio player screens.

7. **Multi-Paper Comparison Matrix**
   - Side-by-side comparison screen (`/compare`) contrasting methodology, datasets, agreements, and divergences across selected papers.

8. **Citation Intelligence & Multi-Format Export**
   - Citation stance classification (supporting, contradicting, mentioning) and topic velocity trend analytics.
   - Multi-format citation export sheet (BibTeX, APA, MLA, Chicago, RIS, Markdown) for rapid academic workflow integration.

9. **Personalization & Cloud Synchronization**
   - Dual-tab mobile Library screen managing both offline-capable `Saved Papers` and server-synchronized `Reading History`.
   - Debounced reading progress tracking across both reader and in-app PDF views.
   - Account-level cloud bookmark synchronization that automatically merges offline state on login or registration.

10. **Multi-Platform Push Notifications**
    - Concrete push notification gateway supporting Firebase Cloud Messaging (FCM HTTP v1) and Apple Push Notification service (APNs HTTP/2 alert envelopes).
    - Device token registration (`POST /api/v1/devices`) and lifecycle unregistration (`DELETE /api/v1/devices/{token}`).
    - Background ingestion fanout worker alerting users on new publications in followed topics, with automatic cleanup of invalid/stale device tokens (`ErrDeviceUnregistered`).

11. **Security, Protocol & Lifecycle Hardening**
    - **Inbound Rate Limiting**: Sliding-window rate limiter emitting standard `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`, and `Retry-After` headers.
    - **Idempotency-Key Deduplication**: Replays cached responses with `X-Cache-Lookup: HIT` for identical mutated requests.
    - **Conditional Caching**: Weak ETag computation and `304 Not Modified` empty responses for paper resource endpoints.
    - **Account Lifecycle**: Self-service password reset recovery flow (`/auth/forgot-password`, `/auth/reset-password`), JWT session refresh (`/auth/refresh`), and App Store Guideline 5.1.1(v) compliant account deletion (`DELETE /api/v1/me`).

12. **In-App PDF Reader**
    - Integrated native PDF viewer with Dio chunked downloads, progress bars, and deep link routing (`athena://paper/{id}`).

---

## Architecture

Full architectural documentation lives in [`docs/architecture/`](docs/architecture/overview.md).

```text
                               ┌──────────────────────────────────────────────────────────┐
                               │                   Research Providers                     │
                               │  arXiv · Semantic Scholar · OpenAlex · Crossref          │
                               └────────────────────────────┬─────────────────────────────┘
                                                            │ ResearchProvider adapters
                                                            ▼
                                        ┌───────────────────────────────────────┐
                                        │        Ingestion Pipeline             │
                                        │  Fetch → Classify → Deduplicate       │
                                        └───────────────────┬───────────────────┘
                                                            │
                                                            ▼
┌─────────────────────────────────┐     ┌───────────────────────────────────────┐
│     Background Workers          │     │        PostgreSQL 16 Storage          │
│  River Queue (Transactional)    │◄───►│  • Bibliographic records & sources    │
│  • Provider Sync & Enrichment   │     │  • Canonical topic taxonomy           │
│  • RAG Indexing & Chunk Embed   │     │  • Users, history & bookmarks         │
│  • Ingestion Push Fanout        │     │  • pgvector (768-dim HNSW embeddings) │
└────────────────┬────────────────┘     └───────────────────┬───────────────────┘
                 │                                          │
                 ▼                                          ▼
┌─────────────────────────────────┐     ┌───────────────────────────────────────┐
│   Push Notification Gateway     │     │             Go REST API               │
│  FCM (HTTP v1) · APNs (HTTP/2)  │     │  • Sliding-Window Rate Limiter        │
└────────────────┬────────────────┘     │  • Idempotency & ETag Middleware      │
                 │                      │  • FTS & Hybrid Vector Search         │
                 │                      │  • SSE Streaming Grounded Chat        │
                 │                      │  • Audio Studio Briefs & Byte-Ranges  │
                 │                      └───────────────────┬───────────────────┘
                 │                                          │
                 ▼                                          ▼
┌───────────────────────────────────────────────────────────────────────────────┐
│                          Flutter Mobile Client                                │
│  • Feed & Discovery Chips    • Dual-Tab Library (Saved & History)             │
│  • Grounded AI Summary Cards • Multi-Paper Comparison & Citation Export       │
│  • SSE Streaming Chat        • Audio Studio Player & In-App PDF Viewer        │
└───────────────────────────────────────────────────────────────────────────────┘
```

### Backend (Go, Clean Architecture)

Strict dependency rule: `delivery → application → domain`; infrastructure implements domain/application-defined ports. The domain layer has zero external dependencies — no HTTP, no SQL, no vendor SDKs.

```text
backend/
├── cmd/
│   ├── api/          # HTTP REST API server binary & composition root
│   ├── worker/       # River background queue worker binary
│   ├── migrate/      # Database migration runner binary
│   └── searchbench/  # Search relevance benchmark harness
├── internal/
│   ├── domain/           # Entities, value objects, domain ports (framework-free)
│   │   ├── audio/        # Audio brief models, Synthesizer & MediaStore ports
│   │   ├── notification/ # Notification types & PushSender interfaces
│   │   └── taxonomy/     # Canonical field classifier & arXiv prefix matcher
│   ├── application/      # Use cases, RAG chunker, audio service, auth orchestration
│   ├── infrastructure/   # Concrete adapters: Postgres, Redis, LLM, TTS, Push, Providers
│   │   ├── ai/tts/       # OpenAI & Mock MPEG-1 Layer 3 TTS synthesizers
│   │   └── push/         # FCM HTTP v1, APNs HTTP/2, and multi-platform router
│   ├── platform/         # Cross-cutting: config, slog logging, HTTP server kit, CORS
│   └── delivery/http/    # Handlers, SSE streaming, RFC-7233 audio streaming, middleware
├── migrations/           # Numbered SQL migrations (000001 through 000016)
└── tests/                # Integration test suites (testcontainers)
```

### Mobile (Flutter)

Feature-first Clean Architecture with Riverpod state management and strict import boundaries:

```text
mobile/lib/
├── core/                 # Constants, errors, network (Dio), routing, theme, utils
├── features/
│   ├── audio/            # Audio brief domain, player, and creation screens
│   ├── auth/             # Login, register, forgot-password, account deletion
│   ├── chat/             # SSE streaming chat with citation verification pills
│   ├── compare/          # Multi-paper side-by-side comparison matrix
│   ├── digest/           # Breakthrough digests and topic velocity pulses
│   ├── library/          # Dual-tab saved bookmarks and reading history
│   ├── onboarding/       # Topic preference selector
│   ├── papers/           # Feed chips, paper details, in-app PDF viewer, citations
│   ├── profile/          # User preferences, explanation level, account deletion
│   └── search/           # Live federated search and keyword filtering
└── main.dart             # Application bootstrap & dependency injection
```

---

## Technology Stack

| Component | Choice | Rationale |
|---|---|---|
| **Language** | **Go 1.26** | Type safety, lightweight memory footprint, low latency, first-class concurrency for ingestion. |
| **HTTP Router** | **Standard Library `net/http`** | Zero-dependency Go 1.22+ ServeMux with method and wildcard routing behind custom middleware chains. |
| **Primary Database** | **PostgreSQL 16** | Relational integrity for citations/authors, JSONB raw payloads, weighted FTS, transactional job store. |
| **Vector Engine** | **pgvector (768 dims)** | Co-located HNSW vector embeddings optimized for Google Gemini `text-embedding-004` and OpenAI Matryoshka models. |
| **Background Jobs** | **River** | Transactional enqueuing within PostgreSQL transactions, exponential backoff, dead-letter recovery. |
| **Cache & Limiting** | **Redis 7 & In-Memory** | Sliding-window request rate limiting, search/feed caching, and idempotency payload replay. |
| **AI / LLM** | **Gemini 3.5 & OpenAI** | Pluggable `LLMProvider` abstraction (`gemini-3.5-flash-lite`, `gpt-4o`, deterministic `stub`). |
| **Audio Synthesis** | **OpenAI TTS & Mock** | Natural voice synthesis (`OpenAISynthesizer`) with valid MPEG-1 Layer 3 mock adapter for offline testing. |
| **Push Gateway** | **FCM v1 & APNs HTTP/2** | Standards-compliant push delivery across Android, iOS, and Web with dead-token unregistration. |
| **Mobile App** | **Flutter / Dart** | Single codebase for iOS and Android with 60 FPS performance and native UI rendering. |
| **State Management** | **Riverpod** | Compile-safe dependency injection, provider caching, and reactive UI bindings. |

---

## Development Setup

### Prerequisites

- Go ≥ 1.26
- Flutter ≥ 3.41 (Dart ≥ 3.10)
- Docker & Docker Compose v2
- Make (optional)

### Environment Configuration

Copy the example environment template:

```bash
cp .env.example .env
```

Key environment configuration variables:

```env
# Database & Cache
ATHENA_DATABASE_URL=postgres://athena:athena@localhost:5433/athena?sslmode=disable
ATHENA_REDIS_ADDR=localhost:6380

# AI & Embeddings
LLM_PROVIDER=gemini                     # Options: gemini, openai_compatible, stub
LLM_MODEL=gemini-3.5-flash-lite
EMBEDDING_PROVIDER=gemini               # Options: gemini, openai_compatible, stub, none
EMBEDDING_DIM=768
EMBEDDING_MODEL=text-embedding-004

# Audio Studio & TTS
ATHENA_TTS_PROVIDER=mock                # Options: mock, openai, nop
OPENAI_TTS_MODEL=tts-1
OPENAI_TTS_VOICE=alloy

# Push Notifications
ATHENA_PUSH_PROVIDER=mock               # Options: mock, router, fcm, apns, nop
```

### Running Locally

```bash
# 1. Start Postgres and Redis
make up

# 2. Run database migrations
make migrate-up

# 3. Start the API server (http://localhost:8080)
cd backend && go run ./cmd/api

# 4. Start the background worker (in a separate terminal)
cd backend && go run ./cmd/worker

# 5. Start the Flutter mobile app
cd mobile
flutter pub get
flutter run --dart-define=ATHENA_API_BASE_URL=http://10.0.2.2:8080/api/v1  # Android emulator
# Or for iOS simulator:
# flutter run --dart-define=ATHENA_API_BASE_URL=http://localhost:8080/api/v1
```

---

## Testing & Quality Assurance

Athena enforces strict testing standards across the entire stack:

```bash
# Run all Go backend unit & application tests
cd backend && go test -count=1 ./...

# Run Go integration tests with Docker testcontainers
cd backend && go test -tags=integration ./tests/integration/...

# Run Flutter mobile unit & widget tests (50+ tests)
cd mobile && flutter test

# Verify Flutter code formatting & architectural import boundaries
cd mobile && dart analyze
```

---

## Roadmap & Status

| Phase | Description | Status |
|---|---|---|
| **Phase 0: Architecture & Specs** | Repository structure, ADRs, database schema, REST API spec, Docker Compose | ✅ Completed |
| **Phase 1: Research Aggregation** | Multi-provider adapters (arXiv, Semantic Scholar, OpenAlex, Crossref), deduplication, River queue | ✅ Completed |
| **Phase 2: Search & Discovery** | FTS keyword search, golden query benchmark, live federated search, Redis caching | ✅ Completed |
| **Phase 3: Flutter Foundation** | Mobile Clean Architecture, deep linking (`athena://`), error/empty/content state handlers | ✅ Completed |
| **Phase 4: AI Layer & RAG** | Multi-level summaries, grounded SSE chat, citation validation, pgvector (768 dims) | ✅ Completed |
| **Phase 5: Personalization & Push** | Auth, bookmarks cloud sync, reading history, push gateway (FCM HTTP v1, APNs HTTP/2) | ✅ Completed |
| **Phase 6: Advanced Intelligence & Audio** | Comparison matrix, citation stance/velocity, multi-format export, Audio Studio TTS & RFC-7233 streaming | ✅ Completed |
| **Phase 7: Cloud & Scaling (Next)** | Production hardening, web client, institutional library proxy integrations, multi-language support | 🚀 Next |

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
