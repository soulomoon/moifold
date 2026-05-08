### Selected Item
- Roadmap item: Route IssueImplement plan-mode and PR setup daemon observations through indexed projection
- Item id: item-019-indexed-issue-implementation-plan-and-pr-setup-daemon
- Roadmap id: 2026-05-07-00-workflow-kernel-indexing
- Roadmap revision: rev-004
- Roadmap dir: orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-004

### Rationale
Select item 019 for round 019. The controller is at `select-task` for this exact item, with `round-019` active on branch `orchestrator/round-019-indexed-issue-implementation-plan-and-pr-setup-daemon`. Its only declared dependency and merge-after item is `item-018-indexed-issue-implementation-policy`; the active roadmap marks item 018 done, `state.json` records `last_completed_round` as `round-018`, and round 018's merge record reports no pending dependencies. The roadmap does not authorize parallel execution for item 019, so this round should run only the plan-mode and PR setup daemon routing slice before later implementation-turn daemon work.
