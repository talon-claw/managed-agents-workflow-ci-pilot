# Current Claude Code + Codex Stack: Layered Configuration Explanation

This document explains the current local automation stack as configured on the machine and as reflected in the repository workflow conventions. It is a configuration-focused explanation rather than a runtime verification report.

## 1. System Positioning

The current setup is not a flat "two tools side by side" arrangement.

It is better understood as a layered collaboration stack:

1. Claude Code as the primary control plane
2. OpenSpec task/spec constraints as the contract plane
3. Codex as the main code execution plane
4. Hook-based and repository-owned gates as the process control plane
5. Artifact and manifest outputs as the result plane

In short:

- Claude is the controller
- Codex is the main code executor
- OpenSpec constrains task scope
- hooks and gate scripts constrain process behavior
- artifacts and manifests constrain final conclusions

## 2. Orchestration Layer

Primary control currently lives in Claude Code.

Repository evidence:
- `CLAUDE.md`
- `~/.claude/CLAUDE.md`

Key control policy currently present:
- Claude Code is the main orchestration surface
- Claude handles planning, decomposition, routing, review coordination, synthesis, and delivery control
- staged execution is preferred: understand -> plan -> execute -> verify -> handoff
- tmux-backed persistent sessions are preferred for long-running work

This means the current system is controller-first, not executor-first.

## 3. Routing Layer

The routing policy is explicit rather than ad hoc.

### Claude-side routing policy

From `~/.claude/CLAUDE.md`:
- code tasks default to Codex-oriented execution
- tiny non-code edits may be handled locally in Claude
- search tasks prefer Grok first

### Codex-side execution profiles

From `~/.codex/config.toml`:
- default model provider: `owl`
- default model: `gpt-5.4`
- explicit execution profiles exist:
  - `planner54`
  - `executor53`
  - `reviewer54`
  - `Codex-1`

Current role split:
- `planner54`: planning and analysis profile
- `executor53`: main code-writing profile
- `reviewer54`: read-only review profile
- `Codex-1`: unrestricted high-autonomy execution profile

This gives the stack role-based routing rather than one undifferentiated execution mode.

## 4. Provider / API Access Layer

Both Claude Code and Codex are currently configured around the Owl-compatible endpoint as the main path.

### Claude-side provider signals

From `~/.claude/settings.json`:
- `OPENAI_BASE_URL=https://api.owlai.tech/v1`
- `OPENAI_API_BASE=https://api.owlai.tech/v1`
- `model=gpt-5.4`

### Codex-side provider signals

From `~/.codex/config.toml`:
- `model_provider = "owl"`
- `model_providers.owl.base_url = "https://api.owlai.tech/v1"`
- fallback provider retained:
  - `model_providers.cliproxy.base_url = "http://127.0.0.1:8317/v1"`

Current provider conclusion:
- main route: Owl
- retained backup route: local cliproxy
- both controller and executor are normalized around compatible API surfaces

## 5. Permission and Sandbox Layer

The setup is high-autonomy, not conservative.

### Claude-side permissions

From `~/.claude/settings.json` and `~/.claude/settings.local.json`:
- broad Bash access is allowed
- file operations are allowed
- `defaultMode` is non-interruptive rather than approval-heavy
- `openspec` commands are explicitly permitted

### Codex-side permissions

From `~/.codex/config.toml`:
- global default: `approval_policy = "never"`
- global default: `sandbox_mode = "danger-full-access"`
- profile-level sandboxes:
  - `planner54`: `workspace-write`
  - `executor53`: `workspace-write`
  - `reviewer54`: `read-only`
  - `Codex-1`: `danger-full-access`

This is not a low-permission design.
It is a high-permission design with downstream gates.

## 6. Claude Hook / Plugin Governance Layer

This is one of the most important layers in the current stack.

The main plugin surface is the Everything Claude Code marketplace plugin.

Relevant files:
- `~/.claude/settings.json`
- `~/.claude/plugins/marketplaces/everything-claude-code/hooks/hooks.json`

### What this layer does

Claude is not acting alone. Its tool usage is wrapped by lifecycle hooks:
- `PreToolUse`
- `PostToolUse`
- `Stop`
- `SessionStart`
- `SessionEnd`
- `PreCompact`
- `PostToolUseFailure`

### Important pre-execution gates

1. `pre:bash:dispatcher`
- all Bash calls pass through a dispatcher
- shell behavior is not treated as raw free execution

2. `pre:config-protection`
- blocks edits to linter / formatter / config guardrails
- prevents passing checks by weakening standards

3. `pre:edit-write:gateguard-fact-force`
- blocks the first write/edit on a file until investigation is done
- forces fact gathering before modification

4. `pre:mcp-health-check`
- checks MCP health before MCP tool usage

5. `pre:governance-capture`
- records governance-sensitive events

6. `pre:observe:continuous-learning`
- records tool-use observations for later pattern learning

### Important post-execution gates

1. `post:bash:dispatcher`
- post-shell dispatch, logging, and workflow reactions

2. `post:quality-gate`
- runs quality gates after edits

3. `post:edit:design-quality-check`
- warns when frontend work drifts toward generic template output

4. `post:edit:accumulate`
- collects edited files for end-of-response batch checks

5. `post:edit:console-warn`
- warns on console logging after edits

6. `post:governance-capture`
- records governance data from tool outputs

7. `post:session-activity-tracker`
- tracks session-level activity for metrics

8. `post:observe:continuous-learning`
- records results for continuous learning

### Important response-end and session gates

1. `stop:format-typecheck`
- batch format and typecheck at the end of the response

2. `stop:check-console-log`
- checks modified files for console logs

3. `stop:session-end`
- persists session state

4. `stop:evaluate-session`
- evaluates the session for extractable patterns

5. `stop:cost-tracker`
- captures token and cost metrics

6. `session:start`
- bootstraps prior context and environment awareness

7. `session:end:marker`
- records lifecycle closure

### Summary of this layer

Claude is currently acting as a governed control plane rather than a plain conversational shell.

## 7. OpenSpec Task Contract Layer

The repository itself defines a task contract surface.

Relevant files:
- `openspec/config.yaml`
- `specs/tasks/task-template.md`
- `specs/tasks/*.md`

The task template currently requires fields such as:
- `task_id`
- `title`
- `change_id`
- `status`
- `owner`
- `base_ref`
- `publish_mode`
- `goal`
- `non_goals`
- `constraints`
- `files_or_areas_expected`
- `dependencies`
- `approved_design_refs`
- `risk_level`
- `review_notes`
- `rollback_considerations`
- `Validation Matrix`
- `Required Evidence`

This means repository work is intended to be task-bound, not free-form.

The active task object defines:
- what work is allowed
- what files are expected
- what the risk level is
- what evidence must be produced
- what validation methods count as completion

## 8. Worktree, Lease, and Task-State Control Layer

The repository also contains a scheduler-like coordination layer.

Relevant files:
- `scripts/worktree-preflight.sh`
- `scripts/scheduler-dry-run.sh`
- `scripts/ci-unified-gate-pilot.sh`

### Worktree preflight responsibilities

Current responsibilities include:
- validating `task_id`
- validating `change_id`
- validating task spec path shape
- checking bound change/task relationships
- checking `base_ref`
- checking low-risk pilot restrictions where applicable
- checking expected worktree naming conventions

### Lease responsibilities

Current lease file pattern:
- `artifacts/tasks/<task_id>/active-lease.json`

Current responsibilities include:
- single-writer ownership semantics
- declared `write_scope`
- acquisition and release timestamps
- run binding
- recording last result state

### Task status transition control

Current transition rules in `scheduler-dry-run.sh` are constrained rather than open-ended.
Allowed automated transitions include:
- `pending -> in-progress`
- `in-progress -> completed`
- `in-progress -> blocked`
- `blocked -> in-progress`

This means task writeback is treated as a state machine, not arbitrary text editing.

## 9. Repository Validation Layer

The repository-owned gate flow is implemented by three key scripts:
- `scripts/verify.sh`
- `scripts/review-check.sh`
- `scripts/acceptance.sh`

### `verify.sh`

Primary role:
- execute the validation matrix
- check evidence references
- emit `verify.txt`

### `review-check.sh`

Primary role:
- apply risk-level review policy
- enforce stronger requirements for medium/high risk tasks

Observed policy direction:
- low risk: local gate path allowed
- medium risk: requires non-placeholder review/rollback notes
- high risk: blocked for local autonomous completion and escalated to human review

### `acceptance.sh`

Primary role:
- collect preflight, verify, and review results
- check required evidence presence
- check contract consistency
- emit `acceptance.txt`
- emit canonical `manifest.json`

This gives the system a repository-owned final acceptance plane.

## 10. Artifact and Evidence Layer

Current canonical run outputs are organized under:
- `artifacts/tasks/<task_id>/<run_id>/`

Expected standard outputs include:
- `search-plan.md`
- `verify.txt`
- `review.txt`
- `acceptance.txt`
- `manifest.json`

Task-level coordination state includes:
- `artifacts/tasks/<task_id>/active-lease.json`

This means conclusions are intended to be evidence-backed and machine-readable.

## 11. Result-State Layer

The manifest contract is not just pass/fail. It records structured conclusions.

Fields observed in manifests and gate scripts include:
- `task_id`
- `change_id`
- `run_id`
- `base_ref`
- `risk_level`
- `result_state`
- `preflight_exit`
- `verify_exit`
- `review_exit`
- `acceptance_status`
- `task_status_before`
- `task_status_after`
- `task_writeback`
- `mirror_writeback`
- `scope_guard_status`
- `evidence_paths`
- `missing_evidence_paths`
- lease timestamps

Observed result-state vocabulary includes:
- `verified`
- `failed-validation`
- `policy-blocked`
- `requires-human`
- `awaiting-review`
- `spec-mismatch`
- `transient`

This is a stateful workflow result system, not a free-text summary system.

## 12. CI Read-Only Recheck Layer

The repository also contains a CI-oriented synthetic worktree pilot:
- `scripts/ci-unified-gate-pilot.sh`

Current responsibilities include:
- constructing a synthetic worktree
- copying repository-owned gate scripts into that environment
- running preflight/verify/review/acceptance in fixed order
- checking for canonical-state mutation
- checking manifest/log consistency
- producing a final machine-readable conclusion

This acts as a read-only or read-mostly externalized recheck plane above local orchestration.

## 13. Current Practical Interpretation

The current stack is best interpreted as:

- Claude Code = control plane
- OpenSpec task specs = contract plane
- Codex = main code execution plane
- Claude hooks + repo scripts = gate and governance plane
- artifacts + manifests = result plane

A concise summary:

It is better described as a controlled autonomous workflow stack than as a pair of model CLIs.

## 14. Current Strengths

The strongest current architectural properties are:
- explicit controller/executor separation
- task-bound repository work rather than free-form modification
- multiple gates before and after write activity
- evidence-backed completion instead of narrative-only completion
- result-state normalization through manifests
- support for lease and scope concepts

## 15. Current Asymmetry

There is also an important asymmetry:
- governance density is much heavier on the Claude side than on the Codex side
- Codex has strong profile-level role separation and sandbox differentiation
- Claude has the denser hook-based governance and lifecycle instrumentation

So the stack is not symmetrical. It is controller-heavy on Claude and execution-heavy on Codex.
