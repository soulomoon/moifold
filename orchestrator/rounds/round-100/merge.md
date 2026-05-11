### Squash Commit
- Title: Move Core.State to direct GitHub ids import
- Summary: Round 100 moves `src/CodexWatcher/Core/State.hs` off the combined `CodexWatcher.Core.Ids` compatibility facade for its GitHub-only identifiers by importing `CommitSha` and `PrNumber` directly from `CodexWatcher.Workflow.GitHub.Ids`. The approved diff is import-only for implementation code, keeps `CompletionEvidence`, `WatcherState`, `SomeWatcherState`, constructors, deriving behavior, package descriptors, and public compatibility facade exposure unchanged, and preserves the remaining facade users for later scoped rounds.

### Merge Readiness
- Base branch freshness: confirmed locally. The round branch `orchestrator/round-100-highest-value-cleanup-slice` and base branch `codex/workflow-facade-extraction` both point at `8856deb1108b4e765de8d6697e9875e90a6d2175` before the round diff, and the base branch is an ancestor of `HEAD`; `origin` has no `codex/workflow-facade-extraction` ref to refresh.
- Merge ordering satisfied: yes. Controller state records `last_completed_round` as `round-099`, `pending_merge_rounds` as empty, serial `max_parallel_rounds: 1`, and active `round-100` at merge stage. The selection declares no `merge_after_item_ids`.
- Pending dependencies: none. The selection and controller state both declare empty `depends_on_round_ids`; review approved the round and verified `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and `git diff --cached --check`.

### Follow-Up Notes
After squash merge, the controller should update the roadmap for `round-100-core-state-github-ids-import-convergence` under direction `direction-011-core-ids-import-convergence`. This round does not complete deprecation, migration, facade removal, Cabal exposure removal, release approval, milestone completion, or terminal completion; remaining `CodexWatcher.Core.Ids` users are intentionally left for later slices.
