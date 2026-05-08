### Squash Commit
- Title: Route issue-planning terminal and retry observations through indexed projections
- Summary: Routes the remaining issue-planning ready-issues-fixed, scope-completed, retry, turn-completed, and blocked daemon/fanout observations through the moifold-owned indexed issue-planning adapter while preserving existing daemon transaction surfaces, compatibility writes, dry-run/execute parity, action ordering, request-id behavior, invalid-observation rejection, completion boundaries, golden surfaces, and package boundaries.

### Merge Readiness
- Base branch freshness: confirmed. `git rev-list --left-right --count HEAD...codex/workflow-facade-extraction` reports `0 0`.
- Merge ordering satisfied: yes. This round merges after `item-015-indexed-issue-planning-daemon-graph-and-requests`, which rev-003 records as done and `orchestrator/state.json` records as `last_completed_round` `round-015`.
- Pending dependencies: none. Review decision is approved, and the selected roadmap item only depends on the completed item 015.

### Follow-Up Notes
The next roadmap item is `item-017-indexed-issue-implementation-next-domain-plan`: artifact-only planning for issue-implementation indexed adoption. It should inspect the `IssueImplement` side-effect surface and author the next roadmap revision without starting implementation.
