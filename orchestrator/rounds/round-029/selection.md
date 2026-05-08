### Selected Extraction
- Milestone: Stabilize the Workflow DSL As Pure Planning Syntax
- Milestone id: milestone-002-workflow-dsl-stabilization
- Direction id: direction-005-dsl-transition-ports
- Extracted item id: item-029-dsl-transition-ports
- Extracted item summary: Port one DocsMigration transition and one moifold transition to the pure workflow DSL helpers, with parity coverage proving the DSL-authored transitions preserve event, state, effect, replay, permission, action ordering, and dry-run behavior.
- Roadmap id: 2026-05-08-00-framework-kernel-migration
- Roadmap revision: rev-001
- Roadmap dir: orchestrator/roadmaps/2026-05-08-00-framework-kernel-migration/rev-001

### Boundaries
- In scope: one non-PR DocsMigration transition and one moifold workflow transition, additive use of existing `WorkflowM` / `Transition` / `advance` DSL helpers, focused parity tests comparing old and DSL transition outputs, and only the minimal helper adjustments needed to preserve existing event, state, effect, replay, permission, action-ordering, and dry-run behavior.
- Out of scope: event schema or golden fixture changes, effect-ordering changes, direct IO or `liftIO` in the DSL, indexed-do complexity, broad transition rewrites beyond the two selected proofs, transaction/daemon/core runtime extraction, Codex or GitHub adapter API stabilization, compatibility facade removal, roadmap edits, `plan.md`, implementation notes, merge notes, reviews, and `state.json`.
- Concurrent batch context: none; controller state allows only one active round and the roadmap keeps DSL transition-port work in the default serial lane unless a planner later authors a lawful disjoint worker plan.

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
Milestone 001 is complete through round 027, satisfying the dependency for milestone 002. Round 028 completed `direction-004-dsl-core-ergonomics`, which was the prerequisite DSL helper and law slice; the active roadmap now names `direction-005-dsl-transition-ports` as the remaining milestone 002 direction.

This extraction should run now because the DSL has focused helper coverage but has not yet proven authoring value on real workflow transitions. A two-transition parity slice is the smallest roadmap-aligned round that can satisfy the milestone's completion signal while preserving the project contract: workflow code stays pure planning syntax, effects remain inspectable data, event-log shape stays stable, and concrete moifold policy stays outside generic core.
