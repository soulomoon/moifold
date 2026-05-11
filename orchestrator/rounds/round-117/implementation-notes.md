### Changes Made
- `src/CodexWatcher/Healthcheck.hs`: removed the `CodexWatcher.AppServerClient` facade import and imported the currently used AppServer client/transport symbols directly from `CodexWatcher.Workflow.Agent.Codex.Client` and `CodexWatcher.Workflow.Agent.Codex.Transport`.

### Tests
- `printf 'HealthcheckSpec.healthcheckAppServerThreadInspectionTests\n:quit\n' | cabal repl watcher-core-test`: passed; the focused Healthcheck app-server thread inspection checks still cover request id `9001`, configured thread id, `includeTurns = True`, skip paths, JSON-RPC failure formatting, and decode failure formatting.
- `cabal test watcher-core-test`: passed.
- `cabal build all`: passed.
- `git diff --check`: passed.
- `git diff --cached --check`: passed.
- Import scans from the plan: passed for `src/CodexWatcher/Healthcheck.hs`.
- Forbidden-path diff guards: passed; no forbidden owner modules, protocol files, package descriptors, tests, docs, app files, or other production files were changed.
- `test ! -e orchestrator/rounds/round-117/worker-plan.json`: passed.
- State checks: roadmap id/revision, controller stage, active round id, worker mode, merge readiness, and roadmap item matched. The live role state is `implement`; the plan's literal `stage == "plan"` predicate returned `false` after dispatch, so I reran the same predicate with `stage == "implement"` and it passed. Review-record/roadmap-update jq check passed.
- Remaining `CodexWatcher.AppServerClient` inventory: other source users remain in `Domain/PrReview/LaunchCli.hs`, `Domain/IssuePlanning/Loop.hs`, `AutomaticLoop/Runner.hs`, `Cli/Command/Observe.hs`, and `Cli/Command/IssueFanout.hs`; tests, docs, and `moifold.cabal` still reference or expose the facade as expected and were not changed.

### Notes
This round is import-only. I did not change Healthcheck bodies, request construction, timeout override, skip reasons, latest-turn reporting, failure formatting, tests, docs, package descriptors, owner modules, protocol modules, state, or roadmap files.
