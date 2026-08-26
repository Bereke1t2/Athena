# Mobile Conventions (Flutter/Dart)

## Architecture rules (enforced in review; lint where possible)

1. **No business logic in widgets.** Widgets build UI from state; decisions
   live in use cases/controllers.
2. **Layer imports are one-directional:** `presentation → domain`,
   `data → domain`, never `domain → data/presentation`. The dio client is
   importable only under `data/`.
3. **DTOs never leak.** API models (`*.dto.dart`) are mapped to domain entities
   at repository boundaries.
4. **Repository interfaces live in feature `domain/`**, implementations in
   feature `data/`; controllers depend on interfaces only (Riverpod providers
   inject implementations).
5. **Every list/detail screen handles four states**: loading, error, empty,
   content — via shared widgets (`AsyncListView`, `ErrorView`) introduced in
   Phase 3 rather than ad-hoc per screen.

## Naming & layout

| Thing | Convention | Example |
|---|---|---|
| Files | snake_case | `paper_detail_screen.dart` |
| Screens | `<Feature><Purpose>Screen` | `SearchScreen` |
| Controllers | `<Feature>Controller` / `<X>Notifier` | `FeedNotifier` |
| Providers | camelCase noun, generated `xProvider` | `feedProvider` |
| Entities | singular nouns | `Paper` |
| Feature folders | feature-first, three subfolders fixed | `features/search/data/…` |

## State management

- Prefer `AsyncNotifier` for server-backed reads; plain `Notifier` for local
  UI state; streams for chat SSE.
- Never mutate shared global state; pass dependencies via provider overrides
  in tests.
- Pagination state = `{items, status, cursor}` data class per list controller;
  expose `refresh()` and `loadMore()` only.

## Error handling

- Data layer throws/maps to sealed `Failure` types from `core/error/`; no raw
  exceptions cross into presentation.
- User-facing messages come from failure mappers (centralized), not inline
  strings scattered in screens.

## Networking

- One dio instance from `core/network/`; features declare endpoint methods on
  typed clients.
- Interceptors own auth headers, request IDs, logging (debug only), retry for
  idempotent GETs.
- Timeouts are constants in `core/constants/`; no magic numbers inline.

## Code generation

- freezed/json_serializable/riverpod_generator outputs (`*.g.dart`,
  `*.freezed.dart`) are committed-ignored? No — they are generated but must be
  reproducible via:

```bash
dart run build_runner build --delete-conflicting-outputs
```

- Never hand-edit generated files; CI regenerates and fails on diffs.

## Testing

- Controllers/use cases: unit tests with mocked repositories (mocktail).
- Screens: widget tests asserting all four states render correctly.
- Golden tests for theme-critical components once design stabilizes (Phase 3+).
- `flutter analyze` must be clean; treat infos as failures in CI.

## Accessibility & UX baseline

- Minimum tap targets 48dp; semantic labels on icons acting as buttons.
- Dark mode supported from Phase 3 via theme tokens, not per-widget colors.
- Text scales with system settings (never disable text scaling).
