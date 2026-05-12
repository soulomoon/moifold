### Changes Made
- `test/IssueFanoutAppServerSpec.hs`: Replaced the `CodexWatcher.AppServerClient (AppServerEndpoint (..))` compatibility-facade import with the direct owner import `CodexWatcher.Workflow.Agent.Codex.Transport (AppServerEndpoint (..))`.

### Tests
- `test/IssueFanoutAppServerSpec.hs`: Existing issue-fanout app-server assertions were preserved; no test logic or helpers changed.
- Focused scan: `rg -n 'CodexWatcher\.AppServerClient|AppServerEndpoint' test/IssueFanoutAppServerSpec.hs` shows no remaining `CodexWatcher.AppServerClient` import in the selected file and retains the direct owner import plus existing endpoint uses.
- Focused assertion scan: `rg -n 'issueFanoutAppServerTests|issueFanoutExecuteStartsAppServerBackedIssueThreads|issueFanoutChildArgsRenderRootEndpoint|issueFanoutChildArgsRenderNonRootEndpoint|issueFanoutRetainsRetryableCloneFailureContract|issueFanoutChildStartClassificationSourceContract|issueFanoutExecuteFormatsJsonRpcFailure|issueFanoutExecuteFormatsDecodeFailure' test/IssueFanoutAppServerSpec.hs` shows all selected issue-fanout app-server assertions remain reachable.
- Broad facade scan: `rg -n 'CodexWatcher\.AppServerClient' src app test docs *.cabal cabal.project agent-workflow-core agent-workflow-codex agent-workflow-github 2>/dev/null || true` no longer lists `test/IssueFanoutAppServerSpec.hs`; remaining matches are out-of-scope facade, policy, docs, package exposure, and other test references.
- `cabal test watcher-core-test`: passed.
- `cabal build all`: passed.
- `git diff --check`: passed.
- `git diff --cached --check`: passed.

### Notes
No production files, other tests, test support, package descriptors, docs/policy, roadmap files, state.json, or facade modules were edited for this implementation slice. Existing uncommitted orchestrator control-plane files were left in place.
