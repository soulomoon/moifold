### Squash Commit
- Title: Move test app-server endpoint helper to direct transport owner
- Summary: Migrates only `test/TestSupport/AppServer.hs` away from the `CodexWatcher.AppServerClient` compatibility facade for `AppServerEndpoint (..)`, importing the type from `CodexWatcher.Workflow.Agent.Codex.Transport` instead. The endpoint-backed fake app-server helper exports and behavior remain unchanged, and remaining `CodexWatcher.AppServerClient` facade imports are intentionally left for later scoped rounds.

### Merge Readiness
- Base branch freshness: confirmed; local `codex/workflow-facade-extraction` and `HEAD` both resolve to `cd39b1a`, and the base branch is an ancestor of the round branch.
- Merge ordering satisfied: yes; `orchestrator/state.json` has `pending_merge_rounds: []`, `depends_on_round_ids: []`, and `merge_after_item_ids: []` for `round-140`.
- Pending dependencies: none.

### Follow-Up Notes
Review approved the one-line import replacement and recorded passing focused scans, broad facade-import scan, `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and `git diff --cached --check`. This merge does not imply public `CodexWatcher.AppServerClient` facade removal, Cabal exposure cleanup, docs/policy changes, milestone completion, or release approval.
