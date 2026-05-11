### Changes Made
- `src/CodexWatcher/Cli/Command/Observe.hs`: replaced the unqualified `CodexWatcher.AppServerClient` compatibility facade import with the direct owner transport import for `appServerInterpreterFromEndpoint` and `defaultAppServerClientOptions`.
- `src/CodexWatcher/Cli/Command/Observe.hs`: preserved all non-import code, including `AppServerInterpreter (\_ -> pure Null)` via the existing `CodexWatcher.ActionExecutor` import.

### Tests
- `printf 'ObserveCommandSpec.observeCommandTests\n:quit\n' | cabal repl watcher-core-test`: passed. The focused observe command coverage returned `True` and printed PASS lines for the execute-without-endpoint failure, dry-run-without-endpoint success, and execute-with-endpoint fake app-server traffic.
- `cabal test watcher-core-test`: passed. The full watcher core test suite passed, including the observe command assertions.
- `cabal build all`: passed.
- `git diff --check`: passed.
- `git diff --cached --check`: passed.
- Target import scan for `src/CodexWatcher/Cli/Command/Observe.hs`: passed. No `import CodexWatcher.AppServerClient` remains, and `CodexWatcher.Workflow.Agent.Codex.Transport` is present with `appServerInterpreterFromEndpoint` and `defaultAppServerClientOptions`.
- Forbidden diff guards: passed. No forbidden direct owner, protocol, facade, package, docs, test, fixtures, runtime, app, or other importer paths were reported by the plan guards; the only implementation code diff is `src/CodexWatcher/Cli/Command/Observe.hs`.
- Import-only diff check: passed using an import-aware diff filter; no non-import code-body changes were found in `Observe.hs`.
- `test ! -e orchestrator/rounds/round-119/worker-plan.json`: passed.
- State lifecycle checks: passed with `.active_rounds[0].stage == "implement"` for the current round lifecycle, while preserving the required roadmap id, revision, controller stage, active round id, worker mode, merge readiness, roadmap item id, and null roadmap update assertions.

### Notes
No worker fan-out was used. No tests, package descriptors, docs, fixtures, direct owner modules, facade modules, protocol modules, runtime compatibility files, app code, or other importers were edited.
