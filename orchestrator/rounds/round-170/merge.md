### Squash Commit
- Title: Round 170: Migrate issue implement watcher ID imports
- Summary: This round migrates `src/CodexWatcher/Domain/IssueImplement/Watcher.hs` away from the `CodexWatcher.Core.Ids` compatibility facade and onto direct owner imports from `CodexWatcher.Workflow.GitHub.Ids` for `BranchName`, `CommitSha`, and `PrNumber`, and `CodexWatcher.Workflow.Agent.Ids` for `ThreadId` and `TurnId`. The reviewed production change is import-only and preserves issue-implementation observation, event construction, state-transition behavior, package exposure, and public compatibility facade availability.

### Merge Readiness
- Base branch freshness: confirmed; round branch `orchestrator/round-170-highest-value-cleanup-slice` is at `3de30b4d72634abd0d2b20dc5addacf57d010048`, matching base branch `codex/workflow-facade-extraction`, and the declared parent HEAD `3de30b4d72634abd0d2b20dc5addacf57d010048` is an ancestor.
- Merge ordering satisfied: yes; no `pending_merge_rounds` are present, `merge_after_item_ids` is empty, and no parallel batch is declared.
- Pending dependencies: none; `depends_on_round_ids` is empty and `merge_ready` is true.

### Follow-Up Notes
Review approved the round with passing focused scans, package exposure scan, `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, and `git diff --cached --check`. This merge does not approve broader `CodexWatcher.Core.Ids` migration, public facade removal, deprecation, Cabal exposure cleanup, milestone completion, terminal cleanup completion, or release/publication gates.
