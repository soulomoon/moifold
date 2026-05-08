### Selected Extraction
- Milestone: Consolidate the WorkflowSpec Contract
- Milestone id: milestone-001-workflow-spec-contract
- Direction id: direction-001-spec-inventory-and-laws
- Extracted item id: item-025-workflow-spec-inventory-law-baseline
- Extracted item summary: Inventory current `WorkflowSpec` and `IndexedWorkflowSpec` users and add the first focused law/coverage baseline for parity, labels, replay state projection, terminal checks, and permission/effect hooks across the existing moifold and DocsMigration spec surfaces.
- Roadmap id: 2026-05-08-00-framework-kernel-migration
- Roadmap revision: rev-001
- Roadmap dir: orchestrator/roadmaps/2026-05-08-00-framework-kernel-migration/rev-001

### Boundaries
- In scope: read and map the current unindexed and indexed spec surfaces in `agent-workflow-core/src/CodexWatcher/Workflow/Spec.hs`, `agent-workflow-core/src/CodexWatcher/Workflow/Indexed/Spec.hs`, `src/CodexWatcher/Workflow/Types.hs`, `src/CodexWatcher/Workflow/DocsMigration.hs`, and existing indexed moifold adapters; add focused tests or source-scan assertions that expose concrete law and coverage gaps without changing runtime behavior.
- Out of scope: unifying or redesigning the public API, porting more daemon routing, changing event codecs or golden fixtures, altering DocsMigration or moifold transition behavior, editing roadmap files, or moving lifecycle policy between packages.
- Concurrent batch context: none; the roadmap sets milestone 001 on the default serial lane, and later spec/API directions depend on this inventory/law baseline.

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
Milestone 001 has no roadmap dependencies and should run before DSL, runtime-contract, adapter, or extraction-readiness work because it defines the kernel contract those later milestones consume. Direction 001 is the dependency-ready first step: the repository currently exposes both `WorkflowSpec` and `IndexedWorkflowSpec`, with compatibility adapters for moifold workflows and DocsMigration, and the roadmap explicitly asks for a read-heavy inventory/law round first when API gaps are not already settled.

Selecting this narrow baseline gives the planner a concrete way to discover drift between the unindexed facade and indexed contract before attempting `direction-002-indexed-contract-unification`. It also preserves the project contract: no event JSON schema changes, no golden log rewrites, no daemon/lifecycle ownership moves, and no compatibility facade removal in this round.
