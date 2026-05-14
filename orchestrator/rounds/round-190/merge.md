### Squash Commit
- Title: Round 190: Migrate workflow execution spec ID imports
- Summary: This round migrates `test/WorkflowExecutionSpec.hs` away from the `CodexWatcher.Core.Ids` compatibility facade and onto the direct Agent and GitHub id-owner imports. The approved diff is import-only for the selected spec, preserves workflow execution behavior and assertions, and leaves the remaining `Core.Ids` users classified for later rounds.

### Merge Readiness
- Base branch freshness: confirmed against the local `codex/workflow-facade-extraction` base head `006608d6`. The round branch `orchestrator/round-190-highest-value-cleanup-slice` is also at `006608d6` before its uncommitted round diff. No `origin/codex/workflow-facade-extraction` ref is present in this checkout, so remote base freshness was not observable.
- Merge ordering satisfied: yes. `selection.md` declares no `merge_after_item_ids`, no `parallel_group`, and the active state records `merge_ready: true` after reviewer approval.
- Pending dependencies: none. `selection.md` declares `depends_on_round_ids: []`, and the scheduler context is serial with no concurrent batch.

### Follow-Up Notes
Reviewer approval is recorded in `review.md` and `review-record.json`. Remaining `CodexWatcher.Core.Ids` users are intentionally out of scope for this round and should be handled by later selected items; this merge should not be treated as public facade removal, Cabal exposure removal, or milestone completion approval.
