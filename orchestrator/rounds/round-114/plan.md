### Goal

Add focused watcher-core command coverage for `probeAppServer` in `src/CodexWatcher/Cli/Command/AppServerProbe.hs`, using an endpoint-backed fake app-server to prove the command-level JSON-RPC request sequence, request ids, smoke-thread and smoke-turn parameters, success output, and selected user-visible failure formatting before any later import-only migration is considered.

### Approach

Keep this round test-only. Add a focused IO test module, `test/AppServerProbeSpec.hs`, instead of mixing command execution and stdout/stderr capture into the existing pure `AppServerSpec` protocol properties or parser-only `CliSpec` checks. Wire the new aggregate into `test/Main.hs` and add only the required `watcher-core-test` `other-modules` metadata in `moifold.cabal`.

Use `TestSupport.AppServer.withEndpointBackedAppServer`, `jsonRpcResult`, and `jsonRpcError` so tests exercise the real websocket transport, initialize/session behavior, response matching, and `formatAppServerClientFailure` output path. If a helper is needed for command output, keep it local to `AppServerProbeSpec` and implement it with existing `base`/`unix` test dependencies by capturing stdout/stderr around `probeAppServer`; do not add a package dependency.

The assertions should inspect command-level requests by filtering out the automatic per-request session handshake (`initialize` id `0` and `initialized` notifications) while retaining the explicit command initialize request id `1`. This keeps request-id checks aligned with the current transport contract: explicit command calls use ids `1`, `2`, `3`, and `4`, while non-initialize requests also open their own initialized session.

Do not change `src/CodexWatcher/Cli/Command/AppServerProbe.hs`, `CodexWatcher.AppServerClient`, direct owner client/transport modules, protocol modules, runtime fixtures, docs, other importers, facade exposure, public API, Cabal exposure, or package descriptors except for the new watcher-core test module metadata.

### Steps

1. Add `test/AppServerProbeSpec.hs` exporting `appServerProbeCommandTests :: IO Bool`.
2. In the new spec, define small request-inspection helpers for method, id, params, text params, and turn input text, reusing `TestSupport.Workflow.assert` and `sequenceAnd` where useful.
3. Add a local `runProbe` helper that starts `withEndpointBackedAppServer`, builds `AppServerProbeCli` with the fake endpoint and a configured workdir such as `/tmp/moifold-app-server-probe-test`, runs `probeAppServer`, captures stdout/stderr plus `ExitCode`, and returns the recorded requests.
4. Add a success test for initialize-only probing. Assert the explicit command request is `initialize` with request id `1`, client name `moifold-probe`, version `0.1.0`, stdout contains `ok initialize` and `app-server probe passed`, and the command exits successfully.
5. Add a success test with `--thread-id`, `--create-smoke-thread`, and `--start-smoke-turn` behavior represented directly in `AppServerProbeCli`. Return a successful `thread/start` result and `turn/start` result from the fake server, then assert command-level methods and ids are `initialize`/`thread/read`/`thread/start`/`turn/start` with ids `1`/`2`/`3`/`4`; `thread/read` uses the configured thread id with `includeTurns = False`; `thread/start` carries the configured workdir and developer instructions `moifold app-server smoke probe`; `turn/start` carries request id `4`, the configured workdir, prompt text `Reply with OK for a moifold app-server smoke probe.`, and the expected thread id; stdout includes all `ok ...` lines and the final success line.
6. Add a success test for `--start-smoke-turn` without an existing thread id. Assert the command creates a smoke thread first, then uses the returned smoke thread id in the `turn/start` request, so the branch where `maybeThreadId` comes from `smokeThread` is covered.
7. Add selected failure-formatting tests:
   - `thread/read` JSON-RPC failure returns `jsonRpcError` for request id `2`; assert non-zero exit, stderr contains `app-server JSON-RPC error for request id 2: <message>`, no final success line is printed, and no later smoke requests are sent.
   - `thread/start` JSON-RPC failure returns `jsonRpcError` for request id `3`; assert non-zero exit, stderr contains `app-server JSON-RPC error for request id 3: <message>`, and no `turn/start` command request is sent.
   - `turn/start` parse failure returns a malformed success result missing `turn.id`; assert non-zero exit and stderr contains the stable `app-server JSON decode failed:` prefix produced through `formatAppServerClientFailure`.
8. Wire `appServerProbeCommandTests` into `test/Main.hs` near the existing app-server and CLI checks, and include its result in the final watcher-core boolean aggregation.
9. Add `AppServerProbeSpec` to the `watcher-core-test` `other-modules` list in `moifold.cabal`. Do not change any other package descriptor field.
10. Confirm no `orchestrator/rounds/round-114/worker-plan.json` exists; this is a single-file test slice plus narrow harness wiring and does not justify worker fan-out.

### Verification

Run these from the round-114 worktree after implementation:

```sh
printf 'AppServerProbeSpec.appServerProbeCommandTests\n:quit\n' | cabal repl watcher-core-test
cabal test watcher-core-test
cabal build all
git diff --exit-code -- src/CodexWatcher/Cli/Command/AppServerProbe.hs src/CodexWatcher/AppServerClient.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs agent-workflow-codex/src/CodexWatcher/AppServerProtocol.hs
git diff --exit-code -- agent-workflow-core/agent-workflow-core.cabal agent-workflow-codex/agent-workflow-codex.cabal agent-workflow-github/agent-workflow-github.cabal
git diff -- moifold.cabal
test ! -e orchestrator/rounds/round-114/worker-plan.json
git diff --check
git diff --cached --check
jq . orchestrator/state.json
```

The `moifold.cabal` diff must be limited to adding `AppServerProbeSpec` under `watcher-core-test` `other-modules`. After review, also run:

```sh
jq . orchestrator/rounds/round-114/review-record.json
```

### Worker Fan-Out

No worker fan-out. The slice is intentionally serial: one focused test module, one test aggregation hook, and one test-suite metadata entry.
