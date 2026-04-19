# Risk Policy

## Purpose
Define a minimal Phase 1 risk classification model for repository changes.

## Risk Levels
- **Low**: Declarative documentation, task metadata, or non-executable skeleton changes.
- **Medium**: Source changes, script changes, dependency changes, or changes that alter repository workflow semantics.
- **High**: Security-sensitive behavior, destructive operations, CI or automation wiring, or runtime enforcement.

## Expected Handling
- Low risk work should still include a validation matrix and required evidence.
- Medium risk work should include explicit review notes and rollback considerations in the task artifact.
- High risk work is outside the intended scope of Phase 1 unless a later approved change expands the boundary.

## Phase 1 Boundary
This policy describes risk expectations only. It does not itself enforce approvals, block execution, or activate automation.
