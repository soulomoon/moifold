### Goal

Add focused endpoint-backed test coverage for `CodexWatcher.Healthcheck`
app-server thread inspection before any `CodexWatcher.Healthcheck` import
migration. The round must prove the live `thread/read` inspection contract
without changing production behavior, public facades, package descriptors, or
runtime compatibility surfaces.

### Approach

Test the behavior through the exported `runHealthcheck` entry point. Do not
export `checkAppServerThread`, do not move it, and do not change
`src/CodexWatcher/Healthcheck.hs`.

Use `test/TestSupport/AppServer.hs`'s `withEndpointBackedAppServer`,
`jsonRpcResult`, and `jsonRpcError` to exercise the real websocket-backed
request path. In `test/HealthcheckSpec.hs`, add a single exported aggregate:

```haskell
healthcheckAppServerThreadInspectionTests :: IO Bool
```

The aggregate should create temporary watcher state roots, run
`runHealthcheck`, capture its JSON stdout, decode the report, and assert only
the healthcheck fields relevant to this round. Because `runHealthcheck` also
runs environment and GitHub CLI diagnostics, add a local test helper that
prepends temporary stub executables for `git`, `gh`, `cabal`, `ghc`, and
`ghcup` to `PATH`; the stubs should return deterministic version/auth/user
output so these endpoint tests do not depend on host auth or network state.

No worker fan-out is justified. The edit target is one test module plus one
test runner registration, with no non-overlapping implementation ownership to
split. Do not create `orchestrator/rounds/round-116/worker-plan.json`.

### Steps

1. Re-read the active scope and contracts before editing:
   - `sed -n '1,220p' orchestrator/rounds/round-116/selection.md`
   - `sed -n '1,220p' orchestrator/project-contract.md`
   - `sed -n '1,220p' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`
2. Confirm the private implementation and exported test route:
   - `rg -n "checkAppServerThread|threadReadRequest \\(RequestId 9001\\)|runHealthcheck" src/CodexWatcher/Healthcheck.hs`
   - `sed -n '1,80p' src/CodexWatcher/Healthcheck.hs`
   - `rg -n "withEndpointBackedAppServer|jsonRpcResult|jsonRpcError" test/TestSupport/AppServer.hs`
3. Edit only `test/HealthcheckSpec.hs` for the new endpoint-backed aggregate:
   - export `healthcheckAppServerThreadInspectionTests`;
   - import `runHealthcheck` and `HealthcheckOptions (..)` from
     `CodexWatcher.Healthcheck`;
   - use the existing fake endpoint helpers from `TestSupport.AppServer`;
   - reuse `TestSupport.Workflow` helpers such as `assert`, `lookupValue`, and
     `sequenceAnd` where useful;
   - keep any stdout-capture, temporary state-root, and stub-command helpers
     local to `HealthcheckSpec` unless a tiny `TestSupport.Workflow` helper is
     clearly needed.
4. Add a success case that writes a minimal watcher config under a temporary
   state root, runs `runHealthcheck` with an endpoint, and asserts:
   - the recorded app-server session includes the `thread/read` request;
   - the `thread/read` request has id `9001`;
   - the request method is `thread/read`;
   - `params.threadId` is the configured thread id;
   - `params.includeTurns` is `True`;
   - the decoded report's `workerThreadInspection` has `skipped = False`,
     `ok = True`, `threadId`, `turnCount`, `latestTurnId`, and
     `latestTurnStatus` matching the fake response's latest turn.
5. Add skipped-case coverage:
   - missing endpoint: run with `appServerEndpoint = Nothing` and a configured
     `threadId`; assert `workerThreadInspection.skipped = True`, `ok = True`,
     `threadId` is preserved, and `reason` is
     `healthcheck app-server endpoint not configured`;
   - missing thread id: run with an endpoint and a config without `threadId`;
     assert `workerThreadInspection.skipped = True`, `ok = True`, `threadId`
     is absent, `reason` is `config has no thread id`, and the fake endpoint
     receives no `thread/read` for that watcher.
6. Add failure-format coverage:
   - JSON-RPC error: have the fake endpoint return
     `jsonRpcError request (-32000) "read boom"` for `thread/read`; assert
     `ok = False` and `reason` contains
     `app-server JSON-RPC error for request id 9001: read boom`;
   - decode failure: have the fake endpoint return a successful JSON-RPC
     result with malformed turns, such as a turn object missing `id`; assert
     `ok = False` and `reason` starts with
     `app-server JSON decode failed:`.
7. Cover timeout behavior where practical without changing production:
   - add one bounded case where the fake endpoint delays the `thread/read`
     response longer than the current hard-coded healthcheck timeout;
   - assert `ok = False` and `reason` contains
     `app-server response timed out for request id 9001`;
   - if this proves too slow or flaky, do not add production configurability in
     this round; record the omitted timeout case and reason in
     `implementation-notes.md`.
8. Edit `test/Main.hs` only to import and run
   `healthcheckAppServerThreadInspectionTests` alongside the existing
   Healthcheck checks.
9. Do not edit production files, package descriptors, direct owner modules,
   protocol modules, docs, compatibility files, or roadmap state.
10. Record implementation notes after the test change, including any omitted
    timeout coverage and the exact verification commands run.

### Verification

Required focused check:

```sh
printf 'HealthcheckSpec.healthcheckAppServerThreadInspectionTests\n:quit\n' | cabal repl watcher-core-test
```

Required full checks:

```sh
cabal test watcher-core-test
cabal build all
git diff --check
git diff --cached --check
```

Diff guards:

```sh
git diff --name-only -- src app agent-workflow-core agent-workflow-codex agent-workflow-github
git diff --exit-code -- moifold.cabal cabal.project agent-workflow-core/agent-workflow-core.cabal agent-workflow-codex/agent-workflow-codex.cabal agent-workflow-github/agent-workflow-github.cabal
git diff --exit-code -- src/CodexWatcher/Healthcheck.hs src/CodexWatcher/AppServerClient.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs agent-workflow-codex/src/CodexWatcher/AppServerProtocol.hs
test ! -e orchestrator/rounds/round-116/worker-plan.json
```

Expected changed implementation paths are limited to:

```text
test/HealthcheckSpec.hs
test/Main.hs
```

If a minimal shared test helper is truly required, the only additional
acceptable test-support path is:

```text
test/TestSupport/Workflow.hs
```

State and review-record checks:

```sh
jq -e '
  .roadmap_id == "2026-05-11-00-highest-value-cleanup" and
  .roadmap_revision == "rev-001" and
  .roadmap_update == null and
  .active_round_id == "round-116" and
  ([.active_rounds[]
    | select(
        .round_id == "round-116" and
        .extracted_item_id == "round-116-healthcheck-appserver-thread-inspection-coverage" and
        .worker_mode == "none" and
        .merge_ready == false
      )] | length == 1)
' orchestrator/state.json

jq -e '
  .roadmap_id == "2026-05-11-00-highest-value-cleanup" and
  .roadmap_revision == "rev-001" and
  .roadmap_dir == "orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001" and
  .milestone_id == "milestone-003-import-convergence-package-boundaries" and
  .direction_id == "direction-010-appserverclient-import-convergence" and
  .extracted_item_id == "round-116-healthcheck-appserver-thread-inspection-coverage" and
  .decision == "approved"
' orchestrator/rounds/round-116/review-record.json
```

This verification does not approve production import migration, public facade
exposure changes, Cabal/API/docs cleanup, deprecation, removal, runtime
compatibility-file changes, milestone completion, or terminal roadmap
completion.
