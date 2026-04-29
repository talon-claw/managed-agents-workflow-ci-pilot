## Why

Phase 1 currently stops at declarative skeletons. The repository still cannot run a minimum local validation loop that proves a task is bound to an active change, executed in a dedicated worktree, and backed by run-scoped evidence.

## What Changes

- Introduce the active `phase1-local-validation-loop` change.
- Expand repository contracts so task metadata and run artifacts are shell-consumable.
- Implement the local validation scripts for preflight, verify, review, and acceptance.
- Define the task-to-change mapping used by the local loop.

## Out Of Scope

- `scripts/guard-command.sh`
- CI wiring
- hooks or external runtime enforcement
- new runtime dependencies

## Impact

- Phase 1 gains a local fail-closed validation loop without claiming CI enforcement.
- Task specs become machine-readable enough for repository scripts to verify scope, risk, and evidence.
- Future task pilots can attach run-scoped artifacts under `artifacts/tasks/<task_id>/<run_id>/`.
