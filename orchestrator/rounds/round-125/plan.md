### Goal

Add focused watcher-core coverage for the app-server-backed IssueFanout child implementer launch path in `src/CodexWatcher/Cli/Command/IssueFanout.hs`, before any `CodexWatcher.AppServerClient` import migration. The round should prove the current behavior around child thread creation, child command rendering, request-id sequencing, retryable workdir setup, readiness/completion classification, and selected app-server failure formatting.

This is a sequential test-coverage round. Do not write `worker-plan.json`.

### Approach

Create a new focused test module, `test/IssueFanoutAppServerSpec.hs`, modeled on `test/PrReviewLaunchCliSpec.hs` and backed by `test/TestSupport/AppServer.hs`'s `withEndpointBackedAppServer`. Keep production behavior unchanged unless an unavoidable testability seam is discovered and explicitly justified in the implementation notes.

Prefer exercising exported IssueFanout APIs and existing workflow helpers over source-string assertions. Existing useful imports are already demonstrated in `test/Main.hs` and `test/TestSupport/Workflow.hs`: `IssueImplementerChildLaunch`, `issueImplementerChildArgs`, `issueImplementerChildLaunchMode`, `issueImplementerLaunchManifest`, `readyIssueStatusFromRuntime`, `resolveFanoutActiveIssues`, and `retryableLaunchCommandFailure`. Do not migrate production imports from `CodexWatcher.AppServerClient` in this round.

The new module should own the endpoint-backed app-server launch behavior that is too integration-shaped for the older inline `test/Main.hs` helpers. Keep existing tests unless replacing one with equivalent or stronger coverage in the new module.

### Steps

1. Add `test/IssueFanoutAppServerSpec.hs` exporting `issueFanoutAppServerTests :: IO Bool`.
2. In that module, reuse `withEndpointBackedAppServer`, `jsonRpcResult`, and `jsonRpcError` to drive IssueFanout app-server calls with deterministic request ids.
3. Add a success-path test that executes multiple IssueFanout child launches against the endpoint-backed server and asserts:
   - the app server receives `thread/start` requests for each selected issue;
   - request ids progress from `8000` for IssueFanout launches;
   - each request uses the launch workdir as `cwd`;
   - developer instructions preserve repo, issue number, branch, state dir, and workdir context;
   - generated config, events, pending/finalized manifests, and thread ids reflect the app-server-created thread ids.
4. Add command-rendering coverage for `issueImplementerChildArgs` and dry-run output shape:
   - root endpoint omits `--app-server-path`;
   - non-root endpoint includes `--app-server-path`;
   - rendered child args keep `run-issue-implement`, `--events`, `--state-dir`, `--repo`, `--workdir`, app-server host/port, poll seconds, `--execute`, `--loop`, and `--pid-file`.
5. Add workdir setup retry coverage around `retryableLaunchCommandFailure` and the setup-command retry contract:
   - keep the pure retryable predicate test for transient `gh repo clone` failures;
   - if an integration check is added, make it local and deterministic, and do not require real network or GitHub access.
6. Add readiness/completion classification coverage for child start results:
   - running pid readiness classifies as started;
   - terminal-complete runtime status before pid readiness classifies as completed-before-ready;
   - a non-running, non-complete status produces a problem result with the readiness detail.
   If direct coverage of `startIssueImplementerChildDetailed` is impossible without a production seam, record the exact blocker and keep the best existing source-order assertion in `test/Main.hs`.
7. Add app-server failure-format tests using endpoint-backed JSON-RPC and decode failures:
   - JSON-RPC failure exits non-zero and includes the formatted request id, starting at `8000`;
   - decode failure exits non-zero and includes the formatted decode failure prefix;
   - failed first request does not send later child-thread requests.
8. Wire the new suite in `test/Main.hs` by importing `IssueFanoutAppServerSpec (issueFanoutAppServerTests)` and adding it to the watcher-core test sequence.
9. Update only the `watcher-core-test` metadata in `moifold.cabal` by adding `IssueFanoutAppServerSpec` to `other-modules`. Do not change library exposed modules, package descriptors outside the required test metadata, or public facade exposure.
10. Before handing to review, confirm no production import migration happened. `src/CodexWatcher/Cli/Command/IssueFanout.hs` should still import `CodexWatcher.AppServerClient`, and no round should remove or deprecate the public facade.
11. Do not edit `orchestrator/state.json`, roadmap files, docs, fixtures, runtime compatibility files, app code, or `orchestrator/rounds/round-125/selection.md`.

### Verification

Run these focused checks while implementing:

```sh
cabal repl watcher-core-test
```

Use the REPL to load `IssueFanoutAppServerSpec` and run `issueFanoutAppServerTests` if this is faster than the full suite during iteration.

Run the required final checks:

```sh
cabal test watcher-core-test
cabal build all
git diff --check
```

Run import and scope guards before review:

```sh
rg -n 'import CodexWatcher\.AppServerClient' src/CodexWatcher/Cli/Command/IssueFanout.hs
git diff -- src/CodexWatcher/Cli/Command/IssueFanout.hs
git diff -- moifold.cabal test/Main.hs test/IssueFanoutAppServerSpec.hs
test ! -e orchestrator/rounds/round-125/worker-plan.json
```

Before implement/review role transitions, check the live controller state without editing it:

```sh
jq -r '.stage as $controller_stage | .active_rounds[] | select(.round_id == "round-125") | "controller_stage=\($controller_stage)\nround_stage=\(.stage)"' orchestrator/state.json
```

The implementer should see `plan` before implementation starts and should not proceed if the controller has advanced to an unexpected round. The reviewer should see the round at `review` or the controller-approved review stage before treating the implementation as review-ready.

If staging is performed later, also run:

```sh
git diff --cached --check
```
