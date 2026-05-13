### Squash Commit
- Title: Migrate AutomaticLoopRunnerSpec to direct id owner imports
- Summary: This round migrates `test/AutomaticLoopRunnerSpec.hs` away from the combined `CodexWatcher.Core.Ids` compatibility facade by importing `RepoName` from `CodexWatcher.Workflow.GitHub.Ids` and `ThreadId` / `unThreadId` from `CodexWatcher.Workflow.Agent.Ids`. The reviewed diff is import-only for the selected test file, preserves the automatic-loop runner assertions, and keeps `CodexWatcher.Core.Ids` available and exposed.

### Merge Readiness
- Base branch freshness: confirmed. `orchestrator/round-154-highest-value-cleanup-slice` is based on `codex/workflow-facade-extraction` at `964fd144c5ee3d76d935e7940dd9ca7ea1f760a7`; `codex/workflow-facade-extraction` is an ancestor of the round branch HEAD.
- Merge ordering satisfied: yes. `orchestrator/state.json` has `max_parallel_rounds: 1`, `active_round_id: round-154`, no `pending_merge_rounds`, `merge_ready: true`, and no `merge_after_item_ids`; selection records no concurrent batch context and serial execution after round 153.
- Pending dependencies: none. `depends_on_round_ids` is empty, `merge_after_item_ids` is empty, and review decision is approved in both `review.md` and `review-record.json`.

### Follow-Up Notes
This round is eligible for squash merge into `codex/workflow-facade-extraction`. It is only a preferred-import convergence slice for `test/AutomaticLoopRunnerSpec.hs`; it does not approve broader `Core.Ids` migration, public facade deprecation or removal, Cabal exposure cleanup, runtime compatibility cleanup, release approval, or milestone completion.
