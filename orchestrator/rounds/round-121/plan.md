### Goal
Add focused watcher-core coverage for `src/CodexWatcher/AutomaticLoop/Runner.hs` so the automatic-loop runner's app-server interpreter construction, dry-run behavior, and retry/fallback classification are protected before any later `CodexWatcher.AppServerClient` import migration.

### Approach
Keep this round coverage-only and sequential. Do not migrate imports in `Runner.hs`, do not touch app-server protocol/client owner modules, and do not change runtime compatibility files, docs, fixtures, public APIs, or facade exposure.

Use the smallest testable seam:

- Prefer direct tests through exported `runAutomaticLoop` plus `TestSupport.AppServer.withEndpointBackedAppServer`, temporary event/state/work directories, and a one-iteration `LoopCli`.
- Drive an execute-capable scenario that must perform endpoint-backed app-server traffic, such as startup thread refresh or turn start, and assert the fake endpoint receives the expected JSON-RPC traffic from the configured `AppServerEndpoint`. Include the default client handshake behavior when practical so the coverage protects use of `defaultAppServerClientOptions`.
- Drive a dry-run scenario that preserves existing loop behavior without live app-server traffic for planned app-server effects. If a dry-run active-turn read legitimately requires app-server inspection, keep that case out of this assertion and instead use a dry-run start/effect scenario where `executePlannedAction` should render/record behavior without sending to the endpoint.
- Reuse existing daemon-loop tests and `retryableAutomaticLoopFailure` for retry/fallback classification unless a focused loop example is materially simpler.
- Only if direct `runAutomaticLoop` testing is too coupled to real runtime ownership, pid files, or post-tick side effects, extract a tiny behavior-preserving runner-local helper from `Runner.hs` that constructs the `ActionExecutor` or runner config from `LoopCli`. Export it only if needed for the watcher-core test and keep the production import from `CodexWatcher.AppServerClient` unchanged.

No worker fan-out is used. Do not create `orchestrator/rounds/round-121/worker-plan.json`.

### Steps
1. Add a focused test module, likely `test/AutomaticLoopRunnerSpec.hs`, exporting one aggregate such as `automaticLoopRunnerTests :: IO Bool`.
2. In that module, add an execute test that:
   - starts an endpoint-backed fake app-server with `TestSupport.AppServer.withEndpointBackedAppServer`;
   - writes a minimal temporary event log and state/work directories for a one-iteration automatic loop;
   - builds a `LoopCli` with `loopCliExecute = True`, `loopCliLoop = False`, `loopCliEndpoint = endpoint`, and a scenario that causes endpoint-backed app-server traffic;
   - runs the runner path under test;
   - asserts the fake server observed expected JSON-RPC requests, including default initialization traffic where exposed, plus the domain-specific request such as `thread/start` or `turn/start`.
3. Add a dry-run test in the same module that proves the applicable dry-run path does not send live app-server traffic while preserving behavior. Prefer a scenario where the runner reaches a planned app-server start effect in dry-run mode and appends or reports the synthetic/dry-run result without the endpoint server recording a `thread/start` or `turn/start`.
4. Add or keep retry/fallback tests that explicitly assert:
   - app-server transport failures remain retryable via `retryableAutomaticLoopFailure (DaemonLoopAppServerFailure (AppServerTransportFailure ...))`;
   - replay/decode failures remain fatal;
   - `DaemonLoopUnexpectedStartPlan` remains fatal.
   Reuse the existing `automaticLoopRetryPolicyKeepsTransientFailuresAlive` coverage if it remains in `test/Main.hs`; otherwise move or wrap it from the new focused module without weakening assertions.
5. Wire the aggregate into `test/Main.hs` and `moifold.cabal` only as test metadata: import the new module, call `automaticLoopRunnerTests` in `main`, include it in the final success conjunction, and add the module to `watcher-core-test` `other-modules`.
6. If direct `runAutomaticLoop` testing proves too heavy, make the smallest possible production extraction in `src/CodexWatcher/AutomaticLoop/Runner.hs`, such as a helper that builds the loop `ActionExecutor` from logger, endpoint, poll seconds, and stop flag. Keep behavior identical, keep `appServerInterpreterFromEndpoint endpoint defaultAppServerClientOptions` in the runner construction path, and do not migrate the import away from `CodexWatcher.AppServerClient`.
7. Confirm the implementation changed only the focused test module, `test/Main.hs`, `moifold.cabal` test metadata, and possibly the tiny `Runner.hs` helper seam. Do not edit orchestrator state, roadmaps, docs, fixtures, app code, runtime compatibility files, facade modules, direct app-server owner modules, or protocol modules.

### Verification
Run the focused tests first:

```sh
printf ':set -Wno-type-defaults\nAutomaticLoopRunnerSpec.automaticLoopRunnerTests\n:quit\n' | cabal repl watcher-core-test
```

Then run the full required gates:

```sh
cabal test watcher-core-test
cabal build all
git diff --check
git diff --cached --check
```

Run scope and import guards:

```sh
git diff -- src/CodexWatcher/AutomaticLoop/Runner.hs | rg 'CodexWatcher\\.AppServerClient|Workflow\\.Agent\\.Codex\\.Client|Workflow\\.Agent\\.Codex\\.Transport|Workflow\\.Agent\\.Codex\\.Interpreter' || true
git diff --name-only | rg -v '^(test/AutomaticLoopRunnerSpec.hs|test/Main.hs|moifold.cabal|src/CodexWatcher/AutomaticLoop/Runner.hs|orchestrator/rounds/round-121/plan.md)$' && exit 1 || true
git diff --name-only | rg '^(docs/|fixtures/|app/|src/CodexWatcher/AppServerClient.hs|src/CodexWatcher/AppServerProtocol.hs|src/CodexWatcher/Workflow/Agent/Codex|src/CodexWatcher/Runtime/Compatibility|src/CodexWatcher/Runtime/Owner|src/CodexWatcher/Domain/PrReview/LaunchCli.hs|src/CodexWatcher/Cli/Command/IssueFanout.hs)' && exit 1 || true
git diff -- moifold.cabal
test ! -e orchestrator/rounds/round-121/worker-plan.json
```

Interpret the first guard strictly: `Runner.hs` may still import `CodexWatcher.AppServerClient`, but this round must not migrate that import to direct owner modules. Any `moifold.cabal` diff must be limited to `watcher-core-test` metadata for the new test module.

Run state lifecycle checks without editing state:

```sh
jq -e '.contract_version == "orchestrator-v2" and .roadmap_style == "strategy-backlog" and .roadmap_id == "2026-05-11-00-highest-value-cleanup" and .roadmap_revision == "rev-001" and .controller_stage == "dispatch-rounds" and .active_round_id == "round-121" and .active_rounds[0].stage == "plan" and .active_rounds[0].worker_mode == "none" and .active_rounds[0].merge_ready == false and .roadmap_update == null' orchestrator/state.json
```
