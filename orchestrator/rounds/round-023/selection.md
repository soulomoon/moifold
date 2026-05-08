### Selected Item
- Roadmap item: Route IssueImplement issue-close terminal daemon observations through indexed projection
- Item id: item-023-indexed-issue-implementation-close-daemon
- Roadmap id: 2026-05-07-00-workflow-kernel-indexing
- Roadmap revision: rev-004
- Roadmap dir: orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-004

### Rationale
Round 023 should run item 023 now because the active controller state is at `select-task` for `item-023-indexed-issue-implementation-close-daemon`, and `rev-004` marks the prior IssueImplement post-merge review slice as done. The item depends on and must merge after `item-022-indexed-issue-implementation-post-merge-review-daemon`; round 022's review and merge artifacts record that item 022 was approved and merged, leaving issue-close terminal routing as the next narrow pending IssueImplement slice.

This keeps the adoption order repository-specific and bounded: route issue close polling and `ObservedIssueClosed` through the indexed projection while preserving the existing close command semantics, retry sleep behavior, wrong-PR rejection, terminal `IssueComplete` evidence, `StopDaemon`, compatibility writes, daemon result shape, and dry-run rendering.
