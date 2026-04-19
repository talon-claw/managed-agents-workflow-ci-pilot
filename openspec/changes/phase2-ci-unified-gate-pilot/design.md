## Context

`phase2-automation-platformization` defines Track A as CI unified gate integration and explicitly separates high-risk CI wiring from later scheduler, guard, and writeback tracks. The repository now has a completed repository-local dry-run slice (`phase2-scheduler-artifact-dry-run`) that proves canonical artifacts can be produced locally on one pilot task.

The next smallest verifiable step is to prove that CI can reach equivalent conclusions by invoking repository-owned gate scripts in a controlled worktree shape, while keeping CI read-only against canonical task state.

## Decision

Adopt a **single-task CI unified gate pilot** with `Push + PR` triggers.

This pilot introduces one thin CI execution path:

1. trigger on `push` and `pull_request`
2. resolve exactly one low-risk pilot task spec
3. construct a synthetic task-named git worktree that satisfies repository preflight constraints
4. invoke repository-owned gate entrypoints in fixed order
5. normalize outputs into the canonical `artifacts/tasks/<task_id>/<run_id>/manifest.json`
6. upload all run artifacts even on failure
7. stop without mutating task spec status, change-task mirrors, or lease ownership

## Scope

### In Scope
- One reviewed CI workflow for the pilot path only
- One repository-owned CI adapter script as the single workflow entrypoint
- `Push + PR` trigger contract for the pilot workflow
- Synthetic task-named worktree creation for CI execution
- Fixed-order invocation of repository gate scripts
- Canonical manifest normalization and CI-side parsing expectations
- Always-upload artifact policy for `search-plan.md`, `verify.txt`, `review.txt`, `acceptance.txt`, and `manifest.json`
- Equivalence checks limited to outcome class, exit-code mapping, and required evidence presence

### Out of Scope
- Reusing `scheduler-dry-run.sh` as the CI entrypoint
- CI lease acquisition, lease takeover, or any task-scoped lock mutation
- Task-spec writeback, derived mirror writeback, or any human-authored artifact mutation
- Guard-policy expansion or runtime command interception changes
- Multi-task CI matrices, repo-wide rollout, or concurrent task execution

## CI Invocation Contract

### Entry Contract
- CI must call one repository-owned adapter script, not inline ad-hoc shell logic in workflow YAML.
- The adapter must accept exactly one task spec input.
- The adapter must derive `task_id`, `change_id`, `base_ref`, and `run_id` before validation starts.
- The adapter must fail closed if the task spec is missing, malformed, not low-risk, or not bound to the expected change.

### Execution Order
The CI adapter must call repository-owned gates in this order:

1. `scripts/worktree-preflight.sh`
2. `scripts/verify.sh`
3. `scripts/review-check.sh`
4. `scripts/acceptance.sh`

No step may be skipped. CI may wrap these calls, but it may not replace their semantics with YAML-native commands.

### Synthetic Worktree Rule
- CI must create an isolated git worktree whose basename equals `task_id`.
- The CI worktree must not be the main checkout directory.
- The worktree must be created from the workflow checkout state so `base_ref` and `HEAD` remain auditable.
- CI must use full git history (`fetch-depth: 0`) so ancestry and diff-based checks remain valid.

## Canonical Result Mapping

### Result States
CI must normalize the run into the canonical manifest result taxonomy already declared by Phase 2:

- `verified`
- `failed-validation`
- `awaiting-review`
- `policy-blocked`
- `spec-mismatch`
- `transient`
- `requires-human`

### Mapping Rules
- `verified` requires `preflight_exit = 0`, `verify_exit_code = 0`, `review_exit_code = 0`, `acceptance_exit_code = 0`, and all required evidence paths present.
- `policy-blocked` is used when `review-check` blocks the run.
- `failed-validation` is used when verify or acceptance exits non-zero after a valid invocation.
- `requires-human` is used for malformed manifest output, missing evidence, invalid task binding, ambiguous worktree state, or any CI-side contract violation.
- `awaiting-review`, `spec-mismatch`, and `transient` remain reserved canonical states if later repository-owned scripts emit them; the workflow must preserve them rather than remapping to ad-hoc labels.

## Artifact Contract

### Required Paths
Each CI run must retain these paths under `artifacts/tasks/<task_id>/<run_id>/`:

- `search-plan.md`
- `verify.txt`
- `review.txt`
- `acceptance.txt`
- `manifest.json`

### Upload Policy
- CI must upload artifacts on both success and failure.
- Artifact upload must be best-effort but must run with always semantics after gate execution.
- Missing upload configuration is a workflow defect; missing local files is a run defect and must remain visible in `manifest.json`.

### Manifest Consumption Rules
CI may inspect `manifest.json` to classify the workflow result, but it must not re-derive status from free-form logs when the manifest is present and readable.
If both logs and manifest exist but disagree, the canonical manifest wins and the workflow must fail closed for human review.

## Canonical Manifest Example

```json
{
  "task_id": "phase2-ci-unified-gate-pilot-task",
  "change_id": "phase2-ci-unified-gate-pilot",
  "run_id": "20260418T120000Z-phase2-ci-unified-gate-pilot-task-r1",
  "task_spec_path": "specs/tasks/phase2-ci-unified-gate-pilot-task.md",
  "worktree_path": ".claude/worktrees/phase2-ci-unified-gate-pilot-task",
  "base_ref": "main",
  "risk_level": "low",
  "head_sha": "abc1234def5678",
  "generated_at_utc": "2026-04-18T12:00:00Z",
  "controller_session_id": "github-actions",
  "executor_session_id": "github-actions",
  "lease_owner": "ci-read-only",
  "result_state": "verified",
  "preflight_exit": 0,
  "verify_exit": 0,
  "review_exit": 0,
  "verify_exit_code": 0,
  "review_exit_code": 0,
  "acceptance_exit_code": 0,
  "acceptance_status": "PASS",
  "task_status_before": "pending",
  "task_status_after": "pending",
  "task_writeback": "not-attempted",
  "mirror_writeback": "not-attempted",
  "scheduler_message": "ci unified gate pilot verified",
  "scope_guard_status": "clean",
  "evidence_paths": [
    "artifacts/tasks/phase2-ci-unified-gate-pilot-task/20260418T120000Z-phase2-ci-unified-gate-pilot-task-r1/search-plan.md",
    "artifacts/tasks/phase2-ci-unified-gate-pilot-task/20260418T120000Z-phase2-ci-unified-gate-pilot-task-r1/verify.txt",
    "artifacts/tasks/phase2-ci-unified-gate-pilot-task/20260418T120000Z-phase2-ci-unified-gate-pilot-task-r1/review.txt",
    "artifacts/tasks/phase2-ci-unified-gate-pilot-task/20260418T120000Z-phase2-ci-unified-gate-pilot-task-r1/acceptance.txt",
    "artifacts/tasks/phase2-ci-unified-gate-pilot-task/20260418T120000Z-phase2-ci-unified-gate-pilot-task-r1/manifest.json"
  ],
  "missing_evidence_paths": []
}
```

## Read-Only State Rule

- CI must not write `specs/tasks/<task_id>.md`.
- CI must not write `openspec/changes/<change_id>/tasks.md`.
- CI must not create or overwrite `artifacts/tasks/<task_id>/active-lease.json`.
- Any attempt to mutate canonical task state in this pilot is a contract violation and must fail closed.

## Validation Strategy

Use one low-risk pilot task bound only to `phase2-ci-unified-gate-pilot` and verify:

1. CI and local runs both invoke repository-owned gate scripts in the same order.
2. CI worktree shaping satisfies `worktree-preflight` without broadening local bypass rules.
3. `manifest.json` is machine-readable and sufficient for workflow result classification.
4. artifacts are uploaded on success and failure.
5. task-spec status remains unchanged after CI execution.

## PBT / Invariant Set

- **Invariant: fixed-order invocation** — CI never runs `acceptance` before `verify` and never skips `review-check` when acceptance runs.
- **Invariant: read-only canonical state** — repeating the same CI run never changes task-spec status or mirror state.
- **Invariant: evidence completeness** — `result_state = verified` implies every required artifact path exists and `missing_evidence_paths` is empty.
- **Invariant: worktree identity** — if preflight passes in CI, the effective worktree basename equals `task_id`.
- **Invariant: manifest authority** — when a readable manifest exists, workflow conclusion is derived from manifest fields, not ad-hoc log parsing.

## Risk Classification

This implementation slice is **High** because it introduces real CI workflow wiring and automated execution on `push` and `pull_request`, even though the pilot remains read-only against canonical task state.

## Rollback Strategy

- Disable the pilot workflow.
- Remove the CI adapter entrypoint.
- Fall back to repository-local dry-run validation only.
- Keep generated artifacts for audit, but stop CI invocation immediately if result/evidence equivalence breaks.

## Acceptance

This change is complete when:

- one low-risk pilot task runs through the CI adapter on `push` and `pull_request`
- CI uses a synthetic task-named worktree instead of bypassing preflight constraints
- `manifest.json` remains the machine-readable result authority
- CI uploads the required artifact set on success and failure
- no CI path mutates task-spec status, mirror state, or lease ownership
