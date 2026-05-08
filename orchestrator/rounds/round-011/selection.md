### Selected Item
- Roadmap item: Route one live PR-review daemon observation path through the indexed adapter
- Item id: item-011-indexed-pr-review-daemon-path
- Roadmap id: 2026-05-07-00-workflow-kernel-indexing
- Roadmap revision: rev-002
- Roadmap dir: orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-002

### Rationale
The active round state is `round-011` at `select-task` and names `item-011-indexed-pr-review-daemon-path` as the current roadmap item. In the active `rev-002` roadmap, this is the first pending item after `item-010-indexed-pr-review-mergeability-complete`; it depends on item 010 and declares `Merge after: item-010-indexed-pr-review-mergeability-complete`. The roadmap marks item 010 done, `state.json` records `last_completed_round` as `round-010`, and the active round has no pending round dependencies, so the dependency and ordering gates are satisfied. The next roadmap item depends on item 011, and item 011 is not parallel-safe, so selecting this single daemon-routing slice preserves the roadmap order.
