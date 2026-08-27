# Athena Mobile

Flutter client for Athena (Clean Architecture — see
[`docs/architecture/mobile.md`](../docs/architecture/mobile.md)).

Phase 0 ships the structure and a placeholder shell; screens arrive in
Phase 3.

## One-time setup

```bash
flutter pub get
flutter create . --platforms=ios,android --org dev.athena --project-name athena
```

## Run against local backend

```bash
# Android emulator reaches host via 10.0.2.2:
flutter run --dart-define=ATHENA_API_BASE_URL=http://10.0.2.2:8080/api/v1
```

## Structure

```text
lib/core/                 constants · error · network · routing · theme · utils
lib/features/<feature>/   data/ (dto, api, repositories) · domain/ (entities,
                          repository interfaces, usecases) · presentation/
                          (screens, controllers, widgets)
```

Rules: widgets render state only; controllers orchestrate use cases via
Riverpod; DTOs never leave the data layer; every list screen handles
loading/error/empty/content states.
