### Source Round
- Round id: round-025
- Merged commit: d07df4c1d21a41484a4147d0f69fdd5c0da49ed3
- Evidence: `orchestrator/rounds/round-025/selection.md`, `orchestrator/rounds/round-025/review.md`, `orchestrator/rounds/round-025/review-record.json`, `orchestrator/rounds/round-025/merge.md`, and merge commit `d07df4c`.

### Roadmap Change
- Roadmap id: 2026-05-08-00-framework-kernel-migration
- Prior revision: rev-001
- Proposed revision: rev-001
- Files changed: `orchestrator/roadmaps/2026-05-08-00-framework-kernel-migration/rev-001/roadmap.md`

### Rationale
Round 025 completed `item-025-workflow-spec-inventory-law-baseline` for `direction-001-spec-inventory-and-laws`. The accepted and merged evidence shows the round added a source-scan inventory for the current `WorkflowSpec` and `IndexedWorkflowSpec` surfaces, DocsMigration indexed/unindexed law parity, and stronger PR-review mergeability law coverage, while leaving production workflow code, public API shape, event codecs, golden fixtures, project-contract text, and roadmap semantics unchanged.

The active roadmap therefore only needs a progress/status update: milestone 001 moves from pending to in-progress, direction 001 is marked complete with the merge commit, and direction 002's precondition is updated to refer to the merged round-025 baseline. No new revision is required because this does not change future coordination rules, sequencing semantics, milestone boundaries, parallel lanes, or active revision metadata.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
