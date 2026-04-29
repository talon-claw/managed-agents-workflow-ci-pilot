## 1. Planning and Mapping

- [x] 1.1 Bind this implementation change to `phase2-automation-platformization` as the first execution slice
- [x] 1.2 Choose one low-risk pilot task spec for the dry-run path (`phase2-scheduler-artifact-dry-run-pilot`)
- [x] 1.3 Confirm rollback notes and review notes for medium-risk automation changes

## 2. Scheduler Envelope

- [x] 2.1 Implement `run_id` generation using the preferred Phase 2 format
- [x] 2.2 Implement single-task envelope creation from one task spec input
- [x] 2.3 Persist `active-lease.json` under `artifacts/tasks/<task_id>/`

## 3. Artifact Generation

- [x] 3.1 Generate `search-plan.md` before executor handoff
- [x] 3.2 Persist `verify.txt`, `review.txt`, and `acceptance.txt` in the run directory
- [x] 3.3 Write `manifest.json` using the canonical result contract

## 4. Writeback

- [x] 4.1 Implement allowed task-spec status transitions only
- [x] 4.2 Fail closed on malformed manifest, missing evidence, or illegal transition
- [x] 4.3 Implement optional derived mirror update without touching human-authored narrative fields

## 5. Pilot Validation

- [x] 5.1 Run the dry-run path on `specs/tasks/phase2-scheduler-artifact-dry-run-pilot.md`
- [x] 5.2 Record evidence proving artifact completeness and status correctness
- [x] 5.3 Confirm no CI wiring or expanded guard behavior was introduced
