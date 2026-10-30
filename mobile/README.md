# Athena Mobile

Flutter mobile client for Athena, built with Feature-First Clean Architecture, Riverpod, go_router, and Dio.

See detailed architectural documentation in [`docs/architecture/mobile.md`](../docs/architecture/mobile.md).

---

## Features

- **Home Feed & Discovery**: Interactive topic filter chips (`All Papers`, `AI & Tech`, `Quantum`, `Neuroscience`, `Biotech`, `Climate`), latest & trending research, and personalized recommendations.
- **Search & Live Discovery**: Fast keyword search with filters (date, open access, citations) and federated live querying.
- **Reading Experience**: Native article detail reader with typography controls and integrated in-app PDF viewer (`flutter_pdfview`) with Dio download progress tracking.
- **AI Research Summaries**: Multi-level explanation cards (Beginner, High School, Undergrad, Expert) with honest grounding indicators (`abstract` vs `abstract+full_text`).
- **Grounded Streaming Chat**: Real-time Server-Sent Events (SSE) chat with verifiable chunk citations (`[chunk N]`) and refusal protection against hallucinations.
- **Audio Studio**: AI brief generation (`CreateAudioScreen`) and RFC-7233 byte-range streaming audio player (`AudioPlayerScreen`) with scrubber seeking.
- **Library (Dual-Tab)**: Offline-first `Saved Papers` with automatic cloud synchronization, plus tracked `Reading History` with debounced progress updates.
- **Multi-Paper Comparison**: Side-by-side comparison matrix (`/compare`) contrasting methodology, findings, consensus, and divergences.
- **Citation Intelligence & Export**: Interactive citation network sheet with stance badges (supporting/contradicting/mentioning) and multi-format bibliography export (BibTeX, APA, MLA, Chicago, RIS, Markdown).
- **Authentication & Account Lifecycle**: Email authentication, self-service password recovery flow, session token refresh, and App Store Guideline 5.1.1(v) compliant account deletion.
- **Deep Linking**: Seamless URL handling for `athena://paper/{id}` directly routing to paper details.

---

## Getting Started

### Prerequisites

- Flutter ≥ 3.41 (Dart ≥ 3.10)
- Android Studio / Xcode for device simulation

### Setup & Code Generation

```bash
cd mobile
flutter pub get

# Generate Riverpod providers and JSON serialization models
dart run build_runner build --delete-conflicting-outputs
```

### Running the App

```bash
# Against local backend on Android emulator (host is 10.0.2.2)
flutter run --dart-define=ATHENA_API_BASE_URL=http://10.0.2.2:8080/api/v1

# Against local backend on iOS simulator (host is localhost)
flutter run --dart-define=ATHENA_API_BASE_URL=http://localhost:8080/api/v1

# Against deployed production backend
flutter run --dart-define=ATHENA_API_BASE_URL=https://athena-r3uq.onrender.com/api/v1
```

---

## Architecture & Code Structure

```text
lib/
├── core/                       # Cross-cutting foundational modules
│   ├── constants/              # API endpoints, assets, layout constants
│   ├── di.dart                 # Dependency injection wiring
│   ├── errors/                 # Domain failure hierarchy & mapping
│   ├── network/                # Dio client, auth interceptor, base URLs
│   ├── routing/                # go_router configuration & route guards
│   ├── theme/                  # Dark/light theme definitions & typography
│   └── utils/                  # Formatting, debounce, platform helpers
│
└── features/                   # Feature-first modular packages
    ├── audio/                  # Audio brief generation, streaming playback
    ├── auth/                   # Authentication, password recovery, session
    ├── chat/                   # Grounded SSE chat with citation chips
    ├── compare/                # Multi-paper comparison matrix
    ├── digest/                 # Breakthrough digests & velocity pulses
    ├── library/                # Saved bookmarks & reading history
    ├── onboarding/             # Topic selector & preferences
    ├── papers/                 # Feed, detail, PDF viewer, citation export
    ├── profile/                # Settings, explanation preferences, account deletion
    └── search/                 # Federated live search & filtering
```

### Architectural Guardrails

- **Strict Import Boundaries**: `Dio` is restricted strictly to `core/network` and feature data layers. DTOs never cross above the data layer. Domain models remain free from Flutter UI framework dependencies. (Enforced by `test/architecture/import_boundary_test.dart`).
- **Unified State Machine**: List screens consistently implement loading, error, empty, and content states using shared widget primitives.
- **Token Efficiency**: AI summaries and audio briefs are explicitly opt-in to avoid unexpected token usage or background latency.

---

## Testing

```bash
# Run unit, widget, and architectural boundary tests (50+ tests)
flutter test

# Run static analysis
dart analyze
```
