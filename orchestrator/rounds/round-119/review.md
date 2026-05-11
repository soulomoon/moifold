### Checks Run
- Command: `printf 'ObserveCommandSpec.observeCommandTests\n:quit\n' | cabal repl watcher-core-test`
  Result: pass. GHCi loaded the watcher-core-test suite and `ObserveCommandSpec.observeCommandTests` returned `True`; PASS lines covered execute without endpoint failure, dry-run without endpoint success, execute with configured fake app-server session, planner `turn/start` traffic, and empty stderr on successful paths.
- Command: `cabal test watcher-core-test`
  Result: pass. The full `watcher-core-test` suite passed, including the observe-once assertions.
- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`.
- Command: `git diff --check`
  Result: pass. No whitespace errors.
- Command: `git diff --cached --check`
  Result: pass. No staged whitespace errors.
- Command: `! rg -n 'import CodexWatcher\.AppServerClient' src/CodexWatcher/Cli/Command/Observe.hs`
  Result: pass. No `CodexWatcher.AppServerClient` import remains in `Observe.hs`.
- Command: `rg -n 'CodexWatcher\.Workflow\.Agent\.Codex\.Transport.*appServerInterpreterFromEndpoint|appServerInterpreterFromEndpoint|defaultAppServerClientOptions' src/CodexWatcher/Cli/Command/Observe.hs`
  Result: pass. `Observe.hs` imports `appServerInterpreterFromEndpoint` and `defaultAppServerClientOptions` from `CodexWatcher.Workflow.Agent.Codex.Transport`, and the existing call site still uses both symbols.
- Command: `git diff -- src/CodexWatcher/Cli/Command/Observe.hs | rg --pcre2 -n '^[-+](?!import |$)' || true`
  Result: pass after manual inspection. The command reported only diff metadata headers and the multi-line import-list additions; the full diff shows no body changes.
- Command: `git diff -- src/CodexWatcher/Cli/Command/Observe.hs`
  Result: pass. Manual inspection shows an import-only diff: remove `import CodexWatcher.AppServerClient`, add the direct `CodexWatcher.Workflow.Agent.Codex.Transport` import, and preserve all non-import lines.
- Command: `git diff --name-only -- . ':!src/CodexWatcher/Cli/Command/Observe.hs' ':!orchestrator/rounds/round-119/plan.md' ':!orchestrator/rounds/round-119/selection.md' ':!orchestrator/state.json'`
  Result: pass. No paths printed.
- Command: `git diff --name-only -- src/CodexWatcher/AppServerClient.hs src/CodexWatcher/ActionExecutor.hs src/CodexWatcher/AppServerProtocol.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Interpreter.hs src/CodexWatcher/Domain/PrReview/LaunchCli.hs src/CodexWatcher/Domain/IssuePlanning/Loop.hs src/CodexWatcher/AutomaticLoop/Runner.hs src/CodexWatcher/Cli/Command/IssueFanout.hs docs runtime fixtures app test`
  Result: pass. No forbidden production, protocol, facade, direct-owner, docs, runtime, fixture, app, test, or other-importer paths printed.
- Command: `git diff --name-only -- '*.cabal' 'package.yaml' 'cabal.project*'`
  Result: pass. No package descriptor paths printed.
- Command: `rg -n 'import CodexWatcher\.AppServerClient' src app test docs agent-workflow-codex agent-workflow-core agent-workflow-github examples moifold.cabal cabal.project 2>/dev/null || true`
  Result: pass. Remaining facade imports are the expected out-of-scope users: `src/CodexWatcher/Domain/PrReview/LaunchCli.hs`, `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`, `src/CodexWatcher/AutomaticLoop/Runner.hs`, `src/CodexWatcher/Cli/Command/IssueFanout.hs`, and test/test-support imports. `Observe.hs` is absent; standalone package candidates/examples have no facade imports.
- Command: `rg -n 'CodexWatcher\.AppServerClient' src app test docs agent-workflow-codex agent-workflow-core agent-workflow-github examples moifold.cabal cabal.project 2>/dev/null || true`
  Result: pass. The facade remains available and exposed via `moifold.cabal`, docs still describe it as a compatibility facade, and no standalone package candidate/example import was reported.
- Command: `rg -n 'CodexWatcher\.AppServerClient' agent-workflow-codex/agent-workflow-codex.cabal agent-workflow-core/agent-workflow-core.cabal agent-workflow-github/agent-workflow-github.cabal examples/workflow-package-consumer/workflow-package-consumer.cabal examples/workflow-package-consumer/cabal.project moifold.cabal cabal.project 2>/dev/null || true`
  Result: pass. Only `moifold.cabal` exposes `CodexWatcher.AppServerClient`; reusable package descriptors and the standalone example candidate do not reference it.
- Command: `test ! -e orchestrator/rounds/round-119/worker-plan.json`
  Result: pass. No worker plan exists.
- Command: `jq -e '.roadmap_id == "2026-05-11-00-highest-value-cleanup" and .roadmap_revision == "rev-001" and .controller_stage == "dispatch-rounds" and .active_round_id == "round-119" and (.active_rounds | length) == 1 and .active_rounds[0].round_id == "round-119" and .active_rounds[0].stage == "review" and .active_rounds[0].worker_mode == "none" and .active_rounds[0].merge_ready == false and (.active_rounds[0].roadmap_item_id == "round-119-observe-appserverclient-import-convergence")' orchestrator/state.json`
  Result: pass. The state is at lifecycle stage `review` with the expected roadmap lineage, active round, worker mode, and merge readiness.
- Command: `jq -e '(.review_records == null or (.review_records | type == "object")) and (.roadmap_update == null)' orchestrator/state.json`
  Result: pass. No roadmap update is active.

### Plan Compliance
- Move only `src/CodexWatcher/Cli/Command/Observe.hs` off `CodexWatcher.AppServerClient`: met. `Observe.hs` no longer imports the facade and now directly imports `CodexWatcher.Workflow.Agent.Codex.Transport (appServerInterpreterFromEndpoint, defaultAppServerClientOptions)`.
- Preserve every non-import line in `Observe.hs`: met. The full `Observe.hs` diff is import-only; manual inspection of diff headers/context confirmed no body, behavior, parser, output, endpoint, or dry-run fallback change.
- Keep `AppServerInterpreter (\_ -> pure Null)` unchanged and supplied by `CodexWatcher.ActionExecutor`: met. The expression remains unchanged in `Observe.hs`, and `src/CodexWatcher/ActionExecutor.hs` still re-exports `AppServerInterpreter (..)`.
- Do not edit facade, action executor, protocol, direct owner modules, other importers, docs, tests, fixtures, package descriptors, runtime files, or app code: met. Forbidden diff guards printed no paths.
- Do not create worker fan-out: met. `orchestrator/rounds/round-119/worker-plan.json` does not exist.
- Preserve compatibility facade availability and avoid deprecation/removal claims: met. `CodexWatcher.AppServerClient` remains exposed in `moifold.cabal`; the remaining source/test/docs references are recorded as out of scope for later rounds, not treated as removal approval.

### Decision
**APPROVED**

### Evidence
The round satisfies the import-only migration scope. The only implementation diff is the `Observe.hs` import block: `CodexWatcher.AppServerClient` was removed and direct owner transport imports for `appServerInterpreterFromEndpoint` and `defaultAppServerClientOptions` were added. The focused round-118 observe gate, full `watcher-core-test`, `cabal build all`, whitespace checks, import scans, forbidden diff guards, no-worker check, and review-stage state checks all passed.

Remaining `CodexWatcher.AppServerClient` imports are expected blockers outside this round's scope: PR review launch, issue-planning loop, automatic loop runner, issue fanout, and test/test-support imports. The compatibility facade itself remains exposed and unchanged.
