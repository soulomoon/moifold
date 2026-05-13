### Squash Commit
- Title: Round 180: Migrate CLI types ID imports
- Summary: This round migrates `src/CodexWatcher/Cli/Types.hs` away from the `CodexWatcher.Core.Ids` compatibility facade and onto the direct ID owner modules, using `CodexWatcher.Workflow.Agent.Ids` for `ThreadId` and `TurnId` and `CodexWatcher.Workflow.GitHub.Ids` for the GitHub IDs used by the CLI type surface. The reviewed diff is import-only and preserves CLI constructors, fields, derived instances, parser/rendering behavior, dry-run behavior, fanout-adjacent plumbing, package descriptors, docs, runtime compatibility files, and the public `CodexWatcher.Core.Ids` facade.

### Merge Readiness
- Base branch freshness: confirmed. `codex/workflow-facade-extraction` is an ancestor of `HEAD` in the round worktree.
- Merge ordering satisfied: yes. `depends_on_round_ids` is empty and `merge_after_item_ids` is empty.
- Pending dependencies: none.

### Follow-Up Notes
Review decision is approved for `round-180-cli-types-core-ids-split-import-migration`. Validation recorded in review includes `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, selected-file absence of `CodexWatcher.Core.Ids`, direct-owner import scans, and broad remaining-user classification. This merge readiness note is limited to the round-180 import-only migration and does not approve public facade deprecation/removal, Cabal cleanup, docs cleanup, runtime compatibility cleanup, release approval, milestone completion, or terminal completion.
