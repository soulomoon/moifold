### Changes Made
- `test/TestSupport/AppServer.hs`: added a narrow endpoint-backed websocket fake app-server that records decoded JSON requests, handles initialize/initialized session traffic, and returns scripted JSON-RPC result or error responses.
- `test/RunnerGuardSpec.hs`: added focused `checkRunnerGuard` active planner-turn coverage for request shape, materialization fallback/stale threshold behavior, active-turn problem mappings, and formatted app-server failure details.
- `test/Main.hs`: wired `runnerGuardActiveTurnInspectionTests` into the existing `watcher-core-test` aggregate near the existing RunnerGuard checks.
- `moifold.cabal`: registered `RunnerGuardSpec` and `TestSupport.AppServer`, and added the test-suite-only `network` and `websockets` dependencies needed by the endpoint fake.

### Tests
- `test/RunnerGuardSpec.hs`: verifies `thread/read` is actually sent to the active planner thread with request id `1` and `includeTurns = True`; verifies materialization-pending fallback records the retry with `includeTurns = False` and only repairs once the event log is stale; verifies `threadSystemError`, missing active turn, failed turn, completed-without-output, blank output, and completed-but-unobserved output map to `LaunchRepairThread` summaries/details; verifies JSON-RPC read failures and parse failures include `formatAppServerClientFailure` text.
- `printf 'RunnerGuardSpec.runnerGuardActiveTurnInspectionTests\n:quit\n' | cabal repl watcher-core-test`: passed; the aggregate returned `True`.
- `cabal test watcher-core-test`: passed.
- `cabal build all`: passed.
- `git diff --check`: passed.
- `git diff --cached --check`: passed.
- `test ! -e orchestrator/rounds/round-111/worker-plan.json`: passed.
- `git diff -- src/CodexWatcher/RunnerGuard.hs src/CodexWatcher/AppServerClient.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs`: passed with an empty diff.

### Notes
No blockers. Production RunnerGuard, AppServerClient facade, app-server client/protocol/transport modules, roadmap files, state, selection, plan, public APIs, fixtures, and docs were not edited by this implementation.
