### Changes Made
- `test/TestSupport/AppServer.hs`: replaced the `CodexWatcher.AppServerClient (AppServerEndpoint (..))` compatibility-facade import with the direct owner import `CodexWatcher.Workflow.Agent.Codex.Transport (AppServerEndpoint (..))`. Helper exports and endpoint-backed fake app-server behavior were left unchanged.

### Tests
- `test/TestSupport/AppServer.hs`: focused scans confirmed the selected file no longer imports `CodexWatcher.AppServerClient`, still imports and uses `AppServerEndpoint`, still exports `withEndpointBackedAppServer`, `jsonRpcResult`, and `jsonRpcError`, and still constructs `AppServerEndpoint "127.0.0.1" port "/"`.
- Broad `CodexWatcher.AppServerClient` scan across `src app test docs *.cabal cabal.project agent-workflow-core agent-workflow-codex agent-workflow-github` confirmed `test/TestSupport/AppServer.hs` is no longer among remaining facade importers. Remaining hits are out-of-scope public facade, Cabal exposure, docs/policy, policy tests, and other test imports.
- `cabal test watcher-core-test`: passed.
- `cabal build all`: passed.
- `git diff --check`: passed.
- `git diff --cached --check`: passed; nothing was staged.

### Notes
No blocker. The implementation diff is limited to `test/TestSupport/AppServer.hs`; the round directory contains orchestrator artifacts, and `orchestrator/state.json` was already modified before this implementer change and was not edited here.
