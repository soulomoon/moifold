### Selected Item
- Roadmap item: Harden package boundary guards for the indexed rewrite
- Item id (`roadmap_item_id`): item-003-boundary-guards
- Roadmap id (`roadmap_id`): 2026-05-07-00-workflow-kernel-indexing
- Roadmap revision (`roadmap_revision`): rev-001
- Roadmap dir (`roadmap_dir`): orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-001

### Rationale
This item is dependency-ready now because the active roadmap marks `item-002-facade-laws` as done, with completion notes recording it as completed in `round-002`. The same roadmap declares `item-003-boundary-guards` with `Depends on: item-002-facade-laws` and `Merge after: item-002-facade-laws`, so both the dependency and ordering gate are satisfied by the completed round-002 facade-law work.

`orchestrator/state.json` binds the active `round-003` to `item-003-boundary-guards`, the `rev-001` roadmap bundle, and the task "Harden package boundary guards for the indexed rewrite"; it also records `last_completed_round` as `round-002`. The roadmap does not authorize parallel execution for this item (`Parallel safe: no`, `Parallel group: none`), and the next roadmap item depends on these boundary guards. Selecting only `item-003-boundary-guards` is therefore the smallest dependency-valid next step.
