# Workflow

## Purpose
Define the Phase 1 repository workflow as a declarative sequence for planning, tasking, execution, and evidence capture.

## Active Sources
- Active change intent lives under `openspec/changes/<change_id>/`.
- Repository-stable operating contracts live under `specs/design/`.
- Execution task definitions use `specs/tasks/<task_id>.md`.
- Frozen `docs/drafts/*.md` are historical inputs only and are not the active source of truth.

## Task Mapping
- Each execution task lives at `specs/tasks/<task_id>.md`.
- Each task binds exactly one `change_id`.
- The bound OpenSpec change must exist at `openspec/changes/<change_id>/`.
- The bound change `tasks.md` must reference the `task_id`.
- `base_ref` defaults to `main` unless a task spec overrides it.

## Phase Sequence
1. Create or update an active OpenSpec change with `proposal.md`, `design.md`, and `tasks.md`.
2. Derive implementation tasks from the active change using `specs/tasks/task-template.md`.
3. Execute work within the boundaries defined by `AGENTS.md` and `CLAUDE.md`.
4. Run the local validation loop with `scripts/worktree-preflight.sh`, `scripts/verify.sh`, `scripts/review-check.sh`, and `scripts/acceptance.sh`.
5. Record validation results and required evidence in the task artifact before declaring completion.

## Workflow Boundaries
- Phase 1 may use repository-local validation scripts for worktree preflight, verification, review, and acceptance.
- Phase 1 still does not introduce CI wiring or command-guard enforcement.
