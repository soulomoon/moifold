### Squash Commit
- Title: Round 167: Migrate issue planning fanout ID imports
- Summary: This round migrates `src/CodexWatcher/Domain/IssuePlanning/Fanout.hs` away from the combined `CodexWatcher.Core.Ids` compatibility facade and onto the direct ID owner modules for its existing `ThreadId`, `BranchName`, `IssueNumber`, and `RepoName` uses. The approved diff is import-only for the selected production file, preserving issue-planning fanout behavior and leaving public compatibility surfaces exposed for later gated cleanup.

### Merge Readiness
- Base branch freshness: confirmed; base branch is `codex/workflow-facade-extraction`, and parent HEAD `4f9b45a411aab9f68e30d271f3dfdde8d85efb04` is an ancestor of branch `orchestrator/round-167-highest-value-cleanup-slice`.
- Merge ordering satisfied: yes; `pending_merge_rounds` is empty, `depends_on_round_ids` is empty, and no `merge_after_item_ids` are declared.
- Pending dependencies: none.

### Follow-Up Notes
The round is approved and ready for squash merge. This merge does not approve `CodexWatcher.Core.Ids` deprecation, public facade removal, Cabal exposure cleanup, docs cleanup, runtime compatibility cleanup, or terminal milestone completion.
