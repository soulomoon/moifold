### Changes Made
- `test/Main.hs`: replaced the remaining exact `import CodexWatcher.AppServerClient` facade import with direct owner imports for `AppServerTurn (..)`, `AppServerClientFailure (..)`, `AppServerInterpreter (..)`, and `AppServerEndpoint (..)`. Kept `CodexWatcher.AppServerProtocol` imported for `AppServerRequest`.
- `test/Main.hs`: tightened the existing `CodexWatcher.ActionExecutor` import list so `AppServerInterpreter` is supplied by its direct owner module instead of through the `ActionExecutor` re-export; this is still import-only and was required by `-Werror=unused-imports`.
- `orchestrator/rounds/round-151/implementation-notes.md`: recorded the scoped import migration, validation evidence, remaining facade references, and explicit non-approval boundaries.

### Tests
- `test/Main.hs`: no test bodies, helper definitions, options, pragmas, assertions, or failure messages changed; existing watcher-core-test coverage remains the validation target for the migrated imports.

### Validation Results
- `rg -n '^import CodexWatcher\.AppServerClient$' test/Main.hs`: passed with no matches.
- `rg -n '^import CodexWatcher\.Workflow\.Agent\.Codex\.(Client|Transport|Interpreter)|^import CodexWatcher\.AppServerProtocol' test/Main.hs`: passed; found `CodexWatcher.AppServerProtocol` plus the three direct owner imports. The client import also names `AppServerClientFailure (..)` for the existing `AppServerTransportFailure` constructor use.
- `rg -n 'AppServerEndpoint|AppServerTurn|AppServerInterpreter|AppServerRequest' test/Main.hs`: passed; symbol anchors remain present in imports and existing test code.
- `rg -n 'AppServerEndpoint|AppServerTurn|AppServerInterpreter|AppServerRequest|AppServerTransportFailure' test/Main.hs`: passed after the compile-driven client import adjustment.
- `rg -n 'module CodexWatcher\.Workflow\.Agent\.Codex\.Client|AppServerTurn|AppServerClientFailure|AppServerTransportFailure' agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs`: passed; owner module exports/defines `AppServerTurn`, `AppServerClientFailure`, and `AppServerTransportFailure`.
- `rg -n 'module CodexWatcher\.Workflow\.Agent\.Codex\.Transport|AppServerEndpoint' agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs`: passed; owner module exports/defines `AppServerEndpoint`.
- `rg -n 'module CodexWatcher\.Workflow\.Agent\.Codex\.Interpreter|AppServerInterpreter' agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Interpreter.hs`: passed; owner module exports/defines `AppServerInterpreter`.
- `rg -n '^import CodexWatcher\.AppServerClient$|CodexWatcher\.AppServerClient' src app test moifold.cabal docs`: passed for this round's expectation; no remaining exact source/app/test import of the facade. Remaining hits are the facade module, Cabal exposure, docs, and `test/BoundaryPolicySpec.hs` policy strings.
- `git diff -- test/Main.hs`: passed; import-only diff in `test/Main.hs`.
- `git diff --name-only`: showed `orchestrator/state.json` and `test/Main.hs`; `orchestrator/state.json` was pre-existing and not edited by this implementer.
- `cabal test watcher-core-test`: passed after two compile-only import adjustments. The first attempt exposed the existing `AppServerTransportFailure` constructor use; the second exposed the redundant `ActionExecutor` re-export of `AppServerInterpreter`.
- `cabal build all`: passed.
- `git diff --check`: passed.

### Remaining Out-Of-Scope Facade Users
- `src/CodexWatcher/AppServerClient.hs`: compatibility facade remains available.
- `moifold.cabal`: exposed-module entry remains unchanged.
- `test/BoundaryPolicySpec.hs`: policy-string references remain unchanged.
- `docs/agentic-workflow-framework/*`: compatibility/deprecation/readiness documentation references remain unchanged.

### Non-Approval Boundary
This round is import convergence only. It does not approve deprecation, facade removal, Cabal exposed-module cleanup, docs cleanup, public API cleanup, package publication, milestone completion, or compatibility-surface removal.

### Notes
- No production code, Cabal, docs, policy strings, state, selection, plan, review, merge, roadmap, or other tests were intentionally edited.
- `orchestrator/state.json` was already modified before this implementer pass and is outside this round's write ownership.
