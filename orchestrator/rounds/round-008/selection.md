### Selected Item
- Roadmap item: Port PR-review worker outcome transitions to the indexed API
- Item id: item-008-indexed-pr-review-worker-outcomes
- Roadmap id: 2026-05-07-00-workflow-kernel-indexing
- Roadmap revision: rev-002
- Roadmap dir: orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-002

### Rationale
The active round state is `round-008` at `select-task` and already names `item-008-indexed-pr-review-worker-outcomes` as the current roadmap item. In the active `rev-002` roadmap, this item is the first pending item after `item-007-indexed-pr-review-checking`, depends on that item, and has `Merge after: item-007-indexed-pr-review-checking`. The roadmap records item 007 as done, and `state.json` records `last_completed_round` as `round-007`, so the dependency and ordering gate are satisfied. Later PR-review reviewer, mergeability, daemon-routing, and next-domain items all depend directly or transitively on item 008, so selecting this single non-parallel item preserves the roadmap order.
