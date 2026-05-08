### Squash Commit
- Title: Route active issue-planning graph and request observations through indexed adapter
- Summary: This round routes active-turn `ObservedPlanningIssuesRequested` and normalized `ObservedPlanningGraphUpdated` daemon observations through the moifold-owned indexed issue-planning projection, then projects the result back onto the existing daemon transaction surface. It preserves issue creation plans, graph recording, compatibility writes, dry-run and execute parity, request-id behavior, invalid-observation failures, and keeps terminal/retry observations on the existing compatibility route.

### Merge Readiness
- Base branch freshness: confirmed. `git rev-list --left-right --count HEAD...codex/workflow-facade-extraction` reports `0 0`.
- Merge ordering satisfied: yes. The required merge-after item is `item-014-indexed-issue-planning-daemon-start`, which `rev-003` records as done and `orchestrator/state.json` records as `last_completed_round` `round-014`.
- Pending dependencies: none for this round. The review decision is approved and no additional round dependency is pending before squash merge.

### Follow-Up Notes
Item 016 still owns routing for retry, blocked, scope-complete, ready-issues-fixed, and completed issue-planning daemon observations. This round intentionally leaves those terminal/retry paths on compatibility routing.
