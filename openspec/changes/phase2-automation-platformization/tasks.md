## 1. Planning Artifacts

- [ ] 1.1 Confirm `phase2-automation-platformization` as the active planning container for platform expansion
- [ ] 1.2 Align workflow/risk references so this change does not claim already-active enforcement
- [ ] 1.3 Reconcile task-spec status authority with derived execution outcomes

## 2. Track A — CI Unified Gate Integration Plan

- [ ] 2.1 Define CI invocation contract that calls repository gate scripts in fixed order
- [ ] 2.2 Define CI result mapping to acceptance/verify/review exit semantics
- [ ] 2.3 Define CI evidence outputs required for equivalence checks with local runs
- [ ] 2.4 Define CI consumption rules for the canonical machine-readable result record
- [ ] 2.5 Publish one synthetic `manifest.json` example and CI parsing expectations

## 3. Track B — Guard/Enforcement Plan

- [ ] 3.1 Define minimal high-risk command set for initial guard coverage
- [ ] 3.2 Define guard decision outcomes (allow, block, require-confirmation) and audit log schema
- [ ] 3.3 Define progressive rollout policy from narrow default to reviewed expansion

## 4. Track C — Claude+Codex Scheduling Wrapper Plan

- [ ] 4.1 Define scheduler envelope fields (`task_id`, `change_id`, `run_id`, session metadata)
- [ ] 4.2 Define execution state taxonomy and retry boundaries
- [ ] 4.3 Define handoff contract between Claude controller and Codex executor
- [ ] 4.4 Define run identity generation, single-writer lease rules, and stale-lease failure handling
- [ ] 4.5 Define controller ownership of `search-plan.md` before executor handoff
- [ ] 4.6 Define preferred lease-file location and synthetic lease example

## 5. Track D — Automatic Status Writeback Plan

- [ ] 5.1 Define canonical writeback targets and patch boundaries in task specs
- [ ] 5.2 Define idempotent state transition rules and conflict handling
- [ ] 5.3 Define evidence-first completion rules (no completion without acceptance evidence)
- [ ] 5.4 Define derived-only authority for change-level progress mirrors
- [ ] 5.5 Define machine-generated mirror annotation format and fail-closed matching rule

## 6. Pilot and Governance

- [ ] 6.1 Define one low-risk pilot task for end-to-end automation dry run
- [ ] 6.2 Define mismatch and rollback triggers for CI/guard/scheduler/writeback tracks
- [ ] 6.3 Define review checklist for high-risk implementation changes split from this planning change
- [ ] 6.4 Define pilot selection criteria that exercise full artifact and lease paths without destructive scope
