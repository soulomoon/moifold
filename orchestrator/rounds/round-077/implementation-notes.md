### Changes Made
- `src/CodexWatcher/AutomaticLoop/IssuePlanningFanout.hs`: replaced endpoint-only `CodexWatcher.AppServerClient` import with `CodexWatcher.Workflow.Agent.Codex.Transport`.
- `src/CodexWatcher/AutomaticLoop/PrReviewHandoff.hs`: replaced endpoint-only `CodexWatcher.AppServerClient` import with `CodexWatcher.Workflow.Agent.Codex.Transport`.
- `src/CodexWatcher/Cli/Command/RunnerGuard.hs`: replaced endpoint-only `CodexWatcher.AppServerClient` import with `CodexWatcher.Workflow.Agent.Codex.Transport`.
- `src/CodexWatcher/Cli/Command/Service.hs`: replaced endpoint-only `CodexWatcher.AppServerClient` import with `CodexWatcher.Workflow.Agent.Codex.Transport`.
- `src/CodexWatcher/Cli/Parser/Common.hs`: replaced endpoint-only `CodexWatcher.AppServerClient` import with `CodexWatcher.Workflow.Agent.Codex.Transport`.
- `src/CodexWatcher/Cli/Types.hs`: replaced endpoint-only `CodexWatcher.AppServerClient` import with `CodexWatcher.Workflow.Agent.Codex.Transport`.
- `src/CodexWatcher/Healthcheck/Types.hs`: replaced endpoint-only `CodexWatcher.AppServerClient` import with `CodexWatcher.Workflow.Agent.Codex.Transport`.
- `test/CliSpec.hs`: replaced endpoint-only `CodexWatcher.AppServerClient` import with `CodexWatcher.Workflow.Agent.Codex.Transport`.
- `src/CodexWatcher/AutomaticLoop/StartupThreads.hs`: replaced `formatAppServerClientFailure` facade import with `CodexWatcher.Workflow.Agent.Codex.Client`.
- `src/CodexWatcher/DaemonLoop.hs`: replaced `formatAppServerClientFailure` facade import with `CodexWatcher.Workflow.Agent.Codex.Client`.
- `src/CodexWatcher/DaemonLoop/Types.hs`: replaced `AppServerClientFailure` and `AppServerTurn` facade imports with `CodexWatcher.Workflow.Agent.Codex.Client`.
- `src/CodexWatcher/Failure.hs`: replaced `AppServerClientFailure` and `JsonRpcError` facade imports with `CodexWatcher.Workflow.Agent.Codex.Client`.
- `src/CodexWatcher/Workflow/DocsMigration.hs`: replaced `AppServerTurn` facade import with `CodexWatcher.Workflow.Agent.Codex.Client`.
- `src/CodexWatcher/Workflow/Moifold/PrReview/Agent.hs`: replaced `AppServerTurn` facade import with `CodexWatcher.Workflow.Agent.Codex.Client`.
- `test/AppServerSpec.hs`: split the former facade import into direct owner imports from `CodexWatcher.Workflow.Agent.Codex.Client` for parsing, failure, fallback, and turn APIs, and `CodexWatcher.Workflow.Agent.Codex.Transport` for request sessions and interpreter-backed thread start.

### Tests
- `test/AppServerSpec.hs`: continues to cover app-server request rendering, initialized/session behavior, response matching, request-id mismatch, JSON-RPC failures, materialization fallback, thread system-error parsing, thread/turn id parsing, thread read turn parsing, and interpreter-backed thread start through direct owner imports.
- `test/CliSpec.hs`: continues to cover CLI endpoint parsing through the direct transport endpoint type.
- `rg -n "^import (qualified )?CodexWatcher\\.AppServerClient\\b" src app test agent-workflow-* examples`: starting inventory found 28 facade imports; final inventory found 13 remaining facade imports.
- `rg -n "CodexWatcher\\.Workflow\\.Agent\\.Codex\\.(Client|Transport)" src test`: confirmed the selected files now import the direct owner modules.
- `cabal test watcher-core-test`: passed.
- `cabal build all`: passed.
- `git diff --check`: passed.

### Notes
Remaining `CodexWatcher.AppServerClient` imports after this round are deferred broad import sites outside the selected explicit-import slice:

- `test/Main.hs`
- `src/CodexWatcher/RunnerGuard.hs`
- `src/CodexWatcher/Domain/PrReview/TurnClassifier.hs`
- `src/CodexWatcher/Domain/PrReview/LaunchCli.hs`
- `src/CodexWatcher/Domain/IssuePlanning/TurnClassifier.hs`
- `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`
- `src/CodexWatcher/Turn/Classifier/Common.hs`
- `src/CodexWatcher/Healthcheck.hs`
- `src/CodexWatcher/Cli/Command/AppServerProbe.hs`
- `src/CodexWatcher/AutomaticLoop/Runner.hs`
- `src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`
- `src/CodexWatcher/Cli/Command/IssueFanout.hs`
- `src/CodexWatcher/Cli/Command/Observe.hs`

`src/CodexWatcher/AppServerClient.hs`, Cabal files, docs, README, runtime compatibility files, event schemas, healthcheck/repair behavior, deprecation/removal state, and Cabal exposure state were not edited. The compatibility facade remains live and unchanged.
