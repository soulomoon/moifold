### Source Round
- Round id: round-029
- Merged commit: 15cd4e5
- Evidence: `orchestrator/rounds/round-029/selection.md`,
  `orchestrator/rounds/round-029/plan.md`,
  `orchestrator/rounds/round-029/implementation-notes.md`,
  `orchestrator/rounds/round-029/review.md`,
  `orchestrator/rounds/round-029/review-record.json`,
  `orchestrator/rounds/round-029/merge.md`, and the squash commit `15cd4e5`.

### Roadmap Change
- Roadmap id: 2026-05-08-00-framework-kernel-migration
- Prior revision: rev-001
- Proposed revision: rev-001
- Files changed: `orchestrator/roadmaps/2026-05-08-00-framework-kernel-migration/rev-001/roadmap.md`

### Rationale
Round 029 completed `milestone-002-workflow-dsl-stabilization` direction
`direction-005-dsl-transition-ports` for extracted item
`item-029-dsl-transition-ports`. The approved and merged work routed one
DocsMigration transition and one moifold transition through pure DSL helpers:
the DocsMigration draft-produced transition and the issue-planning
turn-completed projection.

The review evidence records parity coverage for event, next state, effect
partitioning, replay, permission checks, phase/action validation, compiled
action ordering, and dry-run reporting, with `cabal build all`,
`cabal test watcher-core-test`, `git diff --check`, `git diff --cached --check`,
worker-plan absence, and `agent-workflow-core` forbidden-import scans passing.
This satisfies the milestone 002 completion signal without changing event
schemas, golden fixtures, effect ordering, runtime authority, package
ownership, compatibility facades, or roadmap sequencing.

This is a status-only update to the active rev-001 roadmap. It marks direction
005 and milestone 002 complete, but it does not change future milestone
dependencies, candidate direction boundaries, parallel lanes, retry semantics,
roadmap metadata, or active revision activation.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
