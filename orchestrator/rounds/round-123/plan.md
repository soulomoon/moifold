### Goal

Add focused watcher-core coverage for `src/CodexWatcher/Domain/PrReview/LaunchCli.hs` before any `CodexWatcher.AppServerClient` import migration. The coverage must protect endpoint-backed PR-review worker/reviewer thread launch, launch-plan thread-id refresh, child launch command rendering, and selected app-server failure formatting.

This round is coverage-only. It must not migrate production imports, change `CodexWatcher.AppServerClient`, edit direct owner client/transport/protocol modules, change endpoint parsing, change child daemon ownership, change runtime compatibility files, fixtures, docs, app code, public API/facade/Cabal exposure, issue fanout, test-policy/support imports, deprecation/removal/release/terminal completion, or create worker fan-out. Shared invariants remain governed by `orchestrator/project-contract.md`.

### Approach

Use a sequential test-only implementation. Prefer existing public functions from `CodexWatcher.Domain.PrReview.LaunchCli`:

- `prReviewWatcherLaunchPlan` to build deterministic launch fixtures.
- `launchPrReviewWatcher Execute (Just endpoint)` to exercise the private endpoint-backed worker/reviewer `thread/start` path without exporting `preparePrReviewWatcherLaunch`.
- `launchPrReviewWatcher DryRun (Just endpoint)` to observe the private `prReviewWatcherChildArgs` rendering through the printed child command without exporting `prReviewWatcherChildArgs`.

Do not add public exports from `LaunchCli.hs`. If a tiny seam proves absolutely necessary, it must be behavior-preserving, justified in implementation notes, and limited to test observability; still do not migrate imports or change app-server/client owner modules. The expected path is no production edit.

To keep the execute launch from spawning a real child daemon after successful thread creation, pre-create a `runtime-owner.json` marker in the launch state directory with a `HaskellRuntime` lease for the current test process. `startPrReviewWatcherChild` should then take the existing-live-owner branch, restore `watcher.pid`, and avoid `startChildDaemon`. This uses the current runtime-owner behavior instead of adding a child-daemon seam.

Create a focused test module, likely `test/PrReviewLaunchCliSpec.hs`, exporting `prReviewLaunchCliTests :: IO Bool`. Reuse `TestSupport.AppServer.withEndpointBackedAppServer`, `jsonRpcResult`, `jsonRpcError`, `TestSupport.Workflow.assert`, `lookupValue`, `pollSecondsForTest`, and `sequenceAnd`. Reuse the stdout/stderr/`ExitCode` capture style from `test/ObserveCommandSpec.hs` or `test/AppServerProbeSpec.hs`.

No worker fan-out is justified: the write set should be one focused test module, `test/Main.hs`, optional `moifold.cabal` watcher-core test metadata, and this plan. Do not create `orchestrator/rounds/round-123/worker-plan.json`.

### Steps

1. Add `test/PrReviewLaunchCliSpec.hs` with `prReviewLaunchCliTests :: IO Bool`.
2. Build a fixture helper that creates a temporary root/workdir, constructs an `IssueConfig` for a stable repo/branch and `PrNumber`, then calls `prReviewWatcherLaunchPlan root workdir issueConfig prNumber`.
3. Add a helper that writes a live `runtime-owner.json` into `launch.reviewLaunchStateDir` before the successful execute launch. Use `runtimeLeaseJson`/current `RuntimeLease` shape or `writeRuntimeLease` with the current process id, `HaskellRuntime`, stable timestamps, and a dummy event-log head hash. The helper exists only to make the public execute path skip real child daemon spawning.
4. Add the endpoint-backed successful launch test:
   - start `withEndpointBackedAppServer` with responses for `thread/start`;
   - return `ThreadId "worker-created"` for request id `9000` and `ThreadId "reviewer-created"` for request id `9001`;
   - run `launchPrReviewWatcher Execute (Just endpoint) pollSeconds launch`;
   - assert exit success, captured non-session requests are exactly the two `thread/start` calls after app-server session initialization traffic is ignored or accounted for;
   - assert request ids `9000` and `9001`;
   - assert both requests include `cwd = launch.reviewLaunchWorkdir`;
   - assert worker developer instructions contain the worker role and PR-review state/workdir context, and reviewer developer instructions contain the reviewer role and the same context;
   - read the written config/events or finalized manifest and assert the persisted launch uses `worker-created` and `reviewer-created` as the worker/reviewer thread ids.
5. Add the child command rendering test through `launchPrReviewWatcher DryRun (Just endpoint) pollSeconds launch`:
   - use one endpoint with path `/` and one endpoint with a non-root path such as `/codex/app-server`;
   - capture stdout and assert the rendered `PR review child command:` includes `run-pr-review`, `--events`, `--state-dir`, `--repo`, `--workdir`, `--app-server-host`, `--app-server-port`, `--poll-seconds`, `--execute`, `--loop`, and `--pid-file`;
   - assert the pid file is `launch.reviewLaunchStateDir </> "watcher.pid"`;
   - assert `--app-server-path` is omitted for `/` and included with the configured path for the non-root endpoint.
6. Add selected app-server failure formatting tests through the same public execute path:
   - JSON-RPC error: fake the first `thread/start` response with `jsonRpcError request (-32000) "worker boom"`, capture the non-success exit, and assert stderr contains `app-server JSON-RPC error for request id 9000: worker boom`;
   - decode failure: fake a malformed `thread/start` result, capture the non-success exit, and assert stderr contains `app-server JSON decode failed:`;
   - assert the JSON-RPC failure stops after the worker request, and if the decode case is on the worker request, it also stops before request id `9001`.
7. Keep all helpers local to the new test module unless an existing support helper is already exported. Do not move request-inspection helpers into `TestSupport.AppServer` or `TestSupport.Workflow`, because support-import cleanup is out of scope.
8. Wire the aggregate into `test/Main.hs`: import `PrReviewLaunchCliSpec (prReviewLaunchCliTests)`, run it near the other command/runner focused aggregates, and include it in the final success conjunction.
9. Add `PrReviewLaunchCliSpec` to `moifold.cabal` `watcher-core-test` `other-modules` if the new module is created. Do not change package descriptors beyond that test metadata.
10. Leave `src/CodexWatcher/Domain/PrReview/LaunchCli.hs` unchanged unless the public-path approach is proven impossible. If a seam is unavoidable, keep it tiny, do not migrate imports, do not change behavior, and explicitly record why the public execute/dry-run paths could not cover the selected behavior.
11. Leave `CodexWatcher.AppServerClient`, `CodexWatcher.AppServerProtocol`, `agent-workflow-codex` owner modules, endpoint parsing, child daemon modules, runtime compatibility files, fixtures, docs, app code, issue fanout, test-policy/support imports, public API/facade/Cabal exposure, release/deprecation/removal artifacts, and unrelated production files untouched.

### Verification

Run the focused REPL gate for the new aggregate:

```sh
printf ':set -Wno-type-defaults\nPrReviewLaunchCliSpec.prReviewLaunchCliTests\n:quit\n' | cabal repl watcher-core-test
```

Run the required baseline gates:

```sh
cabal test watcher-core-test
cabal build all
git diff --check
git diff --cached --check
```

Run import and migration guards:

```sh
rg -n '^import[[:space:]]+CodexWatcher\.AppServerClient\b' src/CodexWatcher/Domain/PrReview/LaunchCli.hs
! rg -n '^import[[:space:]]+CodexWatcher\.Workflow\.Agent\.Codex\.(Client|Transport|Interpreter)\b' src/CodexWatcher/Domain/PrReview/LaunchCli.hs
git diff -- src/CodexWatcher/Domain/PrReview/LaunchCli.hs | (! rg -n '^[-+]import .*CodexWatcher\.(AppServerClient|Workflow\.Agent\.Codex)')
```

The first command must prove `LaunchCli.hs` still imports the compatibility facade. The second and third commands must prove this round did not perform the direct-owner migration.

Run changed-path and forbidden-surface guards:

```sh
git diff --name-only -- . \
  ':!test/PrReviewLaunchCliSpec.hs' \
  ':!test/Main.hs' \
  ':!moifold.cabal' \
  ':!orchestrator/rounds/round-123/plan.md' \
  ':!orchestrator/rounds/round-123/selection.md' \
  ':!orchestrator/state.json'

git ls-files --others --exclude-standard -- . \
  ':!test/PrReviewLaunchCliSpec.hs' \
  ':!orchestrator/rounds/round-123/plan.md' \
  ':!orchestrator/rounds/round-123/selection.md'

git diff --name-only -- \
  src/CodexWatcher/AppServerClient.hs \
  src/CodexWatcher/AppServerProtocol.hs \
  agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs \
  agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs \
  agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Interpreter.hs \
  src/CodexWatcher/ChildDaemon.hs \
  src/CodexWatcher/Cli/Command/IssueFanout.hs \
  src/CodexWatcher/Runtime/Compatibility.hs \
  src/CodexWatcher/Runtime/Owner \
  docs fixtures app

git diff --name-only -- '*.cabal' 'package.yaml' 'cabal.project*'
test ! -e orchestrator/rounds/round-123/worker-plan.json
```

The first changed-path guard should print no paths. The untracked guard should print no paths other than the new test module if it has not been staged. The forbidden-surface guard should print no paths. The package-descriptor guard may print only `moifold.cabal`, and only for watcher-core test metadata.

Run optional content guards if the implementer touched `LaunchCli.hs` for a seam:

```sh
git diff -- src/CodexWatcher/Domain/PrReview/LaunchCli.hs
git diff -- src/CodexWatcher/Domain/PrReview/LaunchCli.hs | rg -n '^[-+](?!import |  , |module |$)' && false || true
```

Any production diff must be justified as a tiny test seam and must not include behavior changes or import migration.

Run control-plane checks without editing state:

```sh
jq -e '
  .roadmap_id == "2026-05-11-00-highest-value-cleanup"
  and .roadmap_revision == "rev-001"
  and .controller_stage == "dispatch-rounds"
  and .active_round_id == "round-123"
  and (.active_rounds | length) == 1
  and .active_rounds[0].round_id == "round-123"
  and .active_rounds[0].stage == "plan"
  and .active_rounds[0].worker_mode == "none"
  and .active_rounds[0].merge_ready == false
  and (.active_rounds[0].roadmap_item_id == "round-123-pr-review-launch-appserverclient-coverage")
' orchestrator/state.json

jq -e '
  (.review_records == null or (.review_records | type == "object"))
  and (.roadmap_update == null)
' orchestrator/state.json
```

If the controller has advanced the lifecycle stage by validation time, adjust only the expected stage predicate and keep lineage, worker mode, merge readiness, and roadmap-update assertions intact.

### Worker Fan-Out

Worker fan-out is not used. The selected scope is a focused coverage slice with a small, tightly coupled test write set, so `orchestrator/rounds/round-123/worker-plan.json` must not be created.
