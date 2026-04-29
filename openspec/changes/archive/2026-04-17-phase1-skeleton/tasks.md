## 1. Phase 1 — Minimal Skeleton

- [x] 1.1 Confirm the active `phase1-skeleton` change is the planning source for Phase 1 work
- [x] 1.2 Create `specs/design/` with initial skeleton documents for workflow, risk policy, and artifact contract
- [x] 1.3 Create `specs/tasks/task-template.md` with core metadata, validation matrix, required evidence, and `change_id` binding
- [x] 1.4 Create or converge `AGENTS.md` with primary execution-agent responsibilities and completion-definition boundaries
- [x] 1.5 Create `CLAUDE.md` with guardrail, review, and evidence policy for this repository
- [x] 1.6 Create `.claude/settings.json` with minimal non-enforcing MVP project settings
- [x] 1.7 Create `scripts/lint.sh` skeleton
- [x] 1.8 Create `scripts/typecheck.sh` skeleton
- [x] 1.9 Create `scripts/test-unit.sh` skeleton
- [x] 1.10 Create `scripts/test-integration.sh` skeleton
- [x] 1.11 Create `scripts/test-e2e.sh` skeleton

## 2. Constraints

- [x] 2.1 Do not implement scripts, CI wiring, or runtime enforcement in this change
- [x] 2.2 Do not modify frozen `docs/drafts/*.md` except to reference them as historical inputs if needed
- [x] 2.3 Keep all new artifacts declarative and clearly scoped to Phase 1 only

## 3. Verification Targets

- [x] 3.1 Active change artifacts remain parseable by OpenSpec
- [x] 3.2 All tasks remain in checkbox format so `/ccg:spec-impl` can parse them
- [x] 3.3 Phase 1 scope is self-contained and does not depend on frozen drafts as the active source of truth
