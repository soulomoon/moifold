### Selected Item
- Roadmap item: Harden IssueImplement lifecycle, repair, and child ownership after full indexed routing
- Item id: item-024-indexed-issue-implementation-lifecycle-hardening
- Roadmap id: 2026-05-07-00-workflow-kernel-indexing
- Roadmap revision: rev-004
- Roadmap dir: orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-004

### Rationale
Round 024 should run item 024 now because the active controller state is at `select-task` for `item-024-indexed-issue-implementation-lifecycle-hardening`, and `rev-004` marks all prior IssueImplement indexed routing slices through issue close as done. The item depends on and must merge after `item-023-indexed-issue-implementation-close-daemon`; round 023's review and merge artifacts record approval, passing verification, and no pending dependencies.

This is the next legal narrow follow-up after full live IssueImplement daemon routing. The work should stay focused on lifecycle hardening surfaces that still depend on terminal and compatibility behavior: child launch manifests, runtime status, healthcheck, repair commands, stale or completed child detection, dry-run launch output, and compatibility facade availability, while preserving moifold ownership of child lifecycle, state files, events, repair behavior, and fanout boundaries.
