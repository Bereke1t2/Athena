# ADR 0009: Database migrations via golang-migrate

- **Status:** accepted
- **Date:** 2026-08-22
- **Deciders:** Lead Architect

## Context

The schema evolves through all phases (baseline → search indexes → embeddings
→ auth tables). Migrations must be reviewable, runnable from CI and from
Docker, and support both up and down paths.

## Decision

Use **golang-migrate** with sequential numbered SQL pairs:

```text
backend/migrations/
├── 000001_init_schema.up.sql
├── 000001_init_schema.down.sql
└── ...
```

- Plain SQL only (no Go migration funcs) — schema changes are reviewable diffs.
- Local execution via the dockerized CLI (`make migrate-up/down/new`) so no one
  must install a global tool.
- Every migration runs inside its transaction where DDL permits; long-running
  backfills are separate job types on the worker queue, never giant migrations.
- Down migrations are mandatory for every change and verified by CI
  (up → down → up round-trip).

## Alternatives considered

| Option | Pros | Cons | Why rejected |
|---|---|---|---|
| goose | SQL+Go migrations, simple | Go-mixing invites logic in migrations; smaller ecosystem | SQL-only discipline preferred |
| Atlas | Declarative diffing | Extra statefulness; less explicit history for reviewers | Imperative diffs fit our review style |
| ORM auto-migrate (GORM etc.) | Convenient | Dangerous outside dev; no down path | Not applicable — no ORM |

## Consequences

**Positive:** deterministic, CI-friendly, zero app-runtime magic.

**Negative / risks:** manual numbering conflicts on busy branches — resolved by
rebase conventions; acceptable at team size.
