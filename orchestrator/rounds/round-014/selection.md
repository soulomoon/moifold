### Selected Item
- Roadmap item: Route live issue-planning daemon start through the indexed adapter
- Item id: item-014-indexed-issue-planning-daemon-start
- Roadmap id: 2026-05-07-00-workflow-kernel-indexing
- Roadmap revision: rev-003
- Roadmap dir: orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-003

### Rationale
`item-014-indexed-issue-planning-daemon-start` is the next legal roadmap item for round 014. The active controller state already targets this item, and the active rev-003 roadmap marks `item-013-indexed-issue-planning-policy` as done while `item-014-indexed-issue-planning-daemon-start` remains the first pending item.

The selected item depends on and must merge after `item-013-indexed-issue-planning-policy`, which is complete in the roadmap and recorded as the last completed round in state. Later pending items depend sequentially on this one, and the roadmap marks this item as not parallel safe, so this round should select only the daemon-start slice.
