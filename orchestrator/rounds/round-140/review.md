### Checks Run
- Command: `git status --short`
  Result: pass; before review artifacts, tracked changes were `orchestrator/state.json` and `test/TestSupport/AppServer.hs`, with untracked round-140 artifacts.
- Command: `git diff --name-only`
  Result: pass; tracked diff is limited to `orchestrator/state.json` and `test/TestSupport/AppServer.hs`.
- Command: `git diff -- test/TestSupport/AppServer.hs`
  Result: pass; the implementation diff is exactly one import replacement from `CodexWatcher.AppServerClient (AppServerEndpoint (..))` to `CodexWatcher.Workflow.Agent.Codex.Transport (AppServerEndpoint (..))`.
- Command: `sed -n '1,220p' test/TestSupport/AppServer.hs`
  Result: pass; helper exports remain `withEndpointBackedAppServer`, `jsonRpcResult`, and `jsonRpcError`, and request recording, server startup, endpoint construction, initialize handling, notification handling, JSON-RPC helpers, and cleanup code are unchanged.
- Command: `rg -n 'AppServerEndpoint' agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs`
  Result: pass; the direct owner module exports `AppServerEndpoint (..)` and still defines/uses the endpoint type.
- Command: `rg -n 'CodexWatcher\.AppServerClient|AppServerEndpoint' test/TestSupport/AppServer.hs`
  Result: pass; selected file has no `CodexWatcher.AppServerClient` match, has the direct owner `AppServerEndpoint (..)` import, and still uses `AppServerEndpoint` in the helper type and endpoint construction.
- Command: `rg -n 'withEndpointBackedAppServer|jsonRpcResult|jsonRpcError|AppServerEndpoint "127\.0\.0\.1" port "/"' test/TestSupport/AppServer.hs`
  Result: pass; helper exports and `AppServerEndpoint "127.0.0.1" port "/"` construction remain present.
- Command: `rg -n 'CodexWatcher\.AppServerClient' src app test docs *.cabal cabal.project agent-workflow-core agent-workflow-codex agent-workflow-github 2>/dev/null || true`
  Result: pass; `test/TestSupport/AppServer.hs` is no longer in the broad facade scan. Remaining hits are out-of-scope public facade/Cabal exposure, docs and policy text, policy tests, and other test imports.
- Command: `git diff --cached --name-only`
  Result: pass; no staged changes.
- Command: `git diff --check`
  Result: pass; no whitespace errors.
- Command: `git diff --cached --check`
  Result: pass; no staged whitespace errors.
- Command: `cabal test watcher-core-test`
  Result: pass; `Test suite watcher-core-test: PASS`, 1 of 1 test suites passed.
- Command: `cabal build all`
  Result: pass; build reported `Up to date`.

### Plan Compliance
- Confirm starting point and migrate only `test/TestSupport/AppServer.hs`: met; the only non-orchestrator implementation path changed is `test/TestSupport/AppServer.hs`.
- Replace the exact `CodexWatcher.AppServerClient (AppServerEndpoint (..))` import with `CodexWatcher.Workflow.Agent.Codex.Transport (AppServerEndpoint (..))`: met; the old import is absent and the direct owner import is present.
- Preserve helper exports: met; the module export list still contains only `withEndpointBackedAppServer`, `jsonRpcResult`, and `jsonRpcError`.
- Preserve endpoint-backed fake app-server behavior: met; the diff changes only the import line, and the helper still records requests, starts the websocket server, handles initialize and notifications, constructs JSON-RPC result/error values, and cleans up the server thread.
- Preserve endpoint construction: met; `AppServerEndpoint "127.0.0.1" port "/"` remains unchanged.
- Remove selected file from broad AppServerClient facade import scan: met; broad scan no longer includes `test/TestSupport/AppServer.hs`.
- Leave remaining AppServerClient imports out of scope: met; remaining broad-scan hits are public facade/exposure, docs/policy, policy tests, and other tests outside this selected slice.
- Do not edit production files, other tests/test-support files, public `CodexWatcher.AppServerClient` facade, direct owner exports, package descriptors, docs/policy, public deprecation/removal, or Cabal exposure cleanup: met; changed-path and diff review show none of those surfaces changed.
- Active roadmap and project-contract baseline: met; the round records lineage for `2026-05-11-00-highest-value-cleanup` / `rev-001`, stays inside milestone 003 direction 010 import convergence, keeps public compatibility facades available, and passes all required baseline checks.

### Decision
**APPROVED**

### Evidence
The integrated round is the selected one-file AppServerClient import convergence slice. `test/TestSupport/AppServer.hs` now imports `AppServerEndpoint (..)` from `CodexWatcher.Workflow.Agent.Codex.Transport`; the exact old `CodexWatcher.AppServerClient (AppServerEndpoint (..))` import is gone.

The implementation diff changes only that import line. The module export list, `withEndpointBackedAppServer`, `jsonRpcResult`, `jsonRpcError`, request recording, websocket server setup, initialize response handling, notification handling, response dispatch, open-port discovery, wait loop, and `AppServerEndpoint "127.0.0.1" port "/"` construction are unchanged.

The direct owner module exports `AppServerEndpoint (..)`. A focused scan confirms the selected file has no `CodexWatcher.AppServerClient` reference and still uses `AppServerEndpoint` at the direct owner import, helper type, and endpoint construction. The broad AppServerClient scan no longer lists `test/TestSupport/AppServer.hs`; remaining hits are out-of-scope public facade/Cabal exposure, docs/policy, policy tests, and other test imports.

No production files, other tests or test-support files, public facade modules, direct owner exports, package descriptors, docs/policy files, public deprecation/removal surfaces, or Cabal exposure cleanup changed. `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and `git diff --cached --check` all passed.
