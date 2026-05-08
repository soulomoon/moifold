### Squash Commit
- Title: Route issue-planning daemon start through indexed adapter
- Summary: Route the live `PlanningReady` plus `ObservedPlanningTurnStarted` daemon observation through the moifold-owned indexed issue-planning projection, then project the transition back to the existing daemon transaction surfaces. The round preserves planner thread creation, planner turn start, request-id progression, dry-run and execute reports, action ordering, compatibility writes, snapshot paths, invalid-observation failures, and package-boundary coverage while keeping all other issue-planning daemon observations on the compatibility path.

### Merge Readiness
- Base branch freshness: confirmed. `HEAD...codex/workflow-facade-extraction` reports `0 0`, so the round branch is neither ahead nor behind the base branch at merge-prep time.
- Merge ordering satisfied: yes. The only merge-after item is `item-013-indexed-issue-planning-policy`; roadmap rev-003 marks it done, and `orchestrator/state.json` records `last_completed_round` as `round-013`.
- Pending dependencies: none. The round has no `depends_on_round_ids`, no pending merge rounds are recorded, and review decision is approved.

### Follow-Up Notes
Graph/request daemon routing remains for `item-015-indexed-issue-planning-daemon-graph-and-requests`.

Terminal and retry daemon routing remains for `item-016-indexed-issue-planning-terminal-and-retry-daemon`, including blocked, scope-complete, ready-issues-fixed, completed, and retry observations.
