# Workflow

## Purpose
Define the repository workflow as a declarative sequence for planning, tasking, execution, evidence capture, and controlled automation rollout.

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
5. For approved pilot changes only, run the repository-owned CI adapter to compare CI results against the same gate contracts and canonical artifacts.
6. Record validation results and required evidence in the task artifact before declaring completion.
7. Archive the completed OpenSpec change after tasks, evidence, and review are complete.

## Workflow Boundaries
- Repository-local validation scripts remain the default execution path.
- The repository may host explicitly approved pilot automation, including the low-risk CI unified gate pilot, without treating CI as a blanket replacement for local validation.
- Guard enforcement, scheduler-triggered execution, and automatic status writeback remain change-scoped capabilities. They are not globally active unless a reviewed change introduces them.
