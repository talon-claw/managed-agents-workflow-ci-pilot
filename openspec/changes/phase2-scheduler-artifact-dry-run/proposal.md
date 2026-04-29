## Why

`phase2-automation-platformization` now defines implementation-ready contracts for scheduler envelopes, run artifacts, leases, and derived writeback boundaries. The next step should prove the smallest closed loop that exercises those contracts without activating high-risk automation surfaces.

Without a dedicated first implementation slice, scheduler and writeback work would be mixed with CI enforcement or guard rollout, making failures harder to classify and rollback.

## What Changes

- Introduce active change `phase2-scheduler-artifact-dry-run` as the first implementation slice under `phase2-automation-platformization`.
- Implement a dry-run scheduler path that:
  1) creates a run envelope for one task
  2) writes `search-plan.md`, `manifest.json`, and `active-lease.json`
  3) records verify/review/acceptance outcomes into the canonical artifact layout
  4) performs task-spec status writeback only under the declared fail-closed rules
- Allow optional derived mirror writeback only after task-spec writeback succeeds.

## Out Of Scope

- Real CI wiring or CI-triggered execution
- Guard/enforcement activation beyond existing local hooks
- Autonomous merge, release, or destructive command approval
- Multi-task scheduling, lease takeover, or concurrent writer support

## Impact

- Creates the first executable proof that Phase 2 contracts can run end-to-end on one low-risk task.
- Keeps risk bounded to repository-local dry-run orchestration and artifact generation.
- Provides the baseline for later CI and guard tracks without coupling them into the first implementation slice.
