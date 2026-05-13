### Findings

No findings. Approved.

### Checks Run

- Command: `git diff -- test/Main.hs`
  Result: pass; the selected implementation diff is import-only in `test/Main.hs`. It removes `import CodexWatcher.AppServerClient`, narrows `CodexWatcher.ActionExecutor` to an explicit import list, and adds direct owner imports for `AppServerTurn`, `AppServerClientFailure`, `AppServerInterpreter`, and `AppServerEndpoint`.
- Command: `git diff --name-only`
  Result: pass; changed paths were `orchestrator/state.json` and `test/Main.hs`. `orchestrator/state.json` is outside implementation scope and was pre-existing reviewer/controller state, while the implementation change is limited to `test/Main.hs`.
- Command: `rg -n '^import CodexWatcher\.AppServerClient$' test/Main.hs`
  Result: pass; no matches.
- Command: `rg -n '^import CodexWatcher\.Workflow\.Agent\.Codex\.(Client|Transport|Interpreter)|^import CodexWatcher\.AppServerProtocol' test/Main.hs`
  Result: pass; found `CodexWatcher.AppServerProtocol`, `CodexWatcher.Workflow.Agent.Codex.Client (AppServerClientFailure (..), AppServerTurn (..))`, `CodexWatcher.Workflow.Agent.Codex.Interpreter (AppServerInterpreter (..))`, and `CodexWatcher.Workflow.Agent.Codex.Transport (AppServerEndpoint (..))`.
- Command: `rg -n 'AppServerEndpoint|AppServerTurn|AppServerInterpreter|AppServerRequest|AppServerTransportFailure|AppServerClientFailure' test/Main.hs`
  Result: pass; symbol anchors remain present in imports and existing test code, including the existing `AppServerTransportFailure` use at the automatic-loop retry assertion.
- Command: `rg -n 'module CodexWatcher\.Workflow\.Agent\.Codex\.Client|AppServerTurn|AppServerClientFailure|AppServerTransportFailure' agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs`
  Result: pass; the direct owner module exports `AppServerClientFailure (..)` and `AppServerTurn (..)`, and defines `AppServerTransportFailure`.
- Command: `rg -n 'module CodexWatcher\.Workflow\.Agent\.Codex\.Transport|AppServerEndpoint' agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs`
  Result: pass; the direct owner module exports and defines `AppServerEndpoint`.
- Command: `rg -n 'module CodexWatcher\.Workflow\.Agent\.Codex\.Interpreter|AppServerInterpreter' agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Interpreter.hs`
  Result: pass; the direct owner module exports and defines `AppServerInterpreter`.
- Command: `rg -n '^import CodexWatcher\.AppServerClient$|CodexWatcher\.AppServerClient' src app test moifold.cabal docs`
  Result: pass for the selected boundary; no remaining exact `src`, `app`, or `test` import of `CodexWatcher.AppServerClient`. Remaining hits are the compatibility facade module, Cabal exposure, policy strings in `test/BoundaryPolicySpec.hs`, and docs references.
- Command: `cabal test watcher-core-test`
  Result: pass; `Test suite watcher-core-test: PASS`, `1 of 1 test suites (1 of 1 test cases) passed`.
- Command: `cabal build all`
  Result: pass; output was `Up to date`.
- Command: `git diff --check`
  Result: pass; no whitespace errors.
- Command: `git diff --cached --check`
  Result: pass; no staged whitespace errors.

### Plan Compliance

- Replace only the remaining exact `test/Main.hs` `CodexWatcher.AppServerClient` import: met. The facade import is gone and the selected file now imports direct owner modules.
- Preserve test bodies, helper declarations, assertions, and failure messages: met. The `test/Main.hs` diff contains only import changes.
- Keep `CodexWatcher.AppServerProtocol` for `AppServerRequest`: met. The import remains present and unchanged.
- Treat compile-required `AppServerClientFailure (..)` / `AppServerTransportFailure` coverage as direct-owner migration, not behavior change: met. `AppServerTransportFailure` is a constructor of `AppServerClientFailure`, whose direct owner is `CodexWatcher.Workflow.Agent.Codex.Client`; importing `AppServerClientFailure (..)` directly is still import-only.
- Tighten `CodexWatcher.ActionExecutor` so `AppServerInterpreter` comes only from its direct owner: met. This removes an incidental re-export source from `ActionExecutor` without changing behavior.
- Leave public facade, Cabal exposure, docs, API/deprecation/removal, and milestone completion out of scope: met. No implementation edits touched those surfaces, and the remaining scan hits are expected compatibility/policy/documentation references.

### Decision

**APPROVED**

### Evidence

Round 151 is a valid import-only direct-owner migration for `round-151-main-appserverclient-direct-owner-import-migration`. The selected file no longer imports the `CodexWatcher.AppServerClient` facade, all used app-server symbols now come from direct owner modules or the existing `CodexWatcher.AppServerProtocol` import, the test diff contains no behavior edits, and the broad facade scan confirms no remaining exact source/app/test facade imports beyond intentional policy strings and compatibility surfaces.

This approval does not claim deprecation, facade removal, Cabal exposure cleanup, docs cleanup, public API cleanup, package publication, milestone completion, or compatibility-surface removal.
