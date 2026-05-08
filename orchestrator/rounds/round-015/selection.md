### Selected Item
- Roadmap item: Route issue-planning graph and request daemon observations through the indexed adapter
- Item id: item-015-indexed-issue-planning-daemon-graph-and-requests
- Roadmap id: 2026-05-07-00-workflow-kernel-indexing
- Roadmap revision: rev-003
- Roadmap dir: orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-003

### Rationale
Round 015 should run `item-015-indexed-issue-planning-daemon-graph-and-requests` now because the active controller state already points round-015 at this item and the active roadmap marks it as the next pending item after the completed issue-planning daemon-start route. Its only dependency and merge-after requirement is `item-014-indexed-issue-planning-daemon-start`, which the roadmap records as done with round 014 approved and merged. The later pending items depend on this one, and the roadmap marks this item as not parallel-safe with no parallel group, so selecting only this item preserves the roadmap ordering.
