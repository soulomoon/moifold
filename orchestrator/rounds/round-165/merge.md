### Squash Commit
- Title: Migrate PR review loop ID imports to owner modules
- Summary: This round migrates `src/CodexWatcher/Domain/PrReview/Loop.hs` off the `CodexWatcher.Core.Ids` compatibility facade by importing `ThreadId` from `CodexWatcher.Workflow.Agent.Ids` and `CommitSha` / `PrNumber (..)` from `CodexWatcher.Workflow.GitHub.Ids`. The approved diff is import-only for the selected production file and preserves the existing PR-review loop behavior and text.

### Merge Readiness
- Base branch freshness: confirmed. Local round branch `orchestrator/round-165-highest-value-cleanup-slice` and local base branch `codex/workflow-facade-extraction` both resolve to `ed1368ab815e8969bfc31f2846c5877d7701804f`; the round diff is unstaged on top of that shared head.
- Merge ordering satisfied: yes. `merge_after_item_ids` is empty, `depends_on_round_ids` is empty, `pending_merge_rounds` is empty, and `max_parallel_rounds` is 1, so there is no earlier local round ordering blocker.
- Pending dependencies: none.

### Follow-Up Notes
`review.md` and `review-record.json` explicitly approve the round. The controller can squash this round when ready; no implementation, roadmap, state, staging, commit, or merge action was performed by the merger.
