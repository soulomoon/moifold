### Changes Made
- `src/CodexWatcher/Domain/PrReview/LaunchCli.hs`: replaced the broad `CodexWatcher.AppServerClient` compatibility-facade import with direct owner imports from `CodexWatcher.Workflow.Agent.Codex.Client` and `CodexWatcher.Workflow.Agent.Codex.Transport`. `AppServerEndpoint (..)` is imported from the owner module because the existing code already uses its record selectors through `OverloadedRecordDot`.

### Tests
- No tests were changed; this round is import-only.
- `printf ':load test/PrReviewLaunchCliSpec.hs\nprReviewLaunchCliTests\n:quit\n' | cabal repl watcher-core-test --repl-options=-ignore-dot-ghci`: the preferred focused REPL route was attempted. It first exposed that `AppServerEndpoint` needed its record selectors imported from the direct owner module. After the import fix, GHCi loaded the watcher-core-test modules but the focused `:load` rejected `TestSupport.AppServer` and `TestSupport.Workflow` as missing home modules for interactive reload, so this REPL route was not counted as the focused pass.
- `cabal test watcher-core-test`: passed. The full watcher-core-test suite compiled and ran successfully, including the PR-review launch assertions.
- `cabal build all`: passed.
- `git diff --check`: passed with no output.
- `rg -n '^import CodexWatcher\.AppServerClient' src/CodexWatcher/Domain/PrReview/LaunchCli.hs`: passed with no matches.
- `rg -n '^import CodexWatcher\.Workflow\.Agent\.Codex\.(Client|Transport)' src/CodexWatcher/Domain/PrReview/LaunchCli.hs`: passed, showing:
  - `import CodexWatcher.Workflow.Agent.Codex.Client (formatAppServerClientFailure)`
  - `import CodexWatcher.Workflow.Agent.Codex.Transport (AppServerEndpoint (..), defaultAppServerClientOptions, startThreadWithEndpoint)`
- `git diff --unified=0 -- src/CodexWatcher/Domain/PrReview/LaunchCli.hs`: passed; only the old facade import removal and two direct owner import additions are present.
- `rg -n 'CodexWatcher\.AppServerClient' src app test *.cabal agent-workflow-* docs`: passed for this round's scope. `LaunchCli.hs` no longer appears; remaining hits are the facade module/Cabal exposure, `IssueFanout`, test-policy/test-support imports, and docs, all intentionally out of scope.
- `jq -e '.active_round_id == "round-124" and .stage == "implement" and .active_rounds[0].worker_mode == "none" and .active_rounds[0].round_artifacts.plan == "orchestrator/rounds/round-124/plan.md"' orchestrator/state.json`: passed and printed `true`.
- `test ! -e orchestrator/rounds/round-124/worker-plan.json`: passed.
- `git status --short`: after implementation, shows the controller-owned modified `orchestrator/state.json`, the intended modified `src/CodexWatcher/Domain/PrReview/LaunchCli.hs`, and the untracked round artifact directory containing the plan/selection artifacts plus these implementation notes.

### Notes
The plan's listed transport import did not include `AppServerEndpoint` record selectors, but `LaunchCli.hs` already uses `endpoint.appServerHost`, `endpoint.appServerPort`, and `endpoint.appServerPath`. Importing `AppServerEndpoint (..)` from the owner module keeps the change import-only and preserves all code bodies and behavior.
