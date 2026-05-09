### Squash Commit
- Title: Record planning-state compatibility evidence
- Summary: Adds round-local evidence for the current `planning-state.json` compatibility projection and records the durable policy pointer while preserving the `defer` classification. The round documents producer paths, confirms issue-planning healthcheck does not read `planning-state.json`, records the missing checked-in fixture as a blocker, and leaves runtime behavior, schemas, write timing, healthcheck behavior, tests, fixtures, and controller state unchanged.

### Merge Readiness
- Base branch freshness: confirmed; this worktree is on `orchestrator/round-064-planning-state-fixture-policy`, and `codex/workflow-facade-extraction` is the current merge base and an ancestor of HEAD.
- Merge ordering satisfied: yes; `max_parallel_rounds` is 1, this is the active round, `pending_merge_rounds` is empty, and the round declares no `depends_on_round_ids` or `merge_after_item_ids`.
- Pending dependencies: none.

### Follow-Up Notes
Round 064 is approved for squash-merge preparation. Keep the follow-up blockers from the evidence artifact in place for later rounds: no checked-in old/current `planning-state.json` fixture, no external operator/downstream reader inventory, no selected behavior-change round for healthcheck surfacing, and no migration or removal approval.
