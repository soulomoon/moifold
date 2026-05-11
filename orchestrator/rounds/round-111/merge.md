### Squash Commit
- Title: Add RunnerGuard active-turn inspection coverage
- Summary: Adds focused watcher-core coverage for `CodexWatcher.RunnerGuard` active app-server turn inspection through a test-only endpoint-backed fake app-server. The round verifies the active `thread/read` request shape, materialization fallback behavior across the stale threshold, active-turn problem mappings, formatted app-server failure details, and wires the new tests into `watcher-core-test` without changing production RunnerGuard, AppServerClient, app-server client, transport, or protocol modules.

### Merge Readiness
- Base branch freshness: confirmed; `codex/workflow-facade-extraction` and round `HEAD` both resolve to `a2274e5`, and the base branch is an ancestor of the round branch.
- Merge ordering satisfied: yes; `pending_merge_rounds` is empty, `depends_on_round_ids` is empty, `merge_after_item_ids` is empty, `parallel_group` is null, and `merge_ready` is true for `round-111`.
- Pending dependencies: none.

### Follow-Up Notes
Review is approved in `review.md`, and `review-record.json` records `"decision": "approved"`. No `orchestrator/rounds/round-111/worker-plan.json` exists.

Changed paths for the implementation are `moifold.cabal`, `test/Main.hs`, `test/RunnerGuardSpec.hs`, and `test/TestSupport/AppServer.hs`, with round control artifacts under `orchestrator/rounds/round-111/` and the controller state update in `orchestrator/state.json`. The production diff guard is empty for `src/CodexWatcher/RunnerGuard.hs`, `src/CodexWatcher/AppServerClient.hs`, and the app-server client/transport/protocol modules.

Reviewer-recorded validation passed: focused `RunnerGuardSpec.runnerGuardActiveTurnInspectionTests` via `cabal repl watcher-core-test`, `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, `git diff --cached --check`, worker-plan absence, and the production diff guard.
