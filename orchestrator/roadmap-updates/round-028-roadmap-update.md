### Source Round
- Round id: round-028
- Merged commit: f3b2280
- Evidence: `orchestrator/rounds/round-028/selection.md`, `orchestrator/rounds/round-028/review.md`, `orchestrator/rounds/round-028/review-record.json`, `orchestrator/rounds/round-028/merge.md`, and the squash commit `f3b2280`.

### Roadmap Change
- Roadmap id: 2026-05-08-00-framework-kernel-migration
- Prior revision: rev-001
- Proposed revision: rev-001
- Files changed: `orchestrator/roadmaps/2026-05-08-00-framework-kernel-migration/rev-001/roadmap.md`

### Rationale
Round 028 completed `milestone-002-workflow-dsl-stabilization` direction `direction-004-dsl-core-ergonomics` for extracted item `item-028-dsl-core-ergonomics-laws`. The approved and merged work added a pure DSL failure helper and focused law/parity tests for `WorkflowM` effect ordering, short-circuiting, phase-changing `advance`, and moifold plus DocsMigration planned pre/post commit projections.

This only updates progress within the active rev-001 roadmap. It does not change milestone dependencies, future sequencing, parallel lanes, retry semantics, roadmap metadata, or the completion signal for milestone 002. The milestone stays pending because direction 005 still needs to port one DocsMigration transition and one moifold transition to the DSL with parity evidence.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
