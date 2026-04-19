# Artifact Contract

## Purpose
Define the minimal artifact set and ownership boundaries for Phase 1 repository work.

## Required Change Artifacts
- `openspec/changes/<change_id>/proposal.md` defines why the change exists.
- `openspec/changes/<change_id>/design.md` defines the chosen approach and scope limits.
- `openspec/changes/<change_id>/tasks.md` defines checkbox-tracked implementation work.

## Required Repository Artifacts
- `specs/design/workflow.md` defines the repository workflow contract.
- `specs/design/risk-policy.md` defines the repository risk classification contract.
- `specs/design/artifact-contract.md` defines artifact ownership and minimum contents.
- `specs/tasks/task-template.md` defines the execution-task schema.
- `AGENTS.md` defines execution-agent responsibilities and completion boundaries.
- `CLAUDE.md` defines guardrail, review, and evidence policy.
- `.claude/settings.json` contains machine-readable project settings only.

## Task Mapping Contract
- Each execution task lives at `specs/tasks/<task_id>.md`.
- Each task spec binds exactly one active `change_id`.
- The bound `change_id` must resolve to `openspec/changes/<change_id>/`.
- The bound change `tasks.md` must reference the `task_id`.
- `base_ref` defaults to `main` when omitted by the task spec.

## Run Artifact Contract
- Each validation run writes to `artifacts/tasks/<task_id>/<run_id>/`.
- The run directory must contain:
  - `search-plan.md`
  - `verify.txt`
  - `review.txt`
  - `acceptance.txt`
  - `manifest.json`

## Manifest Contract
- `manifest.json` records at least:
  - `task_id`
  - `change_id`
  - `run_id`
  - `task_spec_path`
  - `worktree_path`
  - `base_ref`
  - `risk_level`
  - `head_sha`
  - `generated_at_utc`
  - `evidence_paths`

## Evidence Contract
- Each task artifact must reference the active `change_id`.
- Each task artifact must include a validation matrix and required evidence section.
- Evidence may be notes, command output, file inspection, or stored reports as defined by the task.
- Standard run files are mandatory evidence for any acceptance run.

## Boundary
This contract names the artifacts that should exist in Phase 1. It does not impose implementation details beyond those minimum fields and ownership lines.
