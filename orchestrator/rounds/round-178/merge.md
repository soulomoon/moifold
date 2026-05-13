### Squash Commit
- Title: Round 178: Migrate GoldenReplay ID imports
- Summary: Migrates `src/CodexWatcher/GoldenReplay.hs` from the `CodexWatcher.Core.Ids` compatibility facade to the direct owner modules for agent and GitHub identifiers. The approved diff is import-only: `ThreadId` and `TurnId` now come from `CodexWatcher.Workflow.Agent.Ids`, while `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, and `RepoName` now come from `CodexWatcher.Workflow.GitHub.Ids`; replay logic, bootstrap behavior, fixtures, public facade exposure, Cabal files, docs, and runtime compatibility surfaces remain unchanged.

### Merge Readiness
- Base branch freshness: confirmed. The canonical round branch is `orchestrator/round-178-highest-value-cleanup-slice`, and local `codex/workflow-facade-extraction` is an ancestor of `HEAD`.
- Merge ordering satisfied: yes. `depends_on_round_ids` is empty and `merge_after_item_ids` is empty for `round-178-golden-replay-core-ids-split-import-migration`.
- Pending dependencies: none.

### Follow-Up Notes
Round 178 is ready for squash merge as the approved import-only migration. This approval does not approve public facade removal, Cabal exposure cleanup, docs cleanup, runtime compatibility cleanup, release, milestone completion, roadmap terminal completion, or any changes outside `src/CodexWatcher/GoldenReplay.hs` import ownership.
