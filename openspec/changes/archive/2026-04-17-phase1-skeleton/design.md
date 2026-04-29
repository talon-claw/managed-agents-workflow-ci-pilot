## Context

Phase 0 established these preconditions:
- repository baseline branch defaults to `main`
- Node.js baseline is pinned by `.nvmrc`
- OpenSpec was initialized with the minimal core profile
- `docs/drafts/*.md` are frozen bootstrap records and are no longer the active source of truth

Phase 1 now needs an active change that defines the smallest repository skeleton required before any task execution proceeds further.

## Decision

Use a dual-layer ownership model:
- OpenSpec change files own change intent and Phase 1 task sequencing
- `specs/design/*` owns repository-stable operating contracts
- `specs/tasks/task-template.md` owns execution-layer task schema
- `AGENTS.md` owns execution agent responsibilities
- `CLAUDE.md` owns guardrail and review policy
- `.claude/settings.json` owns machine-readable project settings only

## Scope Constraints

This change is limited to Phase 1 tasks 1.1 through 1.11 from the frozen bootstrap checklist:
- 1.1 `openspec/changes/` and `openspec/specs/` base structure
- 1.2 `specs/design/` directory and initial design skeleton
- 1.3 `specs/tasks/task-template.md`
- 1.4 `AGENTS.md`
- 1.5 `CLAUDE.md`
- 1.6 `.claude/settings.json`
- 1.7 `scripts/lint.sh` skeleton
- 1.8 `scripts/typecheck.sh` skeleton
- 1.9 `scripts/test-unit.sh` skeleton
- 1.10 `scripts/test-integration.sh` skeleton
- 1.11 `scripts/test-e2e.sh` skeleton

Out of scope:
- real script implementation (logic beyond placeholders)
- CI integration
- hooks that enforce behavior at runtime
- Phase 2 pilot work
- later hardening and automation

## Explicit Constraints

- All Phase 1 outputs must be declarative skeletons, not enforcement logic.
- No new runtime dependencies may be introduced.
- No file outside the Phase 1 skeleton scope may be modified except active OpenSpec change artifacts.
- Frozen `docs/drafts/*.md` may be referenced for migration context but must not remain the active instruction source after Phase 1 artifacts exist.
- `.claude/settings.json` must stay minimal and non-misleading; if enforcement is not implemented yet, the file must not imply that it is.
- `AGENTS.md`, `CLAUDE.md`, and `.claude/settings.json` must avoid duplicated ownership:
  - responsibilities in `AGENTS.md`
  - guardrail narrative in `CLAUDE.md`
  - machine-readable config only in `.claude/settings.json`

## PBT Properties

1. Single active source boundary
   - Invariant: Phase 1 artifacts point future work to active OpenSpec and repo skeleton files, not frozen drafts.
   - Falsification: A new Phase 1 artifact still instructs operators to edit `docs/drafts/*.md` as live specs.

2. Declarative-only skeleton
   - Invariant: Phase 1 artifacts define structure and policy but do not claim enforcement that does not yet exist.
   - Falsification: A settings or policy file declares an active hook, script gate, or CI behavior that is not implemented.

3. Stable task-template core
   - Invariant: The task template contains the core execution fields from the frozen spec without locking in later-phase implementation details.
   - Falsification: The template either omits required core fields (`task_id`, `change_id`, `validation_matrix`, `required_evidence`) or hard-codes later-phase fields as mandatory runtime behavior.

4. Ownership separation
   - Invariant: Each Phase 1 governance artifact has a distinct responsibility boundary.
   - Falsification: The same rule is specified inconsistently across `AGENTS.md`, `CLAUDE.md`, and `.claude/settings.json`.

## Acceptance for Planning

This change is ready for implementation when:
- `proposal.md`, `design.md`, and `tasks.md` exist under `openspec/changes/phase1-skeleton/`
- `tasks.md` uses checkbox format only
- the tasks map directly to Phase 1 skeleton work and exclude later phases
