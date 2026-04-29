# Current Claude Code + Codex Stack: End-to-End Flow Diagram

This document explains the current stack as a flow from user request to final manifest result.
It complements `docs/current-claude-codex-stack-layers.md`, which focuses on the configuration layers themselves.

## 1. High-Level End-to-End Flow

```text
[User]
  ↓
[Claude Code control plane]
  - receives request
  - plans
  - decomposes
  - routes
  - coordinates review
  - synthesizes delivery
  ↓
[OpenSpec task/spec contract]
  - task_id
  - change_id
  - constraints
  - risk_level
  - validation matrix
  - required evidence
  ↓
[Routing decision]
  ├─ tiny non-code work → Claude local handling
  ├─ search work       → Grok-first path
  └─ code work         → Codex execution path
                           ↓
                       [Codex profiles]
                       - planner54
                       - executor53
                       - reviewer54
                       - Codex-1
                           ↓
[Process gates]
  - Claude hooks
  - worktree preflight
  - lease / write_scope control
  - repository-owned verify/review/acceptance
  ↓
[Artifacts]
  - search-plan.md
  - verify.txt
  - review.txt
  - acceptance.txt
  - active-lease.json
  - manifest.json
  ↓
[Workflow conclusion]
  - verified
  - failed-validation
  - policy-blocked
  - requires-human
  - awaiting-review
  - spec-mismatch
  - transient
```

## 2. Swimlane View

```text
User
  │
  │ request
  ▼
Claude Code
  │ understand
  │ plan
  │ decompose
  │ route
  ▼
OpenSpec task contract
  │ bind task to change_id
  │ constrain scope
  │ declare risk + evidence + validation
  ▼
Claude routing
  ├──────────► Grok/search path
  ├──────────► Claude local tiny edit path
  └──────────► Codex execution path
                   ▼
Codex
  │ profile selection
  │ plan / execute / review role split
  ▼
Claude hooks + repo gates
  │ preflight
  │ config protection
  │ fact-force gate
  │ quality gate
  │ validation gate
  ▼
Repository artifacts
  │ verify.txt
  │ review.txt
  │ acceptance.txt
  │ manifest.json
  ▼
Claude final synthesis
  │ result interpretation
  │ delivery
  ▼
User
```

## 3. User Input Layer

The process starts from the user, but user input is not supposed to become direct code mutation.

The stack first interprets the request as:
- a routing problem
- a task-bound problem
- a risk/scoping problem

That means the system tries to avoid the pattern:
- user request → immediate edit

Instead it aims for:
- user request → control interpretation → task contract → execution

## 4. Claude Control Plane

Current controller responsibilities are concentrated in Claude Code.

Main responsibilities:
- receive user intent
- interpret the task
- decide whether the task is code/search/local
- decompose large work
- coordinate review and synthesis
- maintain continuity through session discipline

This is why the system should be read as Claude-led even though Codex is heavily used for code-path execution.

## 5. Contract Plane: OpenSpec Tasks

Before execution, work is supposed to be shaped by task artifacts.

The task contract currently defines:
- identity: `task_id`, `change_id`
- state: `status`
- scope: `constraints`, `files_or_areas_expected`
- dependency references: `dependencies`, `approved_design_refs`
- risk metadata: `risk_level`, `review_notes`, `rollback_considerations`
- completion rules: `Validation Matrix`, `Required Evidence`

This converts a conversational request into a bounded work object.

## 6. Routing Decision Plane

After the task is understood, Claude routes it.

Current routing split:

### A. Tiny non-code edits
These may stay in Claude local handling when speed is more important than delegated execution.

### B. Search tasks
These prefer the Grok-first path.

### C. Code tasks
These are intended to route to Codex-oriented execution.

This routing plane is one of the most important separations in the stack because it prevents one surface from doing everything by default.

## 7. Codex Execution Plane

When Claude delegates code work, Codex becomes the main execution surface.

Current role profiles:

### `planner54`
Used for planning-oriented work.
Likely emphasis:
- structure
- implementation breakdown
- higher-level reasoning

### `executor53`
Used for main coding work.
Likely emphasis:
- writing code
- changing files
- implementing task-bounded changes

### `reviewer54`
Used for read-only review.
Likely emphasis:
- checking code without mutation
- separation between implementation and inspection

### `Codex-1`
Used as a high-autonomy unrestricted profile.
Likely emphasis:
- strongest execution path
- fallback for cases needing broad system access

## 8. Permission Plane

Execution happens inside a broad-permission environment.

### Claude side
Claude has broad shell and file access with a low-friction default permission mode.

### Codex side
Codex defaults are also high-autonomy:
- `approval_policy = never`
- default unrestricted mode exists
- role profiles vary by sandbox strictness

This means the stack is not relying on frequent human approval prompts.
Instead it relies on control layers after or around permission.

## 9. Claude Hook Gate Plane

Once tools are being used, the hook system acts like a governance wrapper around execution.

### Pre-tool phase
Important behavior here:
- shell calls are dispatched through a preflight layer
- first edits can be blocked until facts are gathered
- edits to protective configuration can be blocked
- MCP health can be checked before use
- governance and observation logging can begin immediately

### Post-tool phase
Important behavior here:
- quality gates can run after edits
- design drift warnings can appear
- modified files can be accumulated for batch checks
- governance and session activity can be recorded

### Response-end phase
Important behavior here:
- batch format + typecheck can be run once per response
- modified files can be checked for logging leftovers
- session state and cost data can be persisted

The purpose of this plane is to compensate for the high-permission execution model by adding behavioral friction and observability around writes.

## 10. Repository Gate Plane

After hook-level process control, the repository itself provides a second gate plane.

### `worktree-preflight.sh`
This checks whether the task and repository context are valid before the core flow proceeds.

Examples of what it constrains:
- task path shape
- change binding
- task id safety
- base ref validity
- expected worktree naming
- task metadata consistency

### `scheduler-dry-run.sh`
This acts like a repository-local coordination layer.

Important functions include:
- generating `run_id`
- writing `search-plan.md`
- acquiring a lease
- constraining `write_scope`
- controlling legal task status transitions
- optionally updating derived mirrors

This layer is a transition from simple scripting toward scheduler semantics.

## 11. Lease and Scope Plane

A special part of the repository gate plane is lease/scope control.

Main coordination artifact:
- `artifacts/tasks/<task_id>/active-lease.json`

What this plane contributes:
- single-writer style ownership
- explicit declaration of writable scope
- timestamps for acquisition and release
- result-state continuity

This is important because it tries to prevent task collisions and uncontrolled multi-writer behavior.

## 12. Validation Plane

After execution, the repository uses a three-step validation stack.

### Step 1: `verify.sh`
Technical verification plane.

Role:
- run validation matrix checks
- verify required evidence references
- emit `verify.txt`

### Step 2: `review-check.sh`
Risk review plane.

Role:
- apply low/medium/high risk policy
- block insufficient medium/high risk documentation
- prevent unsafe autonomous closure at the risk layer

### Step 3: `acceptance.sh`
Final acceptance plane.

Role:
- aggregate preflight, verify, and review outcomes
- check required evidence completeness
- check contract consistency
- emit `acceptance.txt`
- emit canonical `manifest.json`

Together these scripts convert activity into a repository-owned conclusion.

## 13. Artifact Plane

The artifact plane is the evidence plane.

Expected run outputs:
- `search-plan.md`
- `verify.txt`
- `review.txt`
- `acceptance.txt`
- `manifest.json`

Task-level coordination artifact:
- `active-lease.json`

This plane matters because it prevents the workflow from ending as a vague natural-language claim.
The run is expected to produce machine-checkable records.

## 14. Manifest / Result Plane

The final machine-readable conclusion is captured in `manifest.json`.

Typical result fields include:
- task identity
- change identity
- run identity
- risk level
- gate exit codes
- acceptance status
- task state before/after
- writeback behavior
- evidence paths
- missing evidence paths
- result state
- lease timing

This is the workflow’s final normalized output contract.

### Result states
Observed states include:
- `verified`
- `failed-validation`
- `policy-blocked`
- `requires-human`
- `awaiting-review`
- `spec-mismatch`
- `transient`

These states are stronger than plain pass/fail because they separate:
- technical failure
- policy failure
- contract mismatch
- human escalation
- transient operational issues

## 15. Optional CI Recheck Plane

Above the local workflow, there is also a CI pilot path.

Main entrypoint:
- `scripts/ci-unified-gate-pilot.sh`

Its role is to:
- construct a synthetic worktree
- replay the repository-owned gate sequence
- compare local semantics with CI semantics
- detect mutation of canonical repository state
- ensure manifest/log agreement
- produce a structured conclusion

This creates a second-layer recheck surface outside the normal local execution path.

## 16. Practical End-to-End Summary

The current effective workflow can be summarized as:

1. User asks for work
2. Claude interprets and routes it
3. OpenSpec task data constrains the task
4. Claude selects the execution path
5. Codex performs most code-path work
6. Claude hooks govern process behavior before and after tool use
7. repository scripts govern task validity and acceptance
8. artifacts are emitted as evidence
9. manifest normalizes the final outcome
10. optional CI can re-run the gate logic in a more isolated mode

## 17. Key Architectural Character

The defining architectural character of the stack is this:

It is not trying to achieve safety mainly through low permissions.
It is trying to achieve safety and repeatability through layered contracts, gates, artifacts, and result normalization around a high-autonomy execution model.

That is the core logic connecting the entire flow.
