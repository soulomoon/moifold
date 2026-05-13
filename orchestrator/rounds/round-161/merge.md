### Squash Commit
- Title: Migrate PR review watcher ID imports
- Summary: This round migrates `src/CodexWatcher/Domain/PrReview/Watcher.hs` from the combined `CodexWatcher.Core.Ids` compatibility facade to the direct ID owner modules for `TurnId`, `CommitSha`, and `ReviewThreadId`. The production diff is import-only, preserves PR-review watcher behavior, and was approved with `cabal build all`, `cabal test watcher-core-test`, diff hygiene, and focused import scans passing.

### Merge Readiness
- Base branch freshness: confirmed. The round branch `orchestrator/round-161-highest-value-cleanup-slice` is based on `codex/workflow-facade-extraction`; local `HEAD`, base branch, and merge-base are all `b7098567f44cc65b463f221349fc529f4a41f6a8`.
- Merge ordering satisfied: yes. Review decision is `APPROVED`, `merge_ready` is true, `pending_merge_rounds` is empty, and round 161 declares no `depends_on_round_ids`, `merge_after_item_ids`, or `parallel_group`.
- Pending dependencies: none.

### Follow-Up Notes
`CodexWatcher.Core.Ids` remains present and exposed. This round does not approve facade deprecation, public compatibility removal, Cabal exposure cleanup, runtime compatibility cleanup, milestone completion, terminal completion, release, or package publication. Remaining `CodexWatcher.Core.Ids` imports are intentionally left for later selected rounds.
