### Checks Run
- Command: `git diff -- src/CodexWatcher/Healthcheck.hs`
  Result: pass; diff removes only `import CodexWatcher.AppServerClient` and adds direct owner imports from `CodexWatcher.Workflow.Agent.Codex.Client` and `CodexWatcher.Workflow.Agent.Codex.Transport`.
- Command: `if rg -n '^import CodexWatcher\.AppServerClient\b' src/CodexWatcher/Healthcheck.hs; then exit 1; else exit 0; fi`
  Result: pass; `src/CodexWatcher/Healthcheck.hs` no longer imports the public `CodexWatcher.AppServerClient` facade.
- Command: `rg -n '^import CodexWatcher\.Workflow\.Agent\.Codex\.Client\b' src/CodexWatcher/Healthcheck.hs`
  Result: pass; found direct client owner import at line 35.
- Command: `rg -n '^import CodexWatcher\.Workflow\.Agent\.Codex\.Transport\b' src/CodexWatcher/Healthcheck.hs`
  Result: pass; found direct transport owner import at line 36.
- Command: `printf 'HealthcheckSpec.healthcheckAppServerThreadInspectionTests\n:quit\n' | cabal repl watcher-core-test`
  Result: pass; focused Healthcheck aggregate loaded under GHC 9.12.2 and all thread inspection checks returned `PASS`/`True`, including request id `9001`, configured thread id, `includeTurns = True`, skip paths, JSON-RPC failure formatting, and decode failure formatting.
- Command: `cabal test watcher-core-test`
  Result: pass; `Test suite watcher-core-test: PASS`, `1 of 1 test suites (1 of 1 test cases) passed`.
- Command: `cabal build all`
  Result: pass; command completed with `Up to date`.
- Command: `git diff --check && git diff --cached --check`
  Result: pass; no whitespace errors in unstaged or staged diffs.
- Command: `git diff --name-only -- src/CodexWatcher/AppServerClient.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs src/CodexWatcher/AppServerProtocol.hs '*.cabal' 'package.yaml' 'cabal.project*' test docs app`
  Result: pass; no forbidden owner module, protocol, package descriptor, test, docs, or app path changed.
- Command: `git diff --name-only -- . ':!src/CodexWatcher/Healthcheck.hs' ':!orchestrator/rounds/round-117/plan.md' ':!orchestrator/rounds/round-117/selection.md' ':!orchestrator/rounds/round-117/implementation-notes.md' ':!orchestrator/state.json'`
  Result: pass; no out-of-scope changed paths were reported.
- Command: `test ! -e orchestrator/rounds/round-117/worker-plan.json`
  Result: pass; no worker fan-out artifact exists.
- Command: `rg -n 'CodexWatcher\.AppServerClient' src app test docs`
  Result: pass; remaining source users are outside this slice (`Domain/PrReview/LaunchCli.hs`, `Domain/IssuePlanning/Loop.hs`, `AutomaticLoop/Runner.hs`, `Cli/Command/Observe.hs`, and `Cli/Command/IssueFanout.hs`), with expected test/docs references and the facade module itself still present.
- Command: `rg -n 'CodexWatcher\.AppServerClient' *.cabal`
  Result: pass; `moifold.cabal` still exposes `CodexWatcher.AppServerClient`.
- Command: `jq -e '.roadmap_id == "2026-05-11-00-highest-value-cleanup" and .roadmap_revision == "rev-001" and .controller_stage == "dispatch-rounds" and .stage == "review" and .active_round_id == "round-117" and (.active_rounds | length) == 1 and .active_rounds[0].round_id == "round-117" and .active_rounds[0].stage == "review" and .active_rounds[0].worker_mode == "none" and .active_rounds[0].merge_ready == false and (.active_rounds[0].roadmap_item_id == "round-117-healthcheck-appserverclient-import-convergence")' orchestrator/state.json`
  Result: pass; state lineage matches the active roadmap, review stage, single active round, no worker fan-out, and not merge-ready yet.
- Command: `jq -e '(.review_records == null or (.review_records | type == "object")) and (.roadmap_update == null)' orchestrator/state.json`
  Result: pass; review-record shape is compatible and no roadmap update is active.

### Plan Compliance
- Edit only `src/CodexWatcher/Healthcheck.hs`: met; production diff is limited to that file's import section.
- Remove `import CodexWatcher.AppServerClient`: met; focused import scan returned no facade import in `Healthcheck.hs`.
- Add direct owner imports for currently used client and transport symbols: met; `Healthcheck.hs` imports `AppServerTurn`, `formatAppServerClientFailure`, and `parseThreadReadTurns` from `CodexWatcher.Workflow.Agent.Codex.Client`, and `AppServerClientOptions`, `AppServerEndpoint`, `defaultAppServerClientOptions`, and `sendOneAppServerRequest` from `CodexWatcher.Workflow.Agent.Codex.Transport`.
- Preserve Healthcheck behavior, including `checkAppServerThread`, request id `9001`, `includeTurns = True`, timeout, skip behavior, latest-turn reporting, and failure formatting: met; the diff changes no Healthcheck bodies, and the focused REPL aggregate plus full `watcher-core-test` passed.
- Do not create `orchestrator/rounds/round-117/worker-plan.json`: met; file does not exist.
- Leave source/test/docs/package/protocol/facade/owner modules unchanged outside scope: met; forbidden-path and out-of-scope diff guards returned no paths.
- Keep public `CodexWatcher.AppServerClient` available and do not approve deprecation/removal or milestone completion: met; facade module and Cabal exposure remain present, remaining users are recorded for later rounds, and this review approves only this import convergence item.

### Decision
**APPROVED**

### Evidence
The integrated round matches the selected extraction `round-117-healthcheck-appserverclient-import-convergence` under roadmap `2026-05-11-00-highest-value-cleanup` revision `rev-001`. The only production code change is an import ownership migration in `src/CodexWatcher/Healthcheck.hs`; no code bodies, tests, package descriptors, public facade, direct owner modules, protocol modules, docs, or other importers changed.

The focused Healthcheck app-server inspection aggregate passed in `cabal repl watcher-core-test`, and full `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and `git diff --cached --check` all passed. Remaining `CodexWatcher.AppServerClient` users are intentionally left for later selected rounds, and `moifold.cabal` continues to expose the compatibility facade.
