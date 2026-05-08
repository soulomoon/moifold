### Selected Item
- Roadmap item: Port issue-planning policy transitions to the indexed API
- Item id: item-013-indexed-issue-planning-policy
- Roadmap id: 2026-05-07-00-workflow-kernel-indexing
- Roadmap revision: rev-003
- Roadmap dir: orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-003

### Rationale
The active round state is `round-013` at `select-task` and names `item-013-indexed-issue-planning-policy` as the current `roadmap_item_id`. In the active `rev-003` roadmap, this is the first pending item after `item-012-indexed-next-domain-plan`; it depends on item 012 and declares `Merge after: item-012-indexed-next-domain-plan`. The roadmap marks item 012 done, `state.json` records `last_completed_round` as `round-012`, and the active round has no round dependencies, so the dependency and ordering gates are satisfied. The item is not parallel-safe and no parallel item set is authorized, so selecting this single issue-planning policy slice matches the current round state.
