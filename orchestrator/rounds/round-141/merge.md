### Squash Commit
- Title: Move IssueFanout app-server endpoint test to direct transport owner
- Summary: This round migrates only `test/IssueFanoutAppServerSpec.hs` from the `CodexWatcher.AppServerClient` compatibility facade import for `AppServerEndpoint (..)` to the direct owner import `CodexWatcher.Workflow.Agent.Codex.Transport (AppServerEndpoint (..))`. Existing issue-fanout app-server assertions, helper behavior, failure formatting, and public compatibility facade surfaces remain unchanged.

### Merge Readiness
- Base branch freshness: confirmed. The worktree branch `orchestrator/round-141-highest-value-cleanup-slice`, `HEAD`, and base branch `codex/workflow-facade-extraction` all point at `0230ecf7e152f0e45e3278153805f27adca72e7a` before applying the uncommitted round diff.
- Merge ordering satisfied: yes. Scheduler fields show `depends_on_round_ids: []`, `merge_after_item_ids: []`, `parallel_group: null`, `pending_merge_rounds: []`, and `merge_ready: true`; the round is serial under `max_parallel_rounds: 1`.
- Pending dependencies: none.

### Follow-Up Notes
The approved review records `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, `git diff --cached --check`, focused selected-file scans, and the broad `CodexWatcher.AppServerClient` scan as passing. Remaining `CodexWatcher.AppServerClient` references are intentionally out of scope for this round and should be handled by later exact selections. This merge note does not approve public facade deprecation, facade removal, Cabal exposure cleanup, milestone completion, package publication, or release approval.
