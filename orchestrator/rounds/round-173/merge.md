### Squash Commit
- Title: Round 173: Migrate effects ID imports
- Summary: Migrates `src/CodexWatcher/Effects.hs` from the `CodexWatcher.Core.Ids` compatibility facade to direct owner imports for its existing ID types. `ThreadId` now comes from `CodexWatcher.Workflow.Agent.Ids`, while `BranchName`, `CommitSha`, `PrNumber`, `RepoName`, and `ReviewThreadId` come from `CodexWatcher.Workflow.GitHub.Ids`; constructors, function bodies, exported API shape, behavior, tests, Cabal exposure, and the public `CodexWatcher.Core.Ids` facade remain unchanged.

### Merge Readiness
- Base branch freshness: confirmed. Round branch `orchestrator/round-173-highest-value-cleanup-slice` is based on `codex/workflow-facade-extraction`.
- Merge ordering satisfied: yes. State is at `stage: merge`, review decision is approved, `merge_ready` is true, `pending_merge_rounds` is empty, and there is no declared parallel group.
- Pending dependencies: none. `depends_on_round_ids` and `merge_after_item_ids` are empty.

### Follow-Up Notes
Remaining `CodexWatcher.Core.Ids` users are expected outside this slice, and the public facade remains exposed. This merge note does not claim facade removal, deprecation, Cabal exposed-module cleanup, runtime compatibility cleanup, behavior change, milestone completion, or release approval.
