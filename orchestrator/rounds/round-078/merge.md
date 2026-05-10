### Squash Commit
- Title: Migrate Core.Ids imports to direct owner modules
- Summary: Round `round-078-core-ids-split-import-migration` performs a behavior-neutral internal import migration from `CodexWatcher.Core.Ids` to the direct identifier owner modules for selected single-owner callers. Agent-id-only callers now import `CodexWatcher.Workflow.Agent.Ids`, GitHub-id-only callers now import `CodexWatcher.Workflow.GitHub.Ids`, and remaining combined-facade users are recorded for later keep/defer decisions. The diff is limited to 30 one-line source/test import replacements and leaves the `Core.Ids` facade, owner modules, Cabal files, docs, runtime compatibility, healthcheck, repair, event schemas, public API, and facade-removal surfaces unchanged.

### Merge Readiness
- Base branch freshness: confirmed locally. The configured base branch is `codex/workflow-facade-extraction`; local `HEAD`, the merge-base, and `codex/workflow-facade-extraction` all resolve to `62d76cd644ec9fe9fd789ef04739e4401548d0ea`.
- Merge ordering satisfied: yes. `orchestrator/state.json` has `max_parallel_rounds: 1`, `last_completed_round: round-077`, no `pending_merge_rounds`, and this active round is in `stage: merge` with `merge_ready: true`. The declared `merge_after_item_ids` for rounds 075, 076, and 077 are therefore satisfied by the local orchestrator state.
- Pending dependencies: none locally observable. The active round depends on `round-075`, `round-076`, and `round-077`; local state records `round-077` as the last completed round and no pending merge queue remains.

### Follow-Up Notes
The reviewer approved the round in both `review.md` and `review-record.json`. Validation recorded by review includes the final import scans, `git diff --check`, `git diff --cached --check`, `cabal test watcher-core-test`, and `cabal build all`. This merge note does not stage, commit, merge, or update controller state.
