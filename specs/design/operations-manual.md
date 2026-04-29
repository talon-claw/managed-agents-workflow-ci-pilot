# Operations Manual

## Purpose
Provide a practical operator guide for running the repository workflow with Claude Code as controller, Codex as delegated code executor, OpenSpec as planning source, and repository-owned validation/evidence contracts as the execution boundary.

## What This Repository Supports Today
- OpenSpec changes under `openspec/changes/<change_id>/` define proposal, design, and task breakdown.
- Execution tasks live under `specs/tasks/<task_id>.md`.
- Local validation uses repository-owned scripts in fixed order:
  1. `scripts/worktree-preflight.sh`
  2. `scripts/verify.sh`
  3. `scripts/review-check.sh`
  4. `scripts/acceptance.sh`
- Canonical run artifacts live under `artifacts/tasks/<task_id>/<run_id>/`.
- A low-risk CI unified gate pilot exists for approved pilot tasks and preserves the same canonical artifact semantics.

## Role Split: Claude Code + Codex + OpenSpec
- **OpenSpec**: planning source of truth (`proposal.md` / `design.md` / `tasks.md`).
- **Claude Code**: controller and reviewer. Owns decomposition, routing, scope control, risk checks, and final evidence synthesis.
- **Codex**: delegated implementation executor for code-path changes. Owns concrete edits/tests under the task boundary.
- **Task spec** (`specs/tasks/<task_id>.md`): execution contract of one bounded slice.
- **Run artifacts** (`artifacts/tasks/<task_id>/<run_id>/`): machine-readable proof of one attempt.

## Operating Model
- Claude Code reads the active change, chooses the next bounded task slice, delegates implementation to Codex when appropriate, runs validation, and summarizes evidence.
- OpenSpec remains the planning source of truth.
- Task specs remain the execution source of truth.
- Run artifacts and `manifest.json` remain the machine-readable execution result of each attempt.

## Recommended Command Entry Points
Use these as the primary operator entry points:
- `/ccg:spec-research` — understand the codebase, locate patterns, and collect context.
- `/ccg:spec-plan` — turn requirements into proposal/design/tasks artifacts.
- `/ccg:spec-impl` — execute the next bounded implementation slice and close the validation loop.
- `/ccg:spec-review` — review completed work against scope, risk, and regressions.

## Task Initiation Runbook
1. Create or update an OpenSpec change under `openspec/changes/<change_id>/`.
2. Ensure the change has:
   - `proposal.md`
   - `design.md`
   - `tasks.md`
3. Create one or more execution task specs from `specs/tasks/task-template.md`.
4. Make sure each task spec includes:
   - `task_id`
   - `change_id`
   - scope constraints
   - validation matrix
   - required evidence
5. Assign one bounded task to execution and keep change/task mapping one-to-one per run.

## Execution Closed Loop (Operator Checklist)
1. Read active change + bound task spec.
2. Pick the smallest verifiable slice.
3. Route implementation to Codex for code-path edits (Claude keeps scope control).
4. Apply only in-scope changes.
5. Run repository-owned gates in fixed order.
6. Collect/verify standard evidence files.
7. Reconcile validation matrix and required evidence with actual outputs.
8. Update task status only when evidence is complete and review conditions are satisfied.

## Standard Local Validation Loop
The local loop is the default path.

### Gate Order
1. `worktree-preflight`
2. `verify`
3. `review-check`
4. `acceptance`

### Expected Standard Evidence
Each accepted run should produce:
- `search-plan.md`
- `verify.txt`
- `review.txt`
- `acceptance.txt`
- `manifest.json`

### Canonical Location
- `artifacts/tasks/<task_id>/<run_id>/`

## CI Pilot Workflow
A low-risk CI pilot is available for explicitly approved pilot tasks.

### What The CI Pilot Does
- Runs the repository-owned CI adapter entrypoint.
- Preserves canonical artifact structure.
- Uploads the standard run evidence.
- Uses `manifest.json` as the machine-readable result contract.

### What The CI Pilot Does Not Mean
- It does not make CI the universal source of truth.
- It does not globally enable automation for all tasks.
- It does not override task-scope or risk-scope limits.

## Failure Handling
### Validation Failure
If `verify`, `review-check`, or `acceptance` fails:
- Treat the run as incomplete.
- Inspect the failing evidence file under `artifacts/tasks/<task_id>/<run_id>/`.
- Fix the scoped issue.
- Re-run with a fresh `run_id` when required by the contract.

### Spec Mismatch
If implementation or evidence conflicts with the task spec or change contract:
- Do not force completion.
- Update the plan via `/ccg:spec-plan` if the requirement changed.
- Then resume with `/ccg:spec-impl`.

### CI Pilot Failure
If CI pilot fails but local loop passes:
- Treat as equivalence failure, not auto-complete.
- Compare gate order, manifest fields, and missing evidence paths first.
- Keep task status unchanged until CI/local conclusion is reconciled.

### High-Risk Work
If a task introduces CI wiring, command enforcement, security-sensitive behavior, or destructive actions:
- Split the change into a reviewed slice.
- Require explicit review notes and rollback considerations in the task artifact.
- Keep the rollout scoped and reversible.

## How To Know A Task Is Complete
A task is complete when all of the following are true:
- Scoped work is finished.
- Validation matrix reflects the current state.
- Required evidence exists and is traceable.
- No unresolved review blocker remains.

## How To Know A Change Is Complete
A change is complete when:
- All checkbox tasks are done.
- Related execution tasks are completed with evidence.
- Review is acceptable for the risk level.
- The change can be archived cleanly.

## Archive Flow
After the change tasks are complete:
1. Confirm `tasks.md` is fully checked.
2. Confirm required evidence exists for completed execution tasks.
3. Archive the change.
4. Verify it disappears from the active change list.

## Current Automation Boundary
This repository currently supports:
- structured planning
- bounded implementation execution
- local validation loop
- canonical evidence capture
- low-risk CI pilot validation

This repository does not yet guarantee:
- full unattended multi-task execution for every future change
- global scheduler-triggered execution by default
- automatic merge/release flows
- blanket front-end/back-end prototype generation without approved task specs and validation steps

## Answer To The Common Operator Question
If all requirements are fully specified, Claude Code can drive a large portion of the build loop through `/ccg:spec-impl`, including both front-end and back-end tasks, as long as:
- the work is broken into explicit OpenSpec changes and task specs
- delegated execution scope (for example, Codex code edits) remains bounded by the same task contract
- the repository contains the needed implementation surface
- validation rules and acceptance criteria are defined
- risky operations still receive the required review

In other words, the workflow can drive toward a full prototype, but it works best as a staged closed loop rather than one giant implicit request.
