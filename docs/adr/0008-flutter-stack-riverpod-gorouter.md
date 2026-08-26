# ADR 0008: Flutter stack — Riverpod, go_router, dio, freezed

- **Status:** accepted
- **Date:** 2026-08-22
- **Deciders:** Lead Architect

## Context

The mobile app must follow Clean Architecture (presentation/domain/data/core),
avoid business logic in widgets, handle loading/error/empty states uniformly,
and remain testable. The Flutter ecosystem offers several state management and
networking options; choosing late or mixing paradigms is a known source of
entropy.

## Decision

| Concern | Choice | Notes |
|---|---|---|
| State management + DI | **Riverpod** (+ codegen) | Compile-safe providers; testable without widget tree; no global mutable singletons |
| Routing / deep links | **go_router** | Declarative routes, typed args, deep links (`athena://paper/{id}`) |
| HTTP client | **dio** | Interceptors for auth token refresh, logging, retries; cancelable requests |
| Models | **freezed + json_serializable** | Immutable domain entities; separate API DTOs with mappers |
| Functional errors | Sealed `Failure` hierarchy (`freezed`) | Domain/data return `Result<T>`; UI maps failures to states |
| Local storage | flutter_secure_storage (tokens), shared_preferences (settings) | Never store tokens in prefs |
| Lint | flutter_lints + custom analysis_options | Enforced in CI |

Architecture rules mirrored from backend: widgets render state; controllers
(`Notifier`s) orchestrate use cases; repositories are interfaces in `domain/`
implemented in `data/`; API models never leak into presentation.

## Alternatives considered

| Option | Pros | Cons | Why rejected |
|---|---|---|---|
| Bloc | Mature, strict structure | Boilerplate-heavy; event→state ceremony slows iteration for feed/chat UX | Riverpod achieves same testability with less ceremony |
| Provider (package) | Simple | Runtime DI errors, weak reactivity model vs Riverpod | Superseded by Riverpod |
| getx | All-in-one speed | Anti-pattern-prone global state; poor test isolation | Violates architecture rules |
| http package | Minimal | No interceptors/retry/cancel ergonomics | dio pays for itself by auth phase |

## Consequences

**Positive:**

- Uniform AsyncValue handling gives consistent loading/error/empty UI.
- Feature folders can be developed/tested in isolation; fakes provided via
  Riverpod overrides.

**Negative / risks:**

- Codegen step (build_runner) required after model changes — accepted tradeoff;
  CI runs `dart run build_runner build --delete-conflicting-outputs`.

**Follow-ups:**

- [ ] Phase 3: establish theme tokens + AppRouter skeleton + ApiClient with
      interceptor tests before building screens.
