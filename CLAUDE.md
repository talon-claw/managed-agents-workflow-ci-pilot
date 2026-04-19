# Claude Policy

## Guardrails
- Follow the active OpenSpec change and the repository contracts in `specs/design/`.
- Treat frozen `docs/drafts/*.md` as historical context, not the active source of truth.
- Avoid destructive, security-sensitive, or out-of-scope changes unless the active task explicitly requires them.
- Do not describe scripts, CI gates, or runtime enforcement as active unless they already exist in the repository or the active change introduces them.

## Review Policy
- Use `specs/design/risk-policy.md` to classify the task before completion.
- Escalate medium-risk or high-risk work for explicit review in the task artifact.
- Keep review notes tied to the task's `change_id`.

## Evidence Policy
- Every state-changing task should update its validation matrix.
- Every completed task should include the required evidence declared in the task artifact.
- Evidence can be lightweight in Phase 1, but it should be specific enough for another operator to inspect.
