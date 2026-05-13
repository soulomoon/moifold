### Squash Commit
- Title: Round 184: Migrate healthcheck ID imports
- Summary: Round 184 migrates `src/CodexWatcher/Healthcheck.hs` away from the `CodexWatcher.Core.Ids` compatibility facade by importing agent IDs directly from `CodexWatcher.Workflow.Agent.Ids` and GitHub IDs directly from `CodexWatcher.Workflow.GitHub.Ids`. The approved diff is import-only for Healthcheck and leaves healthcheck behavior, public facade exposure, Cabal exposure, docs, runtime compatibility files, release approval, milestone completion, and terminal completion unchanged.

### Merge Readiness
- Base branch freshness: confirmed. `codex/workflow-facade-extraction` is an ancestor of `HEAD` in the round worktree.
- Merge ordering satisfied: yes. `depends_on_round_ids` is empty and `merge_after_item_ids` is empty.
- Pending dependencies: none.

### Follow-Up Notes
Review status is APPROVED. Remaining `CodexWatcher.Core.Ids` cleanup for domain-loop imports, tests/fixtures, public facade deprecation or removal, Cabal cleanup, docs cleanup, runtime compatibility cleanup, release approval, milestone completion, and terminal completion remains out of scope for this round.
