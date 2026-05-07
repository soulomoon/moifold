### Selected Item
- Roadmap item: Introduce the parallel indexed WorkflowSpec API
- Item id (`roadmap_item_id`): item-004-indexed-spec-api
- Roadmap id (`roadmap_id`): 2026-05-07-00-workflow-kernel-indexing
- Roadmap revision (`roadmap_revision`): rev-001
- Roadmap dir (`roadmap_dir`): orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-001

### Rationale
This item is dependency-ready now because the active roadmap bundle marks `item-003-boundary-guards` as done, with completion notes recording it as completed in `round-003`. The same roadmap declares `item-004-indexed-spec-api` with `Depends on: item-003-boundary-guards` and `Merge after: item-003-boundary-guards`, so both the dependency gate and merge-order gate are satisfied by the completed round-003 boundary-guard work.

`orchestrator/state.json` binds the active `round-004` to `item-004-indexed-spec-api`, the `rev-001` roadmap bundle, and the task "Introduce the parallel indexed WorkflowSpec API"; it also records `last_completed_round` as `round-003`, `depends_on_round_ids` as `round-003`, and `merge_after_item_ids` as `item-003-boundary-guards`. The roadmap does not authorize parallel execution for this item (`Parallel safe: no`, `Parallel group: none`), and the later indexed DocsMigration and PR-review slice items both depend on it. Selecting only `item-004-indexed-spec-api` is therefore the smallest dependency-valid next step. No selection uncertainty was found.
