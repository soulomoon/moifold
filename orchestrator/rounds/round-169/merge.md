### Squash Commit
- Title: Round 169: Migrate daemon loop type ID imports
- Summary: This round migrates `src/CodexWatcher/DaemonLoop/Types.hs` off the combined `CodexWatcher.Core.Ids` compatibility facade and onto the direct owner modules for its existing GitHub and agent identifiers. The approved implementation is import-only: `CommitSha` and `PrNumber` now come from `CodexWatcher.Workflow.GitHub.Ids`, while `ThreadId` and `TurnId (..)` now come from `CodexWatcher.Workflow.Agent.Ids`; daemon-loop type definitions, constructors, helpers, exports, public compatibility facades, package descriptors, docs, tests, and runtime behavior remain unchanged.

### Merge Readiness
- Base branch freshness: confirmed. Base branch is `codex/workflow-facade-extraction`; parent/base HEAD `32d6c5f16d62834bbcef0be6189b802d4c06ff0e` is an ancestor of this round branch, and the branch currently resolves to that base commit plus the approved working-tree round diff.
- Merge ordering satisfied: yes. The round declares no `merge_after_item_ids`, no `depends_on_round_ids`, no `parallel_group`, and `max_parallel_rounds` is `1`; there are no pending merge-order blockers for this selected item.
- Pending dependencies: none.

### Follow-Up Notes
Review approved this one-file import-only migration and `review-record.json` records `decision: approved`. The reviewer evidence passed the baseline gates (`cabal build all`, `cabal test watcher-core-test`, `git diff --check`, and `git diff --cached --check`) plus focused scans proving `src/CodexWatcher/DaemonLoop/Types.hs` no longer imports `CodexWatcher.Core.Ids` and the direct owner modules are exposed. This merge does not approve public facade removal, Cabal exposed-module cleanup, broader `Core.Ids` migration, compatibility deprecation, runtime compatibility cleanup, milestone completion, or release/publication.
