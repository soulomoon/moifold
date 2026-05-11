### Goal

Add focused `watcher-core-test` coverage for
`CodexWatcher.RunnerGuard.startRunnerGuardRepairThread` repair-launch behavior
before any later `RunnerGuard.hs` `CodexWatcher.AppServerClient` import
migration is selected.

The round should prove the actual endpoint-backed repair launch sequence:
`thread/start` with `RequestId 1`, `thread/name/set` with `RequestId 2`,
and `turn/start` with `RequestId 3`; repair thread id, repair turn id, repair
thread name, and repair prompt flow; and the currently reported formatted
failure text for launch, name-set, turn-start, and turn-start parse failures.
It must not change production `RunnerGuard` behavior/imports or select the
import migration.

### Approach

Keep the implementation test-only and serial. Extend the round-111
`test/RunnerGuardSpec.hs` coverage and reuse
`test/TestSupport/AppServer.hs`'s endpoint-backed websocket fake app-server
instead of adding production injection points.

Test `startRunnerGuardRepairThread` directly with a deterministic
`RunnerGuardConfig 'IssuePlanning` and a constructed `RunnerGuardProblem`.
The fake app-server already records decoded JSON-RPC requests and handles
initialize/initialized session traffic for each endpoint-backed request, which
is enough to assert the actual request methods, ids, params, and ordering sent
by `startThreadWithEndpoint` and `sendOneAppServerRequest`.

If the existing fake helper needs a tiny test-only convenience for scripting
responses by method or inspecting request params, add it in
`test/TestSupport/AppServer.hs`. Do not touch `src/CodexWatcher/RunnerGuard.hs`,
`src/CodexWatcher/AppServerClient.hs`, or the owner client/transport/protocol
modules.

### Steps

1. Extend the RunnerGuard test aggregate.
   - Add a new `runnerGuardRepairLaunchSequenceTests :: IO Bool` helper inside
     `test/RunnerGuardSpec.hs`, or keep it private and include it in the
     exported `runnerGuardActiveTurnInspectionTests` aggregate.
   - Prefer keeping the public export unchanged unless a separate focused REPL
     target is clearer.
   - Reuse existing `RunnerGuardConfig`, `RunnerGuardProblem`,
     `LaunchRepairThread`, `ThreadId`, `TurnId`, `RequestId`,
     `formatAppServerClientFailure`, `AppServerJsonRpcFailure`,
     `AppServerDecodeFailure`, `JsonRpcError`, `assert`, `sequenceAnd`, and
     `lookupValue` imports/patterns already present in `RunnerGuardSpec`.

2. Add deterministic repair fixture helpers in `RunnerGuardSpec`.
   - Build a `RunnerGuardConfig 'IssuePlanning` with `guardRepo =
     RepoName "owner/name"`, fake endpoint, repair cwd under a unique `/tmp`
     directory, and fixed restart commands.
   - Construct a `RunnerGuardProblem` with `LaunchRepairThread`, a stable
     summary such as `"watcher event log replay failed"`, and details that are
     distinctive enough to assert they flow into the prompt.
   - Add request-inspection helpers for non-session methods so assertions can
     ignore `initialize` and `initialized` traffic while preserving the actual
     endpoint-backed sequence.

3. Cover the successful repair launch sequence.
   - Script fake responses:
     - `thread/start`: JSON-RPC success with result containing
       `"threadId": "repair-thread"`.
     - `thread/name/set`: JSON-RPC success with an empty result object.
     - `turn/start`: JSON-RPC success with result containing
       `"turnId": "repair-turn"`.
   - Call `startRunnerGuardRepairThread config problem`.
   - Assert the returned `RunnerGuardRepair` has
     `runnerGuardRepairThreadId = ThreadId "repair-thread"` and
     `runnerGuardRepairTurnId = TurnId "repair-turn"`.
   - Assert the recorded non-session request methods are exactly:
     `["thread/start", "thread/name/set", "turn/start"]`.
   - Assert request ids are exactly `1`, `2`, and `3` on those methods.
   - Assert `thread/name/set` params include
     `"threadId": "repair-thread"` and
     `"name": "runner-guard repair owner/name"`.
   - Assert `turn/start` params include `"threadId": "repair-thread"` and
     an `"input"` text containing the RunnerGuard prompt sections:
     `"Runner guard detected a problem in the IssuePlanning watcher."`,
     `"Problem summary:"`, the problem summary, `"Problem details:"`, each
     problem detail, `"Repository to repair:"`, the repair cwd, the exact
     restart watcher command, and the exact restart guard command.
   - Assert `thread/start` params include the repair cwd and developer
     instructions text that identifies the runner guard repair worker.

4. Cover launch failure formatting.
   - Script `thread/start` to return a JSON-RPC error such as `"launch boom"`.
   - Call `startRunnerGuardRepairThread` and catch the thrown `IO` failure.
   - Assert the exception text contains the stable formatted prefix from
     `formatAppServerClientFailure`, for example
     `"app-server JSON-RPC error for request id 1: launch boom"`.
   - Assert only the `thread/start` non-session request was sent.

5. Cover name-set failure formatting.
   - Script `thread/start` success with `"repair-thread"`.
   - Script `thread/name/set` to return a JSON-RPC error such as
     `"name boom"`.
   - Catch the thrown failure and assert it contains
     `"app-server JSON-RPC error for request id 2: name boom"`.
   - Assert the recorded non-session methods stop after
     `["thread/start", "thread/name/set"]` and retain ids `1` and `2`.

6. Cover turn-start request failure formatting.
   - Script `thread/start` and `thread/name/set` success.
   - Script `turn/start` to return a JSON-RPC error such as `"turn boom"`.
   - Catch the thrown failure and assert it contains
     `"app-server JSON-RPC error for request id 3: turn boom"`.
   - Assert the full three-request sequence was attempted with ids `1`, `2`,
     and `3`.

7. Cover turn-start parse failure formatting.
   - Script `thread/start` and `thread/name/set` success.
   - Script `turn/start` success with a malformed result such as
     `{"unexpected": "shape"}` so `parseTurnStartTurnId` fails.
   - Catch the thrown failure and assert it contains the stable decode prefix
     `"app-server JSON decode failed:"`.
   - Assert the full three-request sequence was attempted and that the
     `turn/start` request still contains the expected repair prompt text.

8. Keep suite wiring minimal.
   - If the new tests are included in the existing
     `runnerGuardActiveTurnInspectionTests` export, no `test/Main.hs` change is
     needed beyond the internal aggregate result.
   - If a new export is chosen for a cleaner focused REPL target, import it
     from `test/Main.hs`, run it next to the existing RunnerGuard checks, and
     add it to the final `all` condition.
   - Do not add Cabal metadata unless a new module is actually introduced.
     Prefer no new module because `RunnerGuardSpec` and `TestSupport.AppServer`
     already exist in `moifold.cabal`.

9. Preserve selected boundaries.
   - Do not edit `src/CodexWatcher/RunnerGuard.hs`.
   - Do not migrate `RunnerGuard.hs` away from `CodexWatcher.AppServerClient`.
   - Do not edit production app-server client, transport, or protocol modules.
   - Do not edit docs, roadmap files, prior round artifacts, compatibility
     fixtures, package exposure, or public API surfaces.
   - Do not weaken the round-111 active-turn inspection tests.

### Verification

Run the focused target first, then the full required gates:

```sh
printf 'RunnerGuardSpec.runnerGuardActiveTurnInspectionTests\n:quit\n' | cabal repl watcher-core-test
cabal test watcher-core-test
cabal build all
git diff --check
git diff --cached --check
test ! -e orchestrator/rounds/round-112/worker-plan.json
git diff -- src/CodexWatcher/RunnerGuard.hs src/CodexWatcher/AppServerClient.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs agent-workflow-codex/src/CodexWatcher/AppServerProtocol.hs
```

Expected changed paths should be limited to:

```text
test/RunnerGuardSpec.hs
test/TestSupport/AppServer.hs        # only if a tiny test helper is needed
test/Main.hs                         # only if adding a new exported aggregate
moifold.cabal                        # only if adding a new test module
orchestrator/rounds/round-112/plan.md
```

The production diff guard must be empty. If the focused `cabal repl` aggregate
is not supported by the local Cabal/GHC combination, record the failure and
rely on `cabal test watcher-core-test` plus the exact RunnerGuard assertion
output.

### Worker Fan-Out

No worker fan-out. This is one tightly coupled test slice in the existing
RunnerGuard test module and fake app-server support, with shared assertions
over request order and failure flow. Do not write `worker-plan.json`.
