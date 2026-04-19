# Task: [Task Name]

## Metadata
- **task_id**: [unique task identifier; file path must be specs/tasks/<task_id>.md]
- **title**: [human-readable task title]
- **change_id**: [active OpenSpec change id]
- **status**: [pending | in-progress | completed | blocked]
- **owner**: [agent, maintainer, or team]
- **base_ref**: [default main]
- **publish_mode**: [pr-ready | manual-only]

## Objective
- **goal**: [state the expected outcome in 1-3 sentences]
- **non_goals**: [explicit non-goals for this task]

## Scope Constraints
- **constraints**: [allowed edits, approvals, or runtime limits]
- **files_or_areas_expected**: [expected files, directories, or modules]

## Dependencies
- **dependencies**: [upstream tasks, files, or approvals if any]
- **approved_design_refs**: [design docs or change design references]

## Mapping Notes
- The bound `change_id` must resolve to `openspec/changes/<change_id>/`.
- The bound change `tasks.md` must reference `task_id`.
- The task worktree root directory name should match `task_id`.

## Risk and Review
- **risk_level**: [low | medium | high]
- **review_notes**: [required for medium/high risk tasks]
- **rollback_considerations**: [required for medium/high risk tasks]

## Validation Matrix
| Requirement | Verification Method | Evidence Reference | Status |
|-------------|---------------------|--------------------|--------|
| [Requirement] | [lint | typecheck | test-unit | test-integration | test-e2e] | [artifact path or `skip:<reason>`] | [pending | skip] |

## Required Evidence
- Standard run files under `artifacts/tasks/<task_id>/<run_id>/` are enforced by `scripts/acceptance.sh`.
- Additional machine-checked evidence entries must use `path:<repo-relative-path>`.
- [ ] path:artifacts/tasks/<task_id>/<run_id>/custom-output.txt

## Completion Notes
- Confirm the task remains bound to `change_id`.
- Confirm the recorded evidence matches the validation matrix.
