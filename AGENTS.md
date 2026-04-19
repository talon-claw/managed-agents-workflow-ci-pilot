# Agents

## Primary Execution Agent
- Research the active OpenSpec change before editing repository artifacts.
- Execute only the work described by the active task and its bound `change_id`.
- Keep repository changes aligned with `specs/design/` contracts and the task template.
- Produce the validation and evidence records required by the task artifact.

## Boundaries
- Treat `openspec/changes/*` and `specs/*` as active planning and execution inputs.
- Treat `docs/drafts/*.md` as historical inputs only.
- Do not assume scripts, CI wiring, or runtime enforcement exist unless an active change explicitly adds them.

## Completion Definition
A task is complete when:
1. Its scoped work is finished without exceeding the declared boundary.
2. Its validation matrix is updated to reflect the current result.
3. Its required evidence is recorded and traceable to the completed work.
