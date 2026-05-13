### Squash Commit
- Title: Round 181: Migrate IssueFanout ID imports
- Summary: Round 181 is approved for the import-only migration of `src/CodexWatcher/Cli/Command/IssueFanout.hs` away from the `CodexWatcher.Core.Ids` compatibility facade to direct owner imports from `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`. Fanout behavior, public facade exposure, Cabal metadata, docs, runtime compatibility files, and broader cleanup surfaces remain unchanged and out of scope.

### Merge Readiness
- Base branch freshness: confirmed; `codex/workflow-facade-extraction` is an ancestor of `HEAD` in this round worktree.
- Merge ordering satisfied: yes; `depends_on_round_ids` is empty and `merge_after_item_ids` is empty.
- Pending dependencies: none.

### Follow-Up Notes
Review status is `APPROVED`. The approved implementation diff is limited to `src/CodexWatcher/Cli/Command/IssueFanout.hs`, replacing the old `CodexWatcher.Core.Ids` import with direct `RequestId`/`ThreadId` imports from `CodexWatcher.Workflow.Agent.Ids` and `BranchName`/`IssueNumber`/`RepoName` imports from `CodexWatcher.Workflow.GitHub.Ids`.

Public facade deprecation or removal, Cabal cleanup, docs cleanup, runtime compatibility cleanup, release approval, milestone completion, and terminal completion are not approved by this round.
