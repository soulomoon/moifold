### Goal

Add focused watcher-core coverage for `src/CodexWatcher/Cli/Command/Observe.hs` before any `CodexWatcher.AppServerClient` import migration. The coverage must prove:

- execute mode rejects a missing app-server endpoint;
- execute mode builds its app-server interpreter from the configured `AppServerEndpoint` and the default client options where that behavior is externally testable;
- dry-run mode uses the null `AppServerInterpreter` fallback and does not require an endpoint.

This round is coverage only. It must not migrate imports, change app-server protocol/client/owner behavior, change daemon workflow behavior, alter runtime compatibility files or fixtures, update docs, expose/deprecate/remove public API, or touch package descriptors except for required watcher-core test-suite metadata. Shared invariants remain governed by `orchestrator/project-contract.md`.

### Approach

Use a sequential test-only implementation. Prefer black-box assertions through exported `observeOnce`; `observeOnceExecutor` is private and should remain private if the tests can exercise the behavior through the command boundary. Create a focused observe command test module, for example `test/ObserveCommandSpec.hs`, and wire it into `watcher-core-test` from `test/Main.hs` plus `moifold.cabal` `other-modules`.

Reuse existing test patterns instead of inventing a new harness:

- Use `TestSupport.AppServer.withEndpointBackedAppServer`, `jsonRpcResult`, and request capture to prove execute mode sends app-server JSON-RPC traffic to the configured endpoint.
- Reuse or locally mirror the stdout/stderr `ExitCode` capture pattern from `test/AppServerProbeSpec.hs` to assert `die` failures and successful command output without letting a test abort the suite.
- Build a small `ObserveOnceCli` fixture for the existing issue-planning `turn-started` observation and write a temporary event log containing `IssuePlanningInitialized`, so `observeOnce` reaches the `StartPlannerTurn` effect path.
- In execute mode, use the endpoint-backed server response for `thread/start` and assert request methods include the app-server session and command request, with stable command output containing `mode: ExecuteActions`.
- In dry-run mode, provide `observeCliEndpoint = Nothing`, run the same observation against a temporary event log, and assert success output contains `mode: DryRunActions`, `actions: 1`, and no endpoint-backed server is needed or contacted.
- For the missing-endpoint execute case, set `observeCliExecute = True` and `observeCliEndpoint = Nothing`; assert a non-success exit and stderr containing `--execute requires --app-server-host and --app-server-port`.

`defaultAppServerClientOptions` has no useful normal-path request rendering beyond successful endpoint-backed communication and the absence of an observe-specific timeout override. Do not add a slow timeout assertion. If black-box testing cannot prove the default-options path sufficiently, add only the smallest production test seam needed to inspect the executor builder, explain the seam in the test/plan evidence, and keep it internal to this command module's selected scope; do not introduce broad public API/export, facade exposure, or owner-module changes.

No worker fan-out is justified: the write set is one focused test module, the test aggregator, optional test metadata, and this plan. Do not create `orchestrator/rounds/round-118/worker-plan.json`.

### Steps

1. Add a focused observe command test module, preferably `test/ObserveCommandSpec.hs`, exporting a single aggregate such as `observeCommandTests :: IO Bool`.
2. In the new module, define a minimal `baseObserveCli` helper for `IssuePlanning` / `turn-started` with temporary paths, `RepoName "soulomoon/mlf2"`, a temporary workdir, `ThreadId "planner-thread"`, and `TurnId "turn-plan"`.
3. Add a helper that writes a temporary event log with `IssuePlanningInitialized (PlannerConfig repo (maxParallelForTest 8) [])` using the same JSON-lines encoding style as existing daemon tests.
4. Add or reuse a capture helper that runs `observeOnce` and returns `(ExitCode, stdout, stderr)` so both `die` and successful output are real command-boundary observations.
5. Implement the execute-without-endpoint assertion:
   - `observeCliExecute = True`
   - `observeCliEndpoint = Nothing`
   - expected result is non-success exit;
   - stderr includes `--execute requires --app-server-host and --app-server-port`;
   - no production app-server/client/direct-owner code is touched.
6. Implement the dry-run-without-endpoint assertion:
   - `observeCliExecute = False`
   - `observeCliEndpoint = Nothing`
   - run `observeOnce` against the initialized event log;
   - expected result is `ExitSuccess`;
   - stdout includes the observed event, `actions: 1`, and `mode: DryRunActions`;
   - this proves the null interpreter fallback is sufficient and no endpoint is required.
7. Implement the execute-with-configured-endpoint assertion:
   - wrap `observeOnce` in `withEndpointBackedAppServer`;
   - set `observeCliExecute = True` and `observeCliEndpoint = Just endpoint`;
   - return a valid `thread/start` JSON-RPC result from the fake server;
   - assert `ExitSuccess`, stdout includes `mode: ExecuteActions`, and captured requests show app-server traffic reached the configured endpoint, including the expected session/request method order for starting the planner turn.
8. Wire the aggregate into `test/Main.hs` near the other focused command tests, and add the new test module to `moifold.cabal` `watcher-core-test` `other-modules` if a new module is created.
9. Preserve the existing `observeOnceParsingCoversDomainsAndDefaults` parser assertions. Do not weaken, delete, or replace existing daemon/action-executor coverage.
10. Do not change `src/CodexWatcher/Cli/Command/Observe.hs` unless black-box testing through `observeOnce` is not feasible. If a seam is required, keep it minimal, behavior-preserving, and limited to making the current executor selection observable for tests.
11. Leave all out-of-scope source, docs, fixtures, runtime compatibility files, protocol/client/owner modules, package descriptors beyond required test metadata, and other importers unchanged.

### Verification

Run the focused REPL check for the new aggregate/test symbol:

```sh
printf 'ObserveCommandSpec.observeCommandTests\n:quit\n' | cabal repl watcher-core-test
```

Run the baseline gates sequentially:

```sh
cabal test watcher-core-test
cabal build all
git diff --check
git diff --cached --check
```

Run diff guards proving the round stayed coverage-only and did not perform the later import migration or touch forbidden surfaces:

```sh
git diff --name-only -- src/CodexWatcher/Cli/Command/Observe.hs \
  src/CodexWatcher/AppServerClient.hs \
  agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs \
  agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs \
  src/CodexWatcher/AppServerProtocol.hs \
  src/CodexWatcher/Domain/PrReview/LaunchCli.hs \
  src/CodexWatcher/Domain/IssuePlanning/Loop.hs \
  src/CodexWatcher/AutomaticLoop/Runner.hs \
  src/CodexWatcher/Cli/Command/IssueFanout.hs \
  docs runtime fixtures app

git diff --name-only -- '*.cabal' 'package.yaml' 'cabal.project*'

git diff --name-only -- . \
  ':!test/ObserveCommandSpec.hs' \
  ':!test/Main.hs' \
  ':!moifold.cabal' \
  ':!orchestrator/rounds/round-118/plan.md' \
  ':!orchestrator/rounds/round-118/selection.md' \
  ':!orchestrator/state.json'

git diff -- src/CodexWatcher/Cli/Command/Observe.hs | (! rg -n '^[-+]import .*AppServerClient|^[-+]import .*Workflow\.Agent\.Codex')
rg -n 'CodexWatcher\.AppServerClient' src app test docs '*.cabal'

test ! -e orchestrator/rounds/round-118/worker-plan.json
```

The first forbidden-surface command should print no changed paths unless the implementer used the explicitly justified minimal observe seam. The package-descriptor guard may print `moifold.cabal` only when adding the new test module to `watcher-core-test` metadata.

Run lifecycle state checks:

```sh
jq -e '
  .roadmap_id == "2026-05-11-00-highest-value-cleanup"
  and .roadmap_revision == "rev-001"
  and .controller_stage == "dispatch-rounds"
  and .active_round_id == "round-118"
  and (.active_rounds | length) == 1
  and .active_rounds[0].round_id == "round-118"
  and .active_rounds[0].stage == "plan"
  and .active_rounds[0].worker_mode == "none"
  and .active_rounds[0].merge_ready == false
  and (.active_rounds[0].roadmap_item_id == "round-118-observe-appserver-interpreter-coverage")
' orchestrator/state.json

jq -e '
  (.review_records == null or (.review_records | type == "object"))
  and (.roadmap_update == null)
' orchestrator/state.json
```
