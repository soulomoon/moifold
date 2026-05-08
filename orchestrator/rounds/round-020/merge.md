### Squash Commit
- Title: Route IssueImplement worker daemon observations through indexed projection
- Summary: This round routes the live `IssueImplementationReady` and `IssueImplementing` daemon observations for implementation-worker behavior through the moifold-owned indexed IssueImplement projection, then projects back into the existing daemon transaction surface. The approved scope covers worker refresh, implementation turn start, incomplete restart, blocked states, and completed implementation observations, with tests proving dry-run and execute parity, request-id behavior, compatibility writes, active-turn handling, and package-boundary preservation. Review handoff, PR merge wait, post-merge review, follow-up, issue close, and child lifecycle paths remain on the compatibility fallback for later roadmap items.

### Merge Readiness
- Base branch freshness: confirmed. `orchestrator/round-020-indexed-issue-implementation-worker-daemon` and `codex/workflow-facade-extraction` both point at `fa28e93` before the round squash, so the round is based on the current local base.
- Merge ordering satisfied: yes. The declared merge-after dependency `item-019-indexed-issue-implementation-plan-and-pr-setup-daemon` is present through commit `9b86b52`, and round 019 is marked complete on base by `fa28e93`.
- Pending dependencies: none.

### Follow-Up Notes
Next round should continue with `item-021-indexed-issue-implementation-handoff-and-merge-wait-daemon`, routing review handoff and PR merge-wait observations through the indexed projection while preserving reviewer-thread reuse, PR merge polling, idle wait behavior, wrong-PR blocking, daemon result shape, compatibility writes, action ordering, and request-id stability.

The reviewer noted a pre-existing modified `orchestrator/state.json`; leave controller state handling to the orchestrator and keep the squash focused on the round implementation and artifacts.
