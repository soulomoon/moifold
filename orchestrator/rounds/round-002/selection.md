### Selected Item
- Roadmap item: Add workflow facade law and parity coverage
- Item id (`roadmap_item_id`): item-002-facade-laws
- Roadmap id (`roadmap_id`): 2026-05-07-00-workflow-kernel-indexing
- Roadmap revision (`roadmap_revision`): rev-001
- Roadmap dir (`roadmap_dir`): orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-001

### Rationale
This item is dependency-ready now because the active roadmap marks `item-001-checked-action-failure-core` as done, and `orchestrator/state.json` records `last_completed_round` as `round-001`. The roadmap declares `item-002-facade-laws` with `Depends on: item-001-checked-action-failure-core` and `Merge after: item-001-checked-action-failure-core`; both ordering requirements are satisfied by the completed round-001 core extraction. `orchestrator/state.json` also binds the active `round-002` to `item-002-facade-laws`, the same roadmap revision, and the task "Add workflow facade law and parity coverage", so this selection matches the controller's current stage and active roadmap bundle.

The roadmap does not authorize parallel execution for this item (`Parallel safe: no`, `Parallel group: none`), and the next later item depends on this facade-law coverage. Selecting only `item-002-facade-laws` is therefore the smallest dependency-valid next step.
