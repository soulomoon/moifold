### Squash Commit
- Title: Round 172: Migrate runner guard ID imports
- Summary: Migrates `src/CodexWatcher/RunnerGuard.hs` away from the `CodexWatcher.Core.Ids` compatibility facade by importing `RequestId`, `ThreadId`, and `TurnId` from `CodexWatcher.Workflow.Agent.Ids` and `RepoName` from `CodexWatcher.Workflow.GitHub.Ids`. The change is import-only; runner-guard behavior, app-server request sequencing, JSON fields, replay handling, prompts, tests, Cabal exposure, docs, runtime compatibility files, and the public `CodexWatcher.Core.Ids` facade remain unchanged.

### Merge Readiness
- Base branch freshness: confirmed; `codex/workflow-facade-extraction` is an ancestor of `orchestrator/round-172-highest-value-cleanup-slice`, and both currently resolve to `a722ca13a271b6259f238b80f4250356b6ce0671` before the round diff.
- Merge ordering satisfied: yes; `pending_merge_rounds` is empty, `depends_on_round_ids` is empty, `merge_after_item_ids` is empty, and `parallel_group` is null.
- Pending dependencies: none.

### Follow-Up Notes
Review decision is APPROVED and state marks `round-172` at `stage: merge` with `merge_ready: true`. Remaining `CodexWatcher.Core.Ids` users are intentionally outside this round; this merge should not be treated as facade deprecation, public surface removal, milestone completion, or terminal cleanup.
