### Selected Item
- Roadmap item: Route IssueImplement review handoff and PR merge-wait daemon observations through indexed projection
- Item id: item-021-indexed-issue-implementation-handoff-and-merge-wait-daemon
- Roadmap id: 2026-05-07-00-workflow-kernel-indexing
- Roadmap revision: rev-004
- Roadmap dir: orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-004

### Rationale
Controller state is at `select-task` for round 021 and already names `item-021-indexed-issue-implementation-handoff-and-merge-wait-daemon` on branch `orchestrator/round-021-indexed-issue-implementation-handoff-and-merge-wait-daemon`. The active roadmap marks round 020's prerequisite item, `item-020-indexed-issue-implementation-worker-daemon`, done and records it as approved and merged in commit `78e3100`; `orchestrator/state.json` also records `last_completed_round` as `round-020` and this round's dependency as `round-020`.

This makes item 021 the next legal non-parallel item: its `Depends on` and `Merge after` constraints both point to completed item 020, while item 022 depends on item 021 and must wait. The planner should keep the scope to review handoff, reviewer-thread readiness, and PR merge-wait daemon observations through the indexed IssueImplement projection, leaving post-merge reviewer start/outcomes, issue close, and follow-up routing for later roadmap items.
