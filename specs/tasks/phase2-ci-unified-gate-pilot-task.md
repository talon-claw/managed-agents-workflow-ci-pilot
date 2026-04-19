# Task: Phase 2 CI Unified Gate Pilot Task

## Metadata
- **task_id**: phase2-ci-unified-gate-pilot-task
- **title**: Run one low-risk CI unified gate pilot task
- **change_id**: phase2-ci-unified-gate-pilot
- **status**: pending
- **owner**: claude
- **base_ref**: main
- **publish_mode**: manual-only

## Objective
- **goal**: Prove that one low-risk task can run through the repository-owned CI unified gate path on `push` and `pull_request` while preserving canonical manifest semantics and read-only task state behavior. Keep the pilot limited to CI execution equivalence, artifact retention, and fail-closed contract validation.
- **non_goals**: No scheduler orchestration, no lease acquisition or mutation, no task-spec or change-task writeback, no guard-policy expansion, and no multi-task CI fan-out.

## Scope Constraints
- **constraints**: Limit changes to the pilot workflow, one repository-owned CI adapter entrypoint, synthetic task-named worktree shaping, canonical artifact normalization, and read-only CI validation. Do not relax local `worktree-preflight` rules globally or add CI-only status labels.
- **files_or_areas_expected**: specs/tasks/phase2-ci-unified-gate-pilot-task.md, openspec/changes/phase2-ci-unified-gate-pilot/, CI workflow files selected by implementation, one repository-owned CI adapter script, artifacts/tasks/phase2-ci-unified-gate-pilot-task/.

## Dependencies
- **dependencies**: Track A of `phase2-automation-platformization` remains the governing design source for CI unified gate ordering, manifest authority, and read-only canonical state. The pilot must stay bound to `phase2-ci-unified-gate-pilot` only.
- **approved_design_refs**: openspec/changes/phase2-automation-platformization/design.md; openspec/changes/phase2-ci-unified-gate-pilot/design.md

## Mapping Notes
- The bound `change_id` must resolve to `openspec/changes/phase2-ci-unified-gate-pilot/`.
- The bound change `tasks.md` must reference `phase2-ci-unified-gate-pilot-task`.
- The task worktree root directory name should match `phase2-ci-unified-gate-pilot-task`.

## Risk and Review
- **risk_level**: low
- **review_notes**: CI workflow wiring is high-risk at change level; require explicit human review of trigger scope (`push` + `pull_request` only), fixed-order gate invocation (`worktree-preflight` → `verify` → `review-check` → `acceptance`), manifest-result mapping, and read-only guarantees for task/mirror/lease state before enabling broadly.
- **rollback_considerations**: Immediate rollback is: disable the pilot workflow, remove the CI adapter entrypoint, and revert to repository-local validation only; preserve uploaded artifacts for audit but stop CI invocation when result/evidence equivalence breaks.

## Validation Matrix
| Requirement | Verification Method | Evidence Reference | Status |
|-------------|---------------------|--------------------|--------|
| CI pilot runs one bound low-risk task through repository-owned gates in fixed order | test-integration | path:artifacts/tasks/phase2-ci-unified-gate-pilot-task/<run_id>/manifest.json | pending |
| CI pilot preserves canonical manifest result mapping and required evidence paths | test-integration | path:artifacts/tasks/phase2-ci-unified-gate-pilot-task/<run_id>/review.txt | pending |
| CI pilot keeps canonical task state read-only and preserves `task_status_before` / `task_status_after` | test-integration | path:artifacts/tasks/phase2-ci-unified-gate-pilot-task/<run_id>/acceptance.txt | pending |

## Required Evidence
- Standard run files under `artifacts/tasks/<task_id>/<run_id>/` are enforced by `scripts/acceptance.sh`.
- Additional machine-checked evidence entries must use `path:<repo-relative-path>`.
- [ ] path:artifacts/tasks/phase2-ci-unified-gate-pilot-task/<run_id>/manifest.json
- [ ] path:artifacts/tasks/phase2-ci-unified-gate-pilot-task/<run_id>/verify.txt
- [ ] path:artifacts/tasks/phase2-ci-unified-gate-pilot-task/<run_id>/review.txt
- [ ] path:artifacts/tasks/phase2-ci-unified-gate-pilot-task/<run_id>/acceptance.txt

## Completion Notes
- Confirm the task remains bound to `phase2-ci-unified-gate-pilot`.
- Confirm the recorded evidence matches the validation matrix.
- Confirm CI did not mutate task-spec status, change-task mirrors, or lease ownership.
