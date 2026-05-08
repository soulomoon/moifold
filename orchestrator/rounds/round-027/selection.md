### Selected Extraction
- Milestone: Consolidate the WorkflowSpec Contract
- Milestone id: milestone-001-workflow-spec-contract
- Direction id: direction-003-terminal-and-observation-laws
- Extracted item id: item-027-terminal-observation-law-assertions
- Extracted item summary: Add focused law/assertion coverage, plus only minimal test-support helper APIs if needed, for observation consistency, terminal closure, replay determinism, and permission soundness across DocsMigration and one representative moifold workflow using the indexed bridge now available from round 026.
- Roadmap id: 2026-05-08-00-framework-kernel-migration
- Roadmap revision: rev-001
- Roadmap dir: orchestrator/roadmaps/2026-05-08-00-framework-kernel-migration/rev-001

### Boundaries
- In scope: focused tests or test-support helpers for terminal semantics, observation-to-event consistency, replay determinism, validation, and effect permission behavior across DocsMigration and one moifold workflow; source-scan or parity assertions that prove the additive indexed bridge preserves the existing spec obligations.
- Out of scope: runtime behavior changes, event codec or golden fixture edits, DSL transition ports, daemon or transaction API movement, adapter package stabilization, compatibility facade removal, roadmap edits, `plan.md`, and `state.json`.
- Concurrent batch context: none; milestone 001 is on the default serial lane, and this extraction depends on the round 026 bridge already being present in the merged base.

### Scheduler Fields
```json
{
  "depends_on_round_ids": [],
  "merge_after_item_ids": [],
  "parallel_group": null,
  "merge_ready": false
}
```

### Rationale
Round 026 completed `direction-002-indexed-contract-unification` and the active roadmap now makes `direction-003-terminal-and-observation-laws` the next dependency-ready slice in milestone 001. This keeps work inside the WorkflowSpec contract milestone before DSL, transaction/daemon, adapter, or extraction-readiness milestones consume the kernel vocabulary.

The round should be assertion-first: the roadmap calls for semantic drift coverage without runtime behavior changes, and the project contract keeps event logs, compatibility facades, daemon behavior, dry-run rendering, effect interpretation, and concrete lifecycle policy stable. A bounded law-focused extraction gives the planner clear ownership over the remaining spec obligations while leaving later API simplification and transition ports for subsequent milestones.
