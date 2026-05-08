### Selected Extraction
- Milestone: Stabilize the Workflow DSL As Pure Planning Syntax
- Milestone id: milestone-002-workflow-dsl-stabilization
- Direction id: direction-004-dsl-core-ergonomics
- Extracted item id: item-028-dsl-core-ergonomics-laws
- Extracted item summary: Tighten the core `WorkflowM` / `Transition` / `advance` DSL surface and focused tests so effect accumulation, phase-changing transition construction, and pre/post commit projection are law-covered before real workflow transitions are ported.
- Roadmap id: 2026-05-08-00-framework-kernel-migration
- Roadmap revision: rev-001
- Roadmap dir: orchestrator/roadmaps/2026-05-08-00-framework-kernel-migration/rev-001

### Boundaries
- In scope: additive DSL API refinements in `agent-workflow-core/src/CodexWatcher/Workflow/DSL.hs`, focused `watcher-core-test` coverage for `WorkflowM` accumulation/order, `advance` lowering through `workflowPlanTransition`, `Transition` event/value accessors, and pre/post commit projection parity against existing `PlannedTransition` behavior.
- Out of scope: porting DocsMigration or moifold transitions to the DSL, indexed-do or direct-IO DSL features, event codec or golden fixture edits, runtime/daemon/transaction movement, adapter API stabilization, compatibility facade removal, roadmap edits, `plan.md`, and `state.json`.
- Concurrent batch context: none; controller state allows only one active round, and this DSL core slice is serial before `direction-005-dsl-transition-ports`.

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
Milestone 001 is complete through round 027, satisfying the dependency for milestone 002. Within milestone 002, `direction-004-dsl-core-ergonomics` is the first dependency-ready direction and must precede `direction-005-dsl-transition-ports` because the roadmap requires helper and law coverage before real transitions are rewritten through the DSL.

This extraction should run now because the current DSL surface already exists in `agent-workflow-core`, but its next useful step is still narrow: prove the pure planning syntax preserves effect ordering and `PlannedTransition` projections without giving workflow authors IO authority or changing event-log, dry-run, daemon, adapter, or compatibility behavior. That gives the planner a bounded core/API round and leaves the DocsMigration plus moifold transition parity work for the following direction.
