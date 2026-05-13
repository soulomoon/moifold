### Squash Commit
- Title: Round 176: Migrate state machine ID imports
- Summary: Migrates `src/CodexWatcher/StateMachine.hs` away from the `CodexWatcher.Core.Ids` compatibility facade by importing `ThreadId` from `CodexWatcher.Workflow.Agent.Ids` and the GitHub-owned identifiers from `CodexWatcher.Workflow.GitHub.Ids`. This round is import-only and preserves state-machine behavior, exports, constructors, validation, branch parsing/rendering, PR mismatch handling, review-thread resolution, package exposure, and public compatibility facade availability.

### Merge Readiness
- Base branch freshness: confirmed against base branch `codex/workflow-facade-extraction`.
- Merge ordering satisfied: yes. Round `round-176` has no declared `depends_on_round_ids`, no `merge_after_item_ids`, no parallel group, and `max_parallel_rounds` is 1.
- Pending dependencies: none.

### Follow-Up Notes
Review approved this round with `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, the focused selected-file scan, and the broad remaining-user scan passing. `git diff --cached --check` was skipped because there were no staged changes.

Remaining `CodexWatcher.Core.Ids` users are outside this round's scope. This merge note does not approve facade deprecation or removal, Cabal exposure cleanup, runtime compatibility cleanup, milestone completion, or broader roadmap completion.
