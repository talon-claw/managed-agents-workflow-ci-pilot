## Overview

This change establishes the minimum local validation loop for Phase 1. The loop is intentionally repository-local: it validates task-to-change binding, worktree isolation, verification execution, review gating, and artifact completeness without introducing CI wiring or command guarding.

## Design Goals

- Keep the loop fail-closed.
- Reuse existing repository shell entrypoints.
- Avoid new runtime dependencies.
- Keep task metadata and artifact rules explicit enough for shell parsing.

## Task Mapping Contract

- Each execution task lives at `specs/tasks/<task_id>.md`.
- Each task binds exactly one `change_id`.
- The bound OpenSpec change must exist at `openspec/changes/<change_id>/`.
- The bound change `tasks.md` must reference the `task_id`.
- `base_ref` defaults to `main` when omitted.
- A validation worktree must not run from the main worktree, and its root directory name must match `task_id`.

## Run Artifact Contract

Each validation run writes to `artifacts/tasks/<task_id>/<run_id>/` and must produce:

- `search-plan.md`
- `verify.txt`
- `review.txt`
- `acceptance.txt`
- `manifest.json`

`manifest.json` records at least `task_id`, `change_id`, `run_id`, `task_spec_path`, `worktree_path`, `base_ref`, `risk_level`, `head_sha`, `generated_at_utc`, and `evidence_paths`.

## Script Responsibilities

### `scripts/worktree-preflight.sh`

- Parse a task spec.
- Confirm the current repository root is a dedicated task worktree.
- Confirm `task_id`, `change_id`, `base_ref`, and worktree cleanliness rules.
- Confirm the bound change exists and references the task.

### `scripts/verify.sh`

- Parse the task validation matrix.
- Create `artifacts/tasks/<task_id>/<run_id>/verify.txt`.
- Execute mapped repository scripts for supported verification methods.
- Permit explicit skips only when `Evidence Reference` begins with `skip:`.
- Exit non-zero on any execution failure or malformed skip entry.

### `scripts/review-check.sh`

- Create `artifacts/tasks/<task_id>/<run_id>/review.txt`.
- Pass low-risk tasks.
- Require non-placeholder `review_notes` and `rollback_considerations` for medium-risk tasks.
- Block high-risk tasks for explicit human approval.

### `scripts/acceptance.sh`

- Orchestrate preflight, verify, and review-check.
- Fail if required run artifacts are missing.
- Fail if required evidence entries are unresolved.
- Generate `manifest.json` and `acceptance.txt` only for the current run.
- Exit zero only when every gate passes.

## Non-Goals

- Real test implementation inside `scripts/lint.sh`, `scripts/typecheck.sh`, or test runners.
- CI invocation changes.
- Command filtering or destructive-command interception.
