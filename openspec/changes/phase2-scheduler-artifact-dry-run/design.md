## Context

`phase2-automation-platformization` defines the implementation-ready contract for:

- canonical task-spec status authority
- run-scoped `manifest.json`
- single-writer lease files
- controller-owned `search-plan.md`
- derived-only mirror writeback

The first implementation slice should prove those contracts locally on one low-risk task before any CI or guard activation is attempted.

## Decision

Adopt a **single-task local dry-run implementation slice** for the scheduler and artifact contract.

This slice implements one bounded execution path:

1. acquire single-writer lease
2. generate `search-plan.md`
3. run repository-local verification steps
4. write canonical `manifest.json`
5. apply fail-closed task-spec writeback
6. optionally update derived mirror
7. release lease or mark failure state in artifacts

## Scope

### In Scope
- One-task scheduler envelope creation
- `run_id` generation in the preferred Phase 2 format
- `active-lease.json` creation under `artifacts/tasks/<task_id>/`
- `search-plan.md` generation before executor handoff
- `manifest.json` population using the canonical result contract
- Task-spec status writeback for allowed transitions only
- Optional derived mirror update to `openspec/changes/<change_id>/tasks.md`

### Out of Scope
- CI invocation or workflow YAML changes
- Guard-policy expansion or runtime enforcement rollout
- Multi-task queues, retries across process crashes, or lease takeover
- Any writeback that touches human-authored narrative fields

## Execution Contract

### Inputs
- one `specs/tasks/<task_id>.md` bound to one active `change_id`
- repository-local scripts already defined by Phase 1 workflow
- a generated `run_id`

### Outputs
- `artifacts/tasks/<task_id>/<run_id>/search-plan.md`
- `artifacts/tasks/<task_id>/<run_id>/verify.txt`
- `artifacts/tasks/<task_id>/<run_id>/review.txt`
- `artifacts/tasks/<task_id>/<run_id>/acceptance.txt`
- `artifacts/tasks/<task_id>/<run_id>/manifest.json`
- `artifacts/tasks/<task_id>/active-lease.json`

### Allowed Status Effects
- `pending -> in-progress`
- `in-progress -> completed`
- `in-progress -> blocked`
- `blocked -> in-progress`

Any other attempted transition fails closed and leaves the task spec unchanged.

## Failure Model

- Missing lease file after acquisition attempt => `requires-human`
- Missing `search-plan.md` before execution => `requires-human`
- Missing required evidence files => `requires-human`
- Acceptance non-zero exit => artifact result may be `failed-validation`, but task-spec status may not advance to `completed`
- Ambiguous mirror target line => mirror writeback skipped and recorded as stale/failed in artifacts

## Validation Strategy

Use one low-risk pilot task and verify:

1. run artifacts are created in the required locations
2. `manifest.json` is machine-readable and internally consistent
3. task-spec writeback respects allowed transitions only
4. mirror writeback is derived-only and optional
5. local dry-run output is sufficient for later CI consumption

## Risk Classification

This implementation slice is **Medium**:
- it changes scripts or automation behavior
- but it remains repository-local and explicitly avoids CI wiring and guard activation

## Rollback Strategy

- disable the dry-run scheduler entrypoint
- stop generating lease and manifest artifacts automatically
- return to manual Phase 1 execution with artifact-only inspection

## Acceptance

This change is complete when:
- one low-risk pilot task can run through the dry-run path end-to-end
- required artifacts and lease file are generated
- `manifest.json` matches the declared contract
- task-spec writeback stays within allowed transitions
- no CI wiring or expanded guard behavior is introduced
