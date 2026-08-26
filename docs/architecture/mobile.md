# Mobile Architecture (Flutter)

## 1. Layering

```text
lib/
├── main.dart                    composition root (ProviderScope, router)
├── core/
│   ├── constants/               API base URL, durations, spacing tokens
│   ├── error/                   Failure hierarchy, Result type
│   ├── network/                 dio client, interceptors, connectivity
│   ├── routing/                 go_router config, guards
│   ├── theme/                   Material 3 themes, colors, typography
│   └── utils/                   formatters, extensions, debouncers
└── features/<feature>/
    ├── data/
    │   ├── dto/                 JSON models (freezed) mirroring the API
    │   ├── api/                 endpoint clients on core dio instance
    │   └── repositories/        implements domain interfaces
    ├── domain/
    │   ├── entities/            pure Dart models (no json annotations)
    │   ├── repositories/        abstract interfaces
    │   └── usecases/            single-responsibility application rules
    └── presentation/
        ├── screens/             widgets per route; stateless renderers
        ├── controllers/         Riverpod Notifiers / AsyncNotifiers
        └── widgets/             feature-local reusable widgets
```

Initial features: `research`, `search`, `ai_chat`, `bookmarks`, `topics`,
`notifications`, `recommendations`, `profile`, `onboarding`.

## 2. Data flow rule

```text
Widget → Controller (Riverpod) → UseCase → Repository interface
                                              ▲
                                    Data layer implementation
                                    (API DTO ⇄ domain entity mappers)
```

- Widgets never call dio. Controllers never import dto/.
- Domain entities are hand-written immutable classes; only data-layer DTOs are
  generated (freezed + json_serializable) and mapped explicitly.

## 3. State conventions

| State kind | Tool |
|---|---|
| Simple async reads (feed, search) | `AsyncNotifier` → UI via `AsyncValue.when` |
| Server-paginated lists | State class with `items + status + cursor`; loadMore() |
| Chat streaming | Stream-based controller consuming SSE |
| Cross-feature signals (bookmark toggled) | Narrow Riverpod providers, not global store |

Every list screen implements **loading / error / empty / content** states from
day one (enforced by a shared `AsyncListView` widget in Phase 3).

## 4. Error handling

`core/error/failure.dart`:

```dart
sealed class Failure { }
class NetworkFailure extends Failure { ... }
class ServerFailure extends Failure { final int? statusCode; ... }
class ValidationFailure extends Failure { ... }
class UnauthorizedFailure extends Failure { ... }
```

dio interceptor converts transport/status errors into failures; controllers
map them to user-facing messages; retry/backoff for idempotent GETs.

## 5. Routing & deep links

go_router with typed routes: `/feed`, `/search`, `/research/:id`,
`/research/:id/chat`, `/topics/:slug`, `/bookmarks`, `/notifications`,
`/profile`. Deep links (`athena://paper/{id}`, https universal links later)
resolve to the same routes — required for notification taps.

## 6. Configuration & environments

- `--dart-define=ATHENA_API_BASE_URL=...` injected at build time; no secrets in
  the app bundle ever.
- Flavors: dev (local backend), staging, prod (Phase 5 CI).

## 7. Testing

| Level | Scope | Tool |
|---|---|---|
| Unit | use cases, mappers, controllers | mocktail + Riverpod overrides |
| Widget | screens render all four states | flutter_test |
| Golden | theme-critical components | golden_toolkit (Phase 3+) |

CI gate: `flutter analyze` clean + tests green.
