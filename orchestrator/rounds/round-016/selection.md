### Selected Item
- Roadmap item: Route issue-planning terminal and retry daemon observations through the indexed adapter
- Item id: item-016-indexed-issue-planning-terminal-and-retry-daemon
- Roadmap id: 2026-05-07-00-workflow-kernel-indexing
- Roadmap revision: rev-003
- Roadmap dir: orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-003

### Rationale
This is the next legal serial item in the active roadmap. The prior issue-planning daemon graph/request slice, `item-015-indexed-issue-planning-daemon-graph-and-requests`, is marked done and recorded as the last completed round in controller state. `item-016-indexed-issue-planning-terminal-and-retry-daemon` depends on and must merge after `item-015`, and no parallel-safe grouping is authorized, so selecting only this item preserves roadmap ordering and keeps the IssuePlanning indexed adoption sequence moving before the later IssueImplementation planning item.
