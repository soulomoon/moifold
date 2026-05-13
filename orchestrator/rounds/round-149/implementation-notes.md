### Changes Made
- `test/WorkflowEventLogSpec.hs`: removed only the now-unused exact `import CodexWatcher.AppServerClient` line. Test bodies, helpers, pragmas, options, fixtures, wiring, and replacement imports were left unchanged.
- `orchestrator/rounds/round-149/implementation-notes.md`: recorded the import-only change, validation, remaining out-of-scope facade users, and round boundaries.

### Tests
- `test/WorkflowEventLogSpec.hs`: no test bodies changed; existing workflow event-log coverage remains reachable through `watcher-core-test`.

### Validation Results
- `rg -n '^import CodexWatcher\.AppServerClient\b' test/WorkflowEventLogSpec.hs`: passed; no matches.
- `rg -n 'AppServerTurn|AppServerEndpoint|AppServerClientFailure|JsonRpcError|formatAppServerClientFailure|AppServerClientOptions|defaultAppServerClientOptions' test/WorkflowEventLogSpec.hs`: passed; no matches.
- `rg -n 'CodexWatcher\.AppServerClient' src app test docs *.cabal agent-workflow-*`: passed as inventory; remaining matches are out of scope for this round:
  - `moifold.cabal`
  - `src/CodexWatcher/AppServerClient.hs`
  - `test/BoundaryPolicySpec.hs`
  - `test/WorkflowExecutionSpec.hs`
  - `test/Main.hs`
  - `docs/agentic-workflow-framework/release-candidate-bundle.md`
  - `docs/agentic-workflow-framework/package-extraction-readiness.md`
  - `docs/agentic-workflow-framework/release-notes.md`
  - `docs/agentic-workflow-framework/package-identity-versioning-contract.md`
  - `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`
- `git diff -- test/WorkflowEventLogSpec.hs`: passed; diff is exactly the single import-line deletion.
- `git diff --name-only`: inspected before notes; implementation code diff was limited to `test/WorkflowEventLogSpec.hs`, with pre-existing `orchestrator/state.json` and round artifacts preserved.
- `git status --short`: inspected before notes; pre-existing `orchestrator/state.json` modification and untracked `orchestrator/rounds/round-149/` were preserved.
- `cabal test watcher-core-test`: passed.
- `cabal build all`: passed when rerun standalone. An earlier parallel invocation collided with the simultaneous test build on `dist-newstyle/packagedb`; this was not a source failure.
- `git diff --check`: passed.

### Notes
This round does not approve, imply, or perform `CodexWatcher.AppServerClient` deprecation, removal, Cabal exposed-module cleanup, documentation cleanup, API cleanup, public facade exposure changes, production-code changes, policy changes, compatibility-file changes, release changes, or roadmap terminal-state changes. Remaining facade users are explicitly out of scope and require later exact selections and reviewed gates.
