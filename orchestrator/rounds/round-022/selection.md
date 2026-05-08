### Selected Item
- Roadmap item: Route IssueImplement post-merge review and follow-up daemon observations through indexed projection
- Item id: item-022-indexed-issue-implementation-post-merge-review-daemon
- Roadmap id: 2026-05-07-00-workflow-kernel-indexing
- Roadmap revision: rev-004
- Roadmap dir: orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-004

### Rationale
Controller state is at `select-task` for round 022 and names `item-022-indexed-issue-implementation-post-merge-review-daemon` on branch `orchestrator/round-022-indexed-issue-implementation-post-merge-review-daemon`. The active roadmap marks item 021 done with completion notes for commit `758cfe4`, and the round branch is at base commit `a48cb7d`, which records round 021 complete.

This makes item 022 the next legal non-parallel item: its `Depends on` and `Merge after` constraints both point to completed item 021, while item 023 depends on item 022 and must wait. The planner should keep scope to post-merge reviewer thread creation, final-review turn start and classification, clean/rework/incomplete/blocked outcomes, and follow-up routing through the indexed IssueImplement projection, leaving terminal issue close for the next roadmap item.
