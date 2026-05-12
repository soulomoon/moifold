### Goal
Move only `test/TestSupport/AppServer.hs` off the public `CodexWatcher.AppServerClient` compatibility-facade import for `AppServerEndpoint (..)`, using the direct owner import `CodexWatcher.Workflow.Agent.Codex.Transport (AppServerEndpoint (..))` while preserving the endpoint-backed fake app-server helper behavior and exports.

### Approach
Keep this as a sequential, single-file import convergence round under `orchestrator/project-contract.md`. The selected helper already constructs `AppServerEndpoint` directly and does not depend on other `CodexWatcher.AppServerClient` exports, so the implementation should be a narrow import replacement only.

Do not edit production files, other test or test-support files, `test/FacadeImportPolicySpec.hs`, the public `CodexWatcher.AppServerClient` facade implementation or exports, direct owner exports, package descriptors, docs/policy files, roadmap files, `orchestrator/state.json`, review artifacts, merge artifacts, Cabal exposure, public facade deprecation/removal, release gates, milestone completion, or terminal completion.

No worker fan-out is justified because the scope is one import in one support file with one serial verification path.

### Steps
1. Confirm the starting point in `test/TestSupport/AppServer.hs`:
   - The exact import `CodexWatcher.AppServerClient (AppServerEndpoint (..))` is present.
   - The file exports only `withEndpointBackedAppServer`, `jsonRpcResult`, and `jsonRpcError`.
   - The helper behavior around request recording, server startup, endpoint construction, JSON-RPC result/error construction, initialize handling, notification handling, and cleanup is unchanged before editing.
2. Confirm the direct owner export in `agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs` includes `AppServerEndpoint (..)`.
3. In `test/TestSupport/AppServer.hs`, replace only:
   - `import CodexWatcher.AppServerClient (AppServerEndpoint (..))`
   - with `import CodexWatcher.Workflow.Agent.Codex.Transport (AppServerEndpoint (..))`
4. Do not change any other imports, helper exports, helper names, request-recording logic, websocket server behavior, endpoint values, JSON-RPC response helpers, timeout/retry behavior, or caller-facing API.
5. Run focused selected-file scans and record the results:
   - `rg -n 'CodexWatcher\.AppServerClient|AppServerEndpoint' test/TestSupport/AppServer.hs`
   - Expected: no `CodexWatcher.AppServerClient` match in the selected file, and `AppServerEndpoint` still appears through the direct owner import plus existing type/constructor uses.
   - `rg -n 'withEndpointBackedAppServer|jsonRpcResult|jsonRpcError|AppServerEndpoint "127\.0\.0\.1" port "/"' test/TestSupport/AppServer.hs`
   - Expected: helper exports and endpoint construction remain present.
6. Run broad remaining `CodexWatcher.AppServerClient` import scans over current source, app, tests, docs, package descriptors, and standalone package candidates:
   - `rg -n 'CodexWatcher\.AppServerClient' src app test docs *.cabal cabal.project agent-workflow-core agent-workflow-codex agent-workflow-github 2>/dev/null || true`
   - Record that `test/TestSupport/AppServer.hs` is removed from remaining facade importers.
   - Treat the public facade module definition, Cabal exposure, docs/policy text, policy tests, roadmap text, and other out-of-scope test imports as remaining evidence or future migration targets, not as part of this round.
7. Inspect the diff and confirm the implementation diff is limited to the import replacement in `test/TestSupport/AppServer.hs` plus this `plan.md`, with no changes to production files, other tests/test-support files, package descriptors, docs/policy, roadmap/state artifacts, review artifacts, or merge artifacts.

### Verification
- `cabal test watcher-core-test`
- `cabal build all`
- `git diff --check`
- `git diff --cached --check` if anything is staged
- Focused `test/TestSupport/AppServer.hs` scans proving the old `CodexWatcher.AppServerClient` import is gone and the helper exports plus endpoint construction remain present.
- Broad `CodexWatcher.AppServerClient` import scan proving `test/TestSupport/AppServer.hs` is no longer among remaining facade importers while other out-of-scope facade references are only recorded.
- Diff review confirming this is behavior-preserving import convergence only and does not imply public facade deprecation, removal, Cabal exposure cleanup, milestone completion, terminal completion, or release approval.

### Worker Fan-Out
No worker fan-out. Do not create `worker-plan.json` for this round.
