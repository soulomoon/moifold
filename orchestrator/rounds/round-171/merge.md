### Squash Commit
- Title: Round 171: Migrate moifold PR review ID imports
- Summary: This round migrates `src/CodexWatcher/Workflow/Moifold/PrReview.hs` away from the `CodexWatcher.Core.Ids` compatibility facade and onto direct owner imports from `CodexWatcher.Workflow.GitHub.Ids` for `CommitSha` and `ReviewThreadId (..)`, and `CodexWatcher.Workflow.Agent.Ids` for `ThreadId` and `TurnId`. The reviewed production change is import-only and preserves PR-review observation handling, unresolved-review-thread evidence, summaries, event construction, package exposure, and public compatibility facade availability.

### Merge Readiness
- Base branch freshness: confirmed; round branch `orchestrator/round-171-highest-value-cleanup-slice` and base branch `codex/workflow-facade-extraction` both resolve to `0e51a393d19f58d1e4b81b814c2197d52fcdf763`, and the declared parent HEAD is an ancestor.
- Merge ordering satisfied: yes; no `pending_merge_rounds` are present in state, `depends_on_round_ids` is empty, `merge_after_item_ids` is empty, and no parallel batch is declared.
- Pending dependencies: none; `review-record.json` records `decision: approved` and state records `merge_ready: true`.

### Follow-Up Notes
Review approved the round with passing focused scans, package exposure scan, `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, and `git diff --cached --check`. This merge does not approve broader `CodexWatcher.Core.Ids` migration, public facade removal, deprecation, Cabal exposure cleanup, compatibility-file migration, milestone completion, terminal cleanup completion, or release/publication gates.
