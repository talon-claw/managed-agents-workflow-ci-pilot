## Why

Phase 0 only bootstrapped Git and OpenSpec preconditions. The repository still lacks an active Phase 1 skeleton that can replace frozen bootstrap drafts as the live planning entrypoint for the next implementation step.

## What Changes

- Create the active `phase1-skeleton` change as the Phase 1 planning container.
- Define the minimal skeleton scope for:
  - repository-stable design skeleton documents under `specs/design/`
  - execution task template under `specs/tasks/task-template.md`
  - governance files `AGENTS.md` and `CLAUDE.md`
  - project-level `.claude/settings.json`
  - script entrypoint skeletons (`lint.sh`, `typecheck.sh`, `test-unit.sh`, `test-integration.sh`, `test-e2e.sh`)
- Keep this change declarative only. Do not implement scripts, CI integration, or later-phase automation here.

## Impact

- Makes `openspec/changes/phase1-skeleton/*` the active specification source for Phase 1 work.
- Reduces reliance on frozen `docs/drafts/*.md` during implementation.
- Preserves the existing Phase 0 bootstrap boundary while enabling `/ccg:spec-impl` to start Phase 1 safely.
