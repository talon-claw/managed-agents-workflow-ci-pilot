## Why

`phase2-automation-platformization` already defines Track A as CI unified gate integration, but the repository still lacks a reviewed implementation slice that proves CI can invoke the repository-owned gate flow without expanding into scheduler orchestration, lease mutation, or task-spec writeback.

Without a dedicated CI pilot slice, any first workflow change would mix multiple high-risk concerns at once: CI trigger semantics, worktree shaping, manifest handling, and status mutation. That would make rollback and review too coarse.

## What Changes

- Introduce active change `phase2-ci-unified-gate-pilot` as the first CI implementation slice under `phase2-automation-platformization`.
- Add a minimal CI adapter path that runs the repository-owned gate flow in fixed order for one low-risk pilot task.
- Bind the first rollout to `Push + PR` triggers.
- Require CI to emit the same task-scoped artifact set expected by local Phase 2 runs, centered on the canonical `manifest.json`.
- Keep CI read-only with respect to task specs, change mirrors, and lease ownership.

## Out Of Scope

- Scheduler-driven execution or lease acquisition in CI.
- Automatic task-spec status writeback or change-level mirror updates.
- Guard/enforcement rollout beyond the existing repository behavior.
- Broad repo-wide task fan-out or multi-task matrix scheduling.
- Merge/release automation or any destructive auto-approval behavior.

## Impact

- Creates a reviewable first CI execution slice with bounded blast radius.
- Preserves local-vs-CI equivalence by forcing CI to call repository-owned scripts instead of ad-hoc commands.
- Keeps the first CI rollout inspectable: one pilot task, one manifest contract, one artifact bundle, no canonical-state mutation.
