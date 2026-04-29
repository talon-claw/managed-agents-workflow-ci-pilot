## Why

Phase 1 already provides a repository-local validation loop, but platform-level automation remains fragmented:

- CI still lacks a unified gate invocation contract.
- command guard / enforcement is not yet active as a controlled layer.
- Claude + Codex collaboration relies on manual orchestration and lacks a stable scheduler wrapper.
- task status and run outcomes are not automatically written back to task specs and change tracking.

Without a dedicated platformization plan, we risk scaling manual process drift instead of scaling a deterministic workflow.

## What Changes

- Introduce active change `phase2-automation-platformization` for implementation planning only.
- Define a staged automation plan across four tracks:
  1) CI unified gate integration
  2) guard/enforcement rollout
  3) Claude+Codex stable scheduling wrapper
  4) automatic status writeback
- Define contracts, boundaries, rollout order, and rollback controls for each track.
- Keep the change implementation-ready but non-executing: no forced CI behavior or runtime interception is activated by this change itself.

## Out Of Scope

- Rewriting existing verification semantics in `scripts/verify.sh` or `scripts/acceptance.sh`.
- Introducing full autonomous merge/release flows.
- Enabling destructive command auto-approval.
- Replacing OpenSpec as the source of planning truth.

## Impact

- Establishes a concrete OpenSpec execution plan for controlled platform expansion.
- Makes high-risk automation work reviewable before implementation.
- Reduces orchestration ambiguity by defining a single scheduling and status-writeback contract.
