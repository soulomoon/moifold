### Changes Made
- `test/WorkflowExecutionSpec.hs`: removed the stale exact `import CodexWatcher.AppServerClient` line only. No replacement imports, test bodies, helpers, assertions, fixtures, runner wiring, production files, package files, docs, or policy files were changed.

### Tests
- `test/WorkflowExecutionSpec.hs`: no test behavior was changed. Validation is focused on proving the selected file no longer imports or references the `CodexWatcher.AppServerClient` facade or selected AppServerClient-owned symbols, while package-level tests/builds still pass.

### Validation Results
- Passed: `rg -n "^import CodexWatcher\\.AppServerClient$|CodexWatcher\\.AppServerClient" test/WorkflowExecutionSpec.hs` returned no matches.
- Passed: `rg -n "\\b(AppServerTurn|AppServerEndpoint|AppServerClient|AppServerClientError|ClientFailure|clientFailure|parseAppServerEndpoint|renderAppServerEndpoint|withAppServer|sendAppServer|postTurn|appServerSession)\\b" test/WorkflowExecutionSpec.hs` returned no matches.
- Passed with expected out-of-scope matches: `rg -n "^import CodexWatcher\\.AppServerClient$|CodexWatcher\\.AppServerClient" src app test docs moifold.cabal`.
- Passed: `git diff -- test/WorkflowExecutionSpec.hs` shows only the deletion of `import CodexWatcher.AppServerClient`.
- Passed with pre-existing controller artifact noted: `git diff --name-only` lists `orchestrator/state.json` and `test/WorkflowExecutionSpec.hs`; `orchestrator/state.json` was already modified before this implementation slice and was not edited here. The untracked round directory contains round artifacts, including this owned implementation notes file.
- Passed: `cabal test watcher-core-test`.
- Passed: `cabal build all`.
- Passed: `git diff --check`.

### Remaining Out-of-Scope Facade Users
- `moifold.cabal`: exposed-module entry for `CodexWatcher.AppServerClient`.
- `src/CodexWatcher/AppServerClient.hs`: public compatibility facade module.
- `test/Main.hs`: remaining exact import of `CodexWatcher.AppServerClient`.
- `test/BoundaryPolicySpec.hs`: policy/reference strings for `CodexWatcher.AppServerClient`.
- `docs/agentic-workflow-framework/release-candidate-bundle.md`: compatibility facade references.
- `docs/agentic-workflow-framework/package-identity-versioning-contract.md`: compatibility facade reference.
- `docs/agentic-workflow-framework/release-notes.md`: compatibility facade reference.
- `docs/agentic-workflow-framework/package-extraction-readiness.md`: compatibility facade references.
- `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`: compatibility/deprecation policy references.

### Notes
This round does not approve, imply, or perform deprecation, removal, Cabal exposure cleanup, documentation cleanup, API cleanup, public facade removal, production-code migration, policy cleanup, or compatibility-surface cleanup for `CodexWatcher.AppServerClient` or any other facade.
