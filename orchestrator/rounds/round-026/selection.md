### Selected Extraction
- Milestone: Consolidate the WorkflowSpec Contract
- Milestone id: milestone-001-workflow-spec-contract
- Direction id: direction-002-indexed-contract-unification
- Extracted item id: item-026-indexed-contract-compatibility-bridge
- Extracted item summary: Add the first additive compatibility bridge between the existing `WorkflowSpec` and `IndexedWorkflowSpec` surfaces, with focused migration tests proving current moifold and DocsMigration behavior still routes through the same labels, replay hooks, terminal checks, validation hooks, and effect permission hooks.
- Roadmap id: 2026-05-08-00-framework-kernel-migration
- Roadmap revision: rev-001
- Roadmap dir: orchestrator/roadmaps/2026-05-08-00-framework-kernel-migration/rev-001

### Boundaries
- In scope: additive core API or adapter helpers that reduce duplication between `WorkflowSpec` and `IndexedWorkflowSpec`; compatibility imports/modules needed by current moifold and DocsMigration callers; focused tests or source scans for indexed/unindexed parity, labels, replay projection, terminal semantics, validation, and effect permissions.
- Out of scope: repo-wide spec rewrites, DSL transition ports, daemon/runtime contract movement, adapter package API stabilization outside the touched bridge, event codec or golden fixture changes, public compatibility facade removal, production lifecycle policy movement, roadmap edits, `plan.md`, and `state.json`.
- Concurrent batch context: none; milestone 001 is on the default serial lane, and this direction touches core API plus moifold adapters.

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
Round 025 completed `direction-001-spec-inventory-and-laws` and the active roadmap now lists `direction-002-indexed-contract-unification` as the next dependency-ready direction in milestone 001. This is still before DSL, runtime-contract, adapter, and extraction-readiness milestones because those later surfaces consume the public workflow kernel vocabulary selected here.

The round should stay additive: the roadmap asks for a bridge and migration tests rather than a one-round rewrite, and the project contract requires existing moifold compatibility modules, event schemas, golden fixtures, daemon behavior, dry-run rendering, and concrete lifecycle ownership to remain stable. Selecting a bridge-sized extraction gives the planner room to reduce spec duplication where the round 025 baseline exposed it while keeping reviewer evidence local to the current `WorkflowSpec` / `IndexedWorkflowSpec` contract.
