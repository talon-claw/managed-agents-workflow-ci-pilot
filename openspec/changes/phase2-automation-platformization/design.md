## Context

Current repository state confirms:

- Phase 1 local loop exists (`worktree-preflight`, `verify`, `review-check`, `acceptance`).
- Workflow contract explicitly avoids claiming CI/guard enforcement as active.
- Risk policy classifies CI wiring and runtime enforcement as high-risk territory.
- The task template currently allows only `pending`, `in-progress`, `completed`, and `blocked` as task-spec status values.

This change plans the next layer: controlled platformization while preserving fail-closed evidence semantics and OpenSpec task/change mapping.

## Decision

Adopt a **four-track staged platform model** with strict rollout ordering:

1. CI Unified Gate Track
2. Guard/Enforcement Track
3. Claude+Codex Scheduling Track
4. Auto Status Writeback Track

Each track ships behind explicit contracts, validation evidence, and rollback criteria.

## Track A — CI Unified Gate Integration

### Goal
Make CI call repository-owned gate entrypoints consistently, so local and CI conclusions are comparable.

### Contract
- CI must invoke repository scripts (not ad-hoc commands).
- CI result schema must map to run artifacts and exit codes.
- CI does not bypass `review-check` or acceptance evidence requirements.

### Constraints
- Preserve local-first debugability (same scripts runnable locally).
- No hidden CI-only checks unless declared in task validation matrix.

## Track B — Guard/Enforcement

### Goal
Introduce minimal command guard enforcement for explicitly high-risk operations.

### Contract
- Guard coverage starts from a minimal deny/confirm list.
- Every blocked/confirmed high-risk action leaves auditable evidence.
- Guard policy remains narrow by default and expands only by reviewed change.

### Constraints
- No blanket interception of routine developer commands.
- No implicit approval behavior.

## Track C — Claude+Codex Stable Scheduling Wrapper

### Goal
Provide deterministic orchestration for Claude controller + Codex execution with durable session continuity.

### Contract
- One task = one bounded execution envelope with explicit owner and handoff points.
- Wrapper records run identity (`task_id`, `change_id`, `run_id`, session id) before execution.
- Scheduler supports retry only via state transition rules (not blind loops).
- Failure states are classed (`transient`, `spec-mismatch`, `policy-blocked`, `requires-human`).

### Constraints
- No direct mutation of task spec status without writeback rules.
- Wrapper cannot mark completion without acceptance evidence.

## Track D — Automatic Status Writeback

### Goal
Write task lifecycle and validation outcomes back to canonical artifacts automatically.

### Contract
- Writeback targets:
  - `specs/tasks/<task_id>.md` status fields
  - run artifact summary under `artifacts/tasks/<task_id>/<run_id>/`
  - optional change-level progress mirror in `openspec/changes/<change_id>/tasks.md`
- Writeback is idempotent and monotonic by state machine.
- Conflicting updates fail closed and require human resolution.

### Constraints
- No overwrite of human-authored narrative fields outside declared status sections.
- No cross-task writeback from a single run.

## Canonical Status Mapping

### Task-Spec Status Authority
- `specs/tasks/<task_id>.md` remains the canonical status source.
- Task-spec status values stay constrained to the existing task template: `pending`, `in-progress`, `completed`, and `blocked`.
- Automation must not introduce new task-spec status literals unless the repository task template is changed in a separate reviewed change.

### Derived Execution Outcomes
- `verified`, `failed-validation`, and `awaiting-review` are execution outcomes, not task-spec statuses.
- Those outcomes live in run-scoped machine-readable artifacts and may be summarized in human-readable evidence files.
- `completed` is allowed only after the latest accepted run records passing acceptance evidence and no unresolved conflict state.
- `blocked` is reserved for explicit human or policy blockage, not generic validation failure.

### Allowed Task-Spec Transitions
- `pending -> in-progress`
- `in-progress -> completed`
- `in-progress -> blocked`
- `blocked -> in-progress`
- No other automated transition is valid.
- Any attempted downgrade from `completed` or conflicting transition must fail closed.

## Machine-Readable Result Contract

### Canonical Result Record
- Each run must emit a canonical machine-readable result record under `artifacts/tasks/<task_id>/<run_id>/manifest.json`.
- The record extends the Phase 1 manifest contract rather than introducing a second source of truth.
- The record must include, at minimum:
  - `task_id`
  - `change_id`
  - `run_id`
  - `task_spec_path`
  - `base_ref`
  - `head_sha`
  - `generated_at_utc`
  - `controller_session_id`
  - `executor_session_id`
  - `lease_owner`
  - `lease_acquired_at_utc`
  - `result_state` (`verified` | `failed-validation` | `awaiting-review` | `policy-blocked` | `spec-mismatch` | `transient` | `requires-human`)
  - `verify_exit_code`
  - `review_exit_code`
  - `acceptance_exit_code`
  - `evidence_paths`
- Scheduler, CI adapters, and writeback logic must consume this shared record instead of reparsing free-form logs independently.

### Manifest Example
```json
{
  "task_id": "phase2-pilot-task",
  "change_id": "phase2-automation-platformization",
  "run_id": "20260418T062500Z-phase2-pilot-task-r1",
  "task_spec_path": "specs/tasks/phase2-pilot-task.md",
  "worktree_path": ".claude/worktrees/phase2-pilot-task",
  "base_ref": "main",
  "risk_level": "low",
  "head_sha": "abc1234def5678",
  "generated_at_utc": "2026-04-18T06:25:00Z",
  "controller_session_id": "claude-session-01",
  "executor_session_id": "codex-session-01",
  "lease_owner": "claude-controller",
  "lease_acquired_at_utc": "2026-04-18T06:24:30Z",
  "result_state": "verified",
  "verify_exit_code": 0,
  "review_exit_code": 0,
  "acceptance_exit_code": 0,
  "evidence_paths": [
    "artifacts/tasks/phase2-pilot-task/20260418T062500Z-phase2-pilot-task-r1/search-plan.md",
    "artifacts/tasks/phase2-pilot-task/20260418T062500Z-phase2-pilot-task-r1/verify.txt",
    "artifacts/tasks/phase2-pilot-task/20260418T062500Z-phase2-pilot-task-r1/review.txt",
    "artifacts/tasks/phase2-pilot-task/20260418T062500Z-phase2-pilot-task-r1/acceptance.txt"
  ]
}
```

### Completion Gate
- `completed` writeback requires `result_state = verified`, `acceptance_exit_code = 0`, and all required evidence paths present.
- `failed-validation` and `awaiting-review` may be reflected in artifacts, but they cannot be written as task-spec status.
- If the result record is incomplete, malformed, or mismatched with evidence files, writeback must stop and raise `requires-human`.

## Run Identity and Lease Semantics

### Run Identity
- `run_id` must be generated before any mutating execution starts.
- A `run_id` is unique within the repository and binds exactly one `task_id` plus one execution attempt.
- Retries that reuse the same evidence directory are not allowed; each retry gets a fresh `run_id` and a fresh artifact directory.
- Preferred format: `<YYYYMMDDTHHMMSSZ>-<task_id>-r<attempt>`.

### Single-Writer Rule
- At most one write-capable lease may be active for a given `task_id` at a time.
- Read-only inspection or audit runs may exist concurrently only if they do not write task status or task-scoped artifacts.
- Any second write-capable claimant for the same `task_id` must fail closed before execution.

### Lease Contract
- The active lease must record `task_id`, `run_id`, `lease_owner`, `lease_acquired_at_utc`, and intended write scope.
- Lease loss, stale lease detection, or ambiguous ownership converts the run to `requires-human`.
- Automatic takeover is out of scope for this planning change.
- Preferred lease location: `artifacts/tasks/<task_id>/active-lease.json`.

### Lease Example
```json
{
  "task_id": "phase2-pilot-task",
  "run_id": "20260418T062500Z-phase2-pilot-task-r1",
  "lease_owner": "claude-controller",
  "lease_acquired_at_utc": "2026-04-18T06:24:30Z",
  "write_scope": [
    "specs/tasks/phase2-pilot-task.md",
    "artifacts/tasks/phase2-pilot-task/20260418T062500Z-phase2-pilot-task-r1/",
    "openspec/changes/phase2-automation-platformization/tasks.md"
  ]
}
```

## Search-Plan Provenance

- `search-plan.md` remains a required run artifact.
- The controller layer owns generation of the initial `search-plan.md` before executor handoff.
- Executors may append bounded implementation notes only within designated sections defined by the run contract.
- If `search-plan.md` is missing, the run is incomplete and cannot be promoted to `verified` or `completed`.

## Change-Level Progress Mirror Authority

- `openspec/changes/<change_id>/tasks.md` is a derived-only mirror, not a canonical execution state source.
- Automation may update the mirror only from already-validated task-spec state plus run evidence.
- Mirror writeback is optional; absence of mirror updates must not block task completion.
- If mirror content diverges from task-spec state, task spec and run artifacts win and the mirror must be treated as stale.

### Mirror Patch Boundary
- Mirror updates may touch checkbox state lines and machine-generated progress annotations only.
- Mirror updates must not rewrite section headings, human-authored rationale, or unrelated task lines.
- Preferred generated annotation format is a single suffix comment on the referenced checkbox line, for example: `<!-- derived: specs/tasks/phase2-pilot-task.md status=completed run_id=20260418T062500Z-phase2-pilot-task-r1 -->`.
- If the target checkbox line cannot be matched unambiguously, mirror writeback must fail closed.

## Pilot Selection Standard

- The first pilot task must be `low` risk under `specs/design/risk-policy.md`.
- The pilot must bind exactly one `change_id` and one `task_id`.
- The pilot must avoid destructive commands, cross-task writeback, CI-side secrets mutation, and guard-policy expansion.
- The pilot must exercise all core artifact paths: `search-plan.md`, `verify.txt`, `review.txt`, `acceptance.txt`, `manifest.json`, and the lease file.
- The pilot passes only if local result and simulated CI result are equivalent on status outcome, required evidence presence, and completion eligibility.

## Risk Classification

This planning change is **Medium** (workflow semantics only).

Future implementation changes are expected to include **High-risk** slices for:
- CI enforcement activation
- runtime command guard enforcement
- scheduler-triggered automation

Those slices must be split into separate OpenSpec changes and reviewed explicitly.

## Rollout Strategy

1. Ship contracts and dry-run adapters.
2. Run pilot on one low-risk task end-to-end.
3. Compare local vs CI equivalence metrics.
4. Expand to broader task set only after mismatch budget is acceptable.

## Rollback Strategy

- CI track: revert to manual-only invocation path.
- Guard track: reduce to audit-only mode with no block.
- Scheduler track: disable wrapper and fall back to manual orchestration.
- Writeback track: disable automated writes, keep artifact-only logging.

## Acceptance for Planning

This change is planning-complete when:
- proposal/design/tasks exist and are internally consistent.
- task-spec status authority and derived execution outcomes are explicitly separated.
- machine-readable result, run identity, lease, and mirror authority contracts are specified.
- implementation-ready details for manifest shape, lease location, mirror patch boundary, and pilot selection are declared.
- tasks are split by track with explicit evidence outputs.
- high-risk implementation boundaries are documented and separated.
