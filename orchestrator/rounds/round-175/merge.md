### Squash Commit
- Title: Round 175: Migrate effect interpreter ID imports
- Summary: Round 175 migrates `src/CodexWatcher/EffectInterpreter.hs` away from the `CodexWatcher.Core.Ids` compatibility facade for its existing ID imports. The module now imports `RequestId`, `ThreadId`, and `nextRequestId` from `CodexWatcher.Workflow.Agent.Ids`, and `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, and `RepoName` from `CodexWatcher.Workflow.GitHub.Ids`. The reviewed change is import-only; effect planning, runtime configuration, request-id progression, rendered turn input selection, exports, behavior, and the public `CodexWatcher.Core.Ids` facade remain unchanged.

### Merge Readiness
- Base branch freshness: confirmed. The round branch is `orchestrator/round-175-highest-value-cleanup-slice`; `codex/workflow-facade-extraction` is an ancestor of the current round head, and both currently resolve to `7cd8575279dafb3755b1bb3400afc1a2883c87e8` before the round diff.
- Merge ordering satisfied: yes. Controller state is at `stage: merge`, the active round is `round-175`, `merge_ready` is `true`, `pending_merge_rounds` is empty, `merge_after_item_ids` is empty, and `parallel_group` is `null`.
- Pending dependencies: none. `depends_on_round_ids` is empty.

### Follow-Up Notes
Review decision is approved. Verification recorded passing `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, focused no-`Core.Ids` scan for `EffectInterpreter.hs`, and broad remaining-user scan. Remaining `CodexWatcher.Core.Ids` users are expected outside this slice; this merge does not claim facade removal, deprecation, Cabal exposure cleanup, runtime compatibility cleanup, milestone completion, terminal cleanup completion, or release approval.
