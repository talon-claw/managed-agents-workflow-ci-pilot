# Task: Phase 2 Scheduler Artifact Dry-Run Pilot

## Metadata
- **task_id**: phase2-scheduler-artifact-dry-run-pilot
- **title**: Run one low-risk scheduler artifact dry-run pilot
- **change_id**: phase2-scheduler-artifact-dry-run
- **status**: completed
- **owner**: claude
- **base_ref**: main
- **publish_mode**: manual-only

## Objective
- **goal**: Prove that the first Phase 2 implementation slice can generate a run envelope, required artifacts, lease state, and fail-closed task writeback behavior for one low-risk task. Keep the pilot repository-local and dry-run only.
- **non_goals**: No CI wiring, no expanded guard enforcement, no multi-task scheduling, and no autonomous merge or release behavior.

## Scope Constraints
- **constraints**: Limit changes to repository-local dry-run scheduler/artifact logic and the pilot task evidence path. Do not introduce CI workflow files, destructive command automation, or human-narrative writeback.
- **files_or_areas_expected**: specs/tasks/phase2-scheduler-artifact-dry-run-pilot.md, openspec/changes/phase2-scheduler-artifact-dry-run/, artifacts/tasks/phase2-scheduler-artifact-dry-run-pilot/, repository-local scheduler or writeback scripts selected by implementation.

## Dependencies
- **dependencies**: phase2-automation-platformization contracts must remain the governing design source for manifest, lease, status mapping, and mirror writeback.
- **approved_design_refs**: openspec/changes/phase2-automation-platformization/design.md; openspec/changes/phase2-scheduler-artifact-dry-run/design.md

## Mapping Notes
- The bound `change_id` must resolve to `openspec/changes/phase2-scheduler-artifact-dry-run/`.
- The bound change `tasks.md` must reference `phase2-scheduler-artifact-dry-run-pilot`.
- The task worktree root directory name should match `phase2-scheduler-artifact-dry-run-pilot`.

## Risk and Review
- **risk_level**: low
- **review_notes**: Low-risk pilot task because it is limited to declarative task metadata and repository-local dry-run validation of a non-executing automation slice.
- **rollback_considerations**: Revert to manual artifact inspection and remove pilot-only task references if the dry-run path cannot satisfy fail-closed rules.

## Validation Matrix
| Requirement | Verification Method | Evidence Reference | Status |
|-------------|---------------------|--------------------|--------|
| Dry-run pilot generates required run artifacts and lease file | test-integration | path:artifacts/tasks/phase2-scheduler-artifact-dry-run-pilot/<run_id>/manifest.json | pending |
| Dry-run pilot preserves allowed task-spec status transitions only | test-integration | path:artifacts/tasks/phase2-scheduler-artifact-dry-run-pilot/<run_id>/review.txt | pending |
| Dry-run pilot does not introduce CI wiring or expanded guard behavior | test-unit | path:artifacts/tasks/phase2-scheduler-artifact-dry-run-pilot/<run_id>/acceptance.txt | pending |

## Required Evidence
- Standard run files under `artifacts/tasks/<task_id>/<run_id>/` are enforced by `scripts/acceptance.sh`.
- Additional machine-checked evidence entries must use `path:<repo-relative-path>`.
- [ ] path:artifacts/tasks/phase2-scheduler-artifact-dry-run-pilot/<run_id>/manifest.json
- [ ] path:artifacts/tasks/phase2-scheduler-artifact-dry-run-pilot/<run_id>/verify.txt
- [ ] path:artifacts/tasks/phase2-scheduler-artifact-dry-run-pilot/<run_id>/review.txt
- [ ] path:artifacts/tasks/phase2-scheduler-artifact-dry-run-pilot/<run_id>/acceptance.txt
- [ ] path:artifacts/tasks/phase2-scheduler-artifact-dry-run-pilot/active-lease.json

## Completion Notes
- Confirm the task remains bound to `phase2-scheduler-artifact-dry-run`.
- Confirm the recorded evidence matches the validation matrix.
- Confirm any mirror update, if present, remained derived-only.
