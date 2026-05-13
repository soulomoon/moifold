### Squash Commit
- Title: Round 182: Migrate EventLog.Types ID imports
- Summary: This approved round migrates only `src/CodexWatcher/EventLog/Types.hs` away from the `CodexWatcher.Core.Ids` compatibility facade by importing `ThreadId` and `TurnId` directly from `CodexWatcher.Workflow.Agent.Ids`, and `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, `RepoName`, and `ReviewThreadId` directly from `CodexWatcher.Workflow.GitHub.Ids`. The approved diff is import-only and preserves event constructors, codecs, schema/version behavior, fixtures, runtime compatibility files, healthcheck behavior, public facade exposure, Cabal exposure, docs, and roadmap artifacts.

### Merge Readiness
- Base branch freshness: confirmed; `codex/workflow-facade-extraction` is an ancestor of `HEAD` in the round worktree.
- Merge ordering satisfied: yes; `depends_on_round_ids` is empty and `merge_after_item_ids` is empty.
- Pending dependencies: none.

### Follow-Up Notes
Review decision is `APPROVED`. Public facade deprecation/removal, Cabal cleanup, docs cleanup, runtime compatibility cleanup, release approval, milestone completion, and terminal completion remain out of scope for this squash merge.
