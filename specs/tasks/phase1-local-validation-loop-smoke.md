# Task: Phase 1 Local Validation Loop Smoke

## Metadata
- **task_id**: phase1-local-validation-loop-smoke
- **title**: Phase 1 Local Validation Loop Smoke
- **change_id**: phase1-local-validation-loop
- **status**: pending
- **owner**: claude
- **base_ref**: main
- **publish_mode**: manual-only

## Objective
- **goal**: Prove the local validation loop can parse a task spec, run the repository verification scripts, and enforce run-scoped evidence.
- **non_goals**: CI wiring, command guard enforcement, and real production test execution.

## Scope Constraints
- **constraints**: Run only the local Phase 1 validation loop contracts introduced by Change A.
- **files_or_areas_expected**: specs/tasks, scripts, artifacts/tasks

## Dependencies
- **dependencies**: phase1-local-validation-loop active change must exist
- **approved_design_refs**: openspec/changes/phase1-local-validation-loop/design.md

## Mapping Notes
- The bound `change_id` must resolve to `openspec/changes/<change_id>/`.
- The bound change `tasks.md` must reference `task_id`.
- The task worktree root directory name should match `task_id`.

## Risk and Review
- **risk_level**: medium
- **review_notes**: Local smoke validation only; scripts modify only run-scoped artifacts.
- **rollback_considerations**: Delete the generated artifacts/tasks/phase1-local-validation-loop-smoke directory if the smoke run is discarded.

## Validation Matrix
| Requirement | Verification Method | Evidence Reference | Status |
|-------------|---------------------|--------------------|--------|
| Skip lint for contract-flow smoke validation | lint | skip:placeholder lint entrypoint intentionally fails until a real implementation exists | skip |
| Skip typecheck for contract-flow smoke validation | typecheck | skip:placeholder typecheck entrypoint intentionally fails until a real implementation exists | skip |
| Explicitly skip unit tests for smoke validation | test-unit | skip:smoke validation covers contract flow only | skip |

## Required Evidence
- Standard run files under `artifacts/tasks/<task_id>/<run_id>/` are enforced by `scripts/acceptance.sh`.
- Additional machine-checked evidence entries must use `path:<repo-relative-path>`.
- [ ] path:artifacts/tasks/phase1-local-validation-loop-smoke/run-pass/search-plan.md
- [ ] path:artifacts/tasks/phase1-local-validation-loop-smoke/run-pass/verify.txt
- [ ] path:artifacts/tasks/phase1-local-validation-loop-smoke/run-pass/review.txt
- [ ] path:artifacts/tasks/phase1-local-validation-loop-smoke/run-pass/acceptance.txt
- [ ] path:artifacts/tasks/phase1-local-validation-loop-smoke/run-pass/manifest.json

## Completion Notes
- Confirm the task remains bound to `change_id`.
- Confirm the recorded evidence matches the validation matrix.
