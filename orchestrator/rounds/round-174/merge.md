### Squash Commit
- Title: Round 174: Migrate indexed issue implement ID imports
- Summary: Round 174 migrates `src/CodexWatcher/Workflow/Moifold/IssueImplement/Indexed.hs` off the `CodexWatcher.Core.Ids` compatibility facade for its existing ID types. The module now imports `ThreadId` and `TurnId` from `CodexWatcher.Workflow.Agent.Ids`, and `BranchName`, `CommitSha`, and `PrNumber` from `CodexWatcher.Workflow.GitHub.Ids`. The change is import-only; indexed workflow exports, types, projections, transitions, behavior, and the public `CodexWatcher.Core.Ids` facade remain unchanged.

### Merge Readiness
- Base branch freshness: confirmed. The round branch is `orchestrator/round-174-highest-value-cleanup-slice`; `codex/workflow-facade-extraction` is an ancestor of the current round head and currently resolves to the same commit.
- Merge ordering satisfied: yes. Controller state is at `stage: merge`, the active round is `round-174`, `merge_ready` is `true`, `pending_merge_rounds` is empty, `merge_after_item_ids` is empty, and `parallel_group` is `null`.
- Pending dependencies: none. `depends_on_round_ids` is empty.

### Follow-Up Notes
Review approved this import-only migration after `cabal build all`, `cabal test watcher-core-test`, and `git diff --check` passed. Remaining `CodexWatcher.Core.Ids` users are intentionally outside this round; this merge does not claim facade removal, deprecation, package exposure cleanup, or milestone completion.
