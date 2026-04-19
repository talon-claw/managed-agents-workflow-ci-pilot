## 1. Planning and Binding

- [x] 1.1 Bind `phase2-ci-unified-gate-pilot` to Track A of `phase2-automation-platformization`
- [x] 1.2 Select one low-risk pilot task spec for CI execution only (`phase2-ci-unified-gate-pilot-task`)
- [x] 1.3 Record explicit review and rollback notes for high-risk CI workflow changes

## 2. CI Invocation Contract

- [x] 2.1 Add one repository-owned CI adapter entrypoint instead of inline workflow shell logic
- [x] 2.2 Wire the pilot workflow to trigger on `push` and `pull_request` only
- [x] 2.3 Enforce fixed-order invocation of `worktree-preflight`, `verify`, `review-check`, and `acceptance`
- [x] 2.4 Fail closed when the pilot task binding, risk level, or base ref contract is invalid

## 3. Synthetic Worktree Shaping

- [x] 3.1 Create a task-named synthetic git worktree whose basename equals `task_id`
- [x] 3.2 Require full git history in CI so ancestry and diff-based checks remain valid
- [x] 3.3 Confirm the CI path does not relax local `worktree-preflight` rules globally

## 4. Canonical Artifact and Result Mapping

- [x] 4.1 Normalize CI outputs into the canonical `artifacts/tasks/<task_id>/<run_id>/manifest.json`
- [x] 4.2 Preserve canonical `result_state` and exit-code mapping without ad-hoc CI-only labels
- [x] 4.3 Keep `task_status_before` and `task_status_after` unchanged in the CI pilot
- [x] 4.4 Fail closed on malformed manifest or missing required evidence paths

## 5. Artifact Retention and Read-Only Guarantees

- [x] 5.1 Upload `search-plan.md`, `verify.txt`, `review.txt`, `acceptance.txt`, and `manifest.json` with always-run semantics
- [x] 5.2 Prove CI does not write task-spec status, change-task mirrors, or `active-lease.json`
- [x] 5.3 Record evidence showing manifest-driven workflow conclusion and read-only canonical state behavior

## 6. Pilot Validation

- [ ] 6.1 Run the CI pilot on `phase2-ci-unified-gate-pilot-task`
- [ ] 6.2 Record equivalence evidence between local gate semantics and CI gate semantics
- [ ] 6.3 Confirm rollback path is disable-workflow plus remove-adapter, with no scheduler or guard expansion
