### Goal

Add focused `watcher-core-test` coverage for `CodexWatcher.RunnerGuard` active
app-server turn inspection before any later `RunnerGuard.hs`
`CodexWatcher.AppServerClient` import migration is selected.

This round should prove the current active-turn behavior through
`checkRunnerGuard`; it must not change `src/CodexWatcher/RunnerGuard.hs`,
production app-server protocol/client behavior, public facade imports, docs,
roadmaps, or runtime compatibility surfaces.

### Approach

Keep the implementation test-only and serial. Add a focused test module for
RunnerGuard active-turn inspection and only the test support needed to run
`checkRunnerGuard` against a controlled endpoint-backed fake app-server.

Use the existing `IssuePlanning` active-turn event-log path because
`IssuePlanningInitialized` followed by `IssuePlanningTurnStarted thread turn`
replays to `PlanningTurnActive` and reaches:

```haskell
checkActiveTurn config "planner" (ActiveTurn thread turn)
```

The fake app-server should record JSON-RPC requests and return scripted
responses. Assertions must inspect the actual received `thread/read` request,
not only the resulting guard problem. Because `checkRunnerGuard` calls
`sendOneAppServerRequest`, the fake should be a real local websocket endpoint
rather than a mocked pure interpreter. Add direct test-suite dependencies only
if the fake server imports them, likely `websockets` and `network`.

Prefer a new `test/RunnerGuardSpec.hs` over expanding `test/Main.hs` further.
If any helper is shared or noisy, place it in a narrow
`test/TestSupport/AppServer.hs` module and list both modules in
`moifold.cabal` under `test-suite watcher-core-test` `other-modules`.

### Steps

1. Add a focused RunnerGuard test entry point.
   - Create `test/RunnerGuardSpec.hs`.
   - Export a single aggregate such as
     `runnerGuardActiveTurnInspectionTests :: IO Bool`.
   - Import `CodexWatcher.RunnerGuard`, `CodexWatcher.AppServerProtocol`,
     `CodexWatcher.AppServerClient`, `CodexWatcher.EventLog.Types`,
     `CodexWatcher.Core.Ids`, `CodexWatcher.Core.Kinds`,
     `CodexWatcher.Core.Limits`, `CodexWatcher.Domain.IssuePlanning.Types`,
     and `CodexWatcher.Core.Thread` as needed.
   - Reuse `TestSupport.Workflow.assert`, `staleSecondsForTest`,
     `maxParallelForTest`, and `lookupValue` where practical.

2. Add the smallest endpoint-backed fake app-server test support.
   - The helper should start a localhost websocket server on an available port,
     return an `AppServerEndpoint`, run the supplied action, then stop/clean up
     the server thread.
   - Record every decoded JSON request value in an `IORef [Value]`.
   - Script responses by request method so each connection can answer the
     initial `initialize` request and then the actual RunnerGuard request.
   - For normal success, respond with JSON-RPC objects containing matching
     `"jsonrpc": "2.0"`, matching `"id"`, and `"result"`.
   - For app-server read-failure coverage, respond to the actual `thread/read`
     with a JSON-RPC error so `sendOneAppServerRequest` returns
     `AppServerJsonRpcFailure` and RunnerGuard details contain
     `formatAppServerClientFailure`.
   - For parse-failure coverage, respond to `thread/read` with malformed
     successful result data that makes `parseThreadReadTurns` fail.
   - Keep this support under `test/` only. Do not add production injection
     hooks to `RunnerGuardConfig`.

3. Add deterministic RunnerGuard fixture helpers in `RunnerGuardSpec`.
   - Use a per-test temporary directory under `/tmp` or another generated
     test path, always removing it before and after the test.
   - Write an event log containing:
     `IssuePlanningInitialized (PlannerConfig (RepoName "owner/name") (maxParallelForTest 8) [])`
     and `IssuePlanningTurnStarted (ThreadId "planner-thread") (TurnId "planner-turn")`.
   - Write `watcher.pid` with the current process id so `checkWatcherPid`
     does not dominate the active-turn result.
   - Build `RunnerGuardConfig 'IssuePlanning` with the fake endpoint,
     the test event-log path, stale threshold, repair cwd, and inert restart
     commands.
   - Add a helper to set the event-log modification time to either fresh or
     older than the configured stale threshold. Use this for stale-gated
     materialization and completed-unobserved cases.

4. Assert the active thread/read request shape.
   - Run `checkRunnerGuard` against a response whose active turn is still
     running and whose event log is fresh enough to avoid a stale problem.
   - Assert the guard result is `Nothing`.
   - Assert the recorded actual non-initialize request is method
     `"thread/read"`, request id `1`, parameter `"threadId" =
     "planner-thread"`, and parameter `"includeTurns" = True`.

5. Cover materialization-pending missing turns across the stale threshold.
   - Script the first `thread/read includeTurns=True` response as the
     materialization JSON-RPC error already recognized by
     `threadReadFallbackRequest`, and script the fallback
     `thread/read includeTurns=False` response as a successful thread object.
   - Fresh event log: assert `checkRunnerGuard` returns `Nothing`.
   - Stale event log: assert `LaunchRepairThread`, summary
     `"active planner turn is still materializing"`, and details include both
     `"turn: planner-turn"` and `"thread: planner-thread"`.
   - Also assert the recorded requests show the first active read uses
     `RequestId 1` with `includeTurns=True`; if asserting the fallback too,
     keep it secondary and expect the same request id with
     `includeTurns=False`.

6. Cover the RunnerGuard active-turn problem mappings.
   Add table-driven cases that each run `checkRunnerGuard` with a stale event
   log where staleness is required, then assert the exact
   `RunnerGuardProblem` action, summary, and key details:
   - `threadSystemError`: result has thread status type `systemError`;
     expect summary `"planner app-server thread is in systemError"` and
     details containing `"thread: planner-thread"` and the status text.
   - Missing active turn without materialization marker: result contains other
     turns but not `planner-turn`; expect summary
     `"active planner turn is missing from app-server thread"`.
   - Failed turn: `AppServerTurn planner-turn failed` with output/reason text;
     expect summary `"active planner turn failed"` and a `"reason: ..."`
     detail.
   - Completed without output: completed active turn with no output; expect
     summary `"active planner turn completed without output"`.
   - Blank output: completed active turn with whitespace output; expect
     summary `"active planner turn completed with blank output"`.
   - Completed but unobserved output: completed active turn with nonblank
     output and stale event log; expect summary
     `"completed planner turn has not been observed by watcher"`, action
     `LaunchRepairThread`, and stale details including the threshold line.

7. Cover app-server read and parse failure details.
   - Read failure: make the actual `thread/read` return a JSON-RPC error such
     as `"boom"`. Assert summary
     `"guard cannot read planner app-server thread"` and assert
     `runnerGuardProblemDetails` contains
     `formatAppServerClientFailure (AppServerJsonRpcFailure (RequestId 1) ...)`
     text, including the stable prefix
     `"app-server JSON-RPC error for request id 1: boom"`.
   - Parse failure: make `thread/read` return a successful result that cannot
     decode turns. Assert summary
     `"guard cannot parse planner app-server turns"` and assert details contain
     the stable `formatAppServerClientFailure` decode prefix
     `"app-server JSON decode failed:"`.

8. Wire the test into the suite.
   - Import `RunnerGuardSpec (runnerGuardActiveTurnInspectionTests)` from
     `test/Main.hs`.
   - In `main`, run the aggregate near the existing RunnerGuard checks and
     include it in the final `all` condition.
   - Add `RunnerGuardSpec` and any new `TestSupport.AppServer` module to
     `moifold.cabal` `test-suite watcher-core-test` `other-modules`.
   - Add only required test-suite dependencies for the fake server, expected
     to be `websockets` and `network` if the support module imports
     `Network.WebSockets` and `Network.Socket`.

9. Preserve selected boundaries.
   - Do not edit `src/CodexWatcher/RunnerGuard.hs`.
   - Do not migrate imports away from `CodexWatcher.AppServerClient`.
   - Do not edit production app-server protocol/client modules, docs, roadmap
     files, prior round artifacts, or compatibility fixtures.
   - Do not weaken existing RunnerGuard tests in `test/Main.hs`.

### Verification

Run the narrow test first, then the full required gates:

```sh
printf 'RunnerGuardSpec.runnerGuardActiveTurnInspectionTests\n:quit\n' | cabal repl watcher-core-test
cabal test watcher-core-test
cabal build all
git diff --check
git diff --cached --check
test ! -e orchestrator/rounds/round-111/worker-plan.json
git diff -- src/CodexWatcher/RunnerGuard.hs src/CodexWatcher/AppServerClient.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs
```

Expected changed paths should be limited to:

```text
test/RunnerGuardSpec.hs
test/TestSupport/AppServer.hs        # only if the fake server helper is split out
test/Main.hs
moifold.cabal                        # only for new test modules/dependencies
orchestrator/rounds/round-111/plan.md
```

If the narrow `cabal repl` command is not supported by the local Cabal/GHC
combination after adding the module, record that failure and rely on
`cabal test watcher-core-test` plus the exact RunnerGuard assertion output.

### Worker Fan-Out

No worker fan-out. This is one tightly coupled test slice: fake app-server
support, RunnerGuard fixtures, suite wiring, and Cabal metadata should be
implemented and debugged serially to avoid conflicting edits in the same test
surface. Do not write `worker-plan.json`.
