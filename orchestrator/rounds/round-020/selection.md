### Selected Item
- Roadmap item: Route IssueImplement implementation-turn daemon observations through indexed projection
- Item id: item-020-indexed-issue-implementation-worker-daemon
- Roadmap id: 2026-05-07-00-workflow-kernel-indexing
- Roadmap revision: rev-004
- Roadmap dir: orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-004

### Rationale
Round 020 should run `item-020-indexed-issue-implementation-worker-daemon` now because `orchestrator/state.json` records the controller at `select-task` for that item, and `rev-004` shows it as the first pending IssueImplement adoption slice after the completed plan-mode and PR setup routing.

The item's only dependency and merge-after requirement is `item-019-indexed-issue-implementation-plan-and-pr-setup-daemon`. Round 019 is the last completed round in controller state, and its review and merge artifacts record approval, merge readiness, and no pending dependencies. This makes the implementation-turn daemon route the next legal non-parallel item. The round should stay limited to live `IssueImplementationReady` and `IssueImplementing` implementation-turn observations, preserving review handoff, PR merge wait, post-merge review, follow-up, issue close, and child lifecycle routing for later roadmap items.
