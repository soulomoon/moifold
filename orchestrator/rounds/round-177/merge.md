### Squash Commit
- Title: Round 177: Migrate event-log replay ID imports
- Summary: This round migrated `src/CodexWatcher/EventLog/Replay.hs` off the `CodexWatcher.Core.Ids` compatibility facade for its existing replay identifiers. `IssueNumber (..)` now imports directly from `CodexWatcher.Workflow.GitHub.Ids`, while `ThreadId (..)` and `TurnId (..)` import directly from `CodexWatcher.Workflow.Agent.Ids`. The reviewed diff is import-only and preserves replay initialization, event application, transition behavior, replay failure text, event JSON shape, old-log parsing behavior, exports, constructors, package exposure, and the public compatibility facade.

### Merge Readiness
- Base branch freshness: confirmed against `codex/workflow-facade-extraction` for this serial round worktree.
- Merge ordering satisfied: yes. `round-177` has no declared `depends_on_round_ids`, no `merge_after_item_ids`, no parallel group, and `max_parallel_rounds` is 1.
- Pending dependencies: none.

### Follow-Up Notes
Validation passed per review: `cabal build all`, focused `cabal test watcher-core-test --test-options='--match "workflow event-log"'`, full `cabal test watcher-core-test`, `git diff --check`, selected-file scans, direct-owner scan, and remaining-user scan. `git diff --cached --check` was skipped because no changes were staged during review.

Remaining `CodexWatcher.Core.Ids` users are outside this round's scope. This approval does not authorize facade deprecation or removal, Cabal exposure cleanup, runtime compatibility cleanup, milestone completion, or terminal roadmap completion.
