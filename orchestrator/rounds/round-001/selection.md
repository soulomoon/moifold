### Selected Item
- Roadmap item: Extract generic checked-action failure traversal into core
- Item id (`roadmap_item_id`): item-001-checked-action-failure-core
- Roadmap id (`roadmap_id`): 2026-05-07-00-workflow-kernel-indexing
- Roadmap revision (`roadmap_revision`): rev-001
- Roadmap dir (`roadmap_dir`): orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-001

### Rationale
This is dependency-ready now because the active roadmap marks `item-001-checked-action-failure-core` as pending with `Depends on: none` and `Merge after: none`. It is also the smallest first dependency in the workflow-kernel indexing sequence: later facade-law, boundary-guard, indexed-API, DocsMigration, and PR-review items all depend directly or transitively on this core extraction. The roadmap does not authorize parallel execution for this item, and `orchestrator/state.json` already binds `round-001` to this same item and active roadmap revision, so selecting it keeps the round aligned with the current controller state.
