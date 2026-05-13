### Squash Commit
- Title: Round 183: Migrate runtime compatibility ID imports
- Summary: This round migrates only `src/CodexWatcher/Runtime/Compatibility.hs` away from the `CodexWatcher.Core.Ids` compatibility facade. The approved diff is import-only and replaces the facade import with direct owner imports from `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`; runtime compatibility behavior, JSON shapes, file names, write timing, repair behavior, healthcheck behavior, runtime state semantics, event schemas, replay, Cabal, docs, tests, and public facade exposure are unchanged.

### Merge Readiness
- Base branch freshness: confirmed. `codex/workflow-facade-extraction` is an ancestor of `HEAD` in this round worktree; both resolve to `26cc3f6`.
- Merge ordering satisfied: yes. `depends_on_round_ids` is empty and `merge_after_item_ids` is empty for `round-183-runtime-compatibility-core-ids-import-migration-or-classification`.
- Pending dependencies: none.
- Review status: approved. `review.md` records `APPROVED`, and `review-record.json` records `"decision": "approved"`.
- Approved diff scope: only `src/CodexWatcher/Runtime/Compatibility.hs` changes, and the source diff only removes `CodexWatcher.Core.Ids` while adding direct imports for `ThreadId`, `TurnId`, `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, `RepoName`, and `ReviewThreadId`.
- Readiness decision: ready for squash merge with title `Round 183: Migrate runtime compatibility ID imports`.

### Follow-Up Notes
Public facade deprecation or removal, Cabal cleanup, docs cleanup, runtime compatibility file cleanup, release approval, milestone completion, and terminal completion remain out of scope. Remaining `CodexWatcher.Core.Ids` users outside the selected file should be handled by later selected rounds or classification work.
