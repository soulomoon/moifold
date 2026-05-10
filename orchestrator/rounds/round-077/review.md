### Checks Run
- Command: `rg -n "^import (qualified )?CodexWatcher\\.AppServerClient\\b" src app test agent-workflow-* examples`
  Result: pass. Final inventory has 13 remaining `CodexWatcher.AppServerClient` imports, all broad/deferred sites recorded in `implementation-notes.md`.
- Command: `rg -n "CodexWatcher\\.Workflow\\.Agent\\.Codex\\.(Client|Transport)" src test`
  Result: pass. The selected source/test files now import `CodexWatcher.Workflow.Agent.Codex.Client` or `CodexWatcher.Workflow.Agent.Codex.Transport` directly. The compatibility facade still reexports both owners.
- Command: `cabal test watcher-core-test`
  Result: pass. `watcher-core-test` built and ran under `ghc-9.12.2`; the suite ended with `Test suite watcher-core-test: PASS` and `1 of 1 test suites (1 of 1 test cases) passed`.
- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`.
- Command: `git diff --check`
  Result: pass. No whitespace or conflict-marker issues.
- Command: `git diff --cached --check`
  Result: pass. No staged diff issues; no files were staged during review.
- Command: `git diff --name-only -- '*.cabal' 'README*' 'docs/**' 'runtime/**' 'src/CodexWatcher/AppServerClient.hs' 'src/CodexWatcher/EventLog*' 'src/CodexWatcher/Workflow/EventLog*' 'src/CodexWatcher/EventLogRepair.hs' 'src/CodexWatcher/Repair*' 'src/CodexWatcher/Cli/Command/Replay.hs'`
  Result: pass. No package descriptor, docs, README, runtime compatibility, facade module, event-log, or repair-path files changed.
- Command: `git diff -- src/CodexWatcher/Healthcheck/Types.hs src/CodexWatcher/AutomaticLoop/IssuePlanningFanout.hs src/CodexWatcher/AutomaticLoop/PrReviewHandoff.hs`
  Result: pass. The only healthcheck-adjacent and compatibility-write-adjacent changes are import-source replacements for `AppServerEndpoint`; no behavior changed.
- Command: `git diff -G'(deprecated|deprecation|remove-later|removal|preferred import|preferred-import|WARNING|DEPRECATED|event.*type|type\"|healthcheck|repair|compatibilityStateWrites|writeCompatibility)' -- src test app '*.cabal' README.md 'docs/**'`
  Result: pass. No diff hunks introduce deprecation/removal wording, event schema changes, healthcheck/repair behavior changes, or compatibility write changes.

### Plan Compliance
- Confirm starting and final inventory: met. `implementation-notes.md` records 28 starting facade imports and 13 final remaining imports; reviewer final inventory reproduced the 13 remaining imports.
- Endpoint-only source/test imports moved to `CodexWatcher.Workflow.Agent.Codex.Transport`: met. The eight selected endpoint files now import `AppServerEndpoint` from `Transport`.
- Client-value imports moved to `CodexWatcher.Workflow.Agent.Codex.Client`: met. The six selected source files now import `formatAppServerClientFailure`, `AppServerClientFailure`, `JsonRpcError`, or `AppServerTurn` from `Client`.
- `test/AppServerSpec.hs` split away from `CodexWatcher.AppServerClient`: met. It imports parsing/failure/turn APIs from `Client` and session/start-thread APIs from `Transport`, while keeping `CodexWatcher.AppServerProtocol` separate.
- Compile-check changed imports and avoid broadening unrelated sites: met. `cabal test watcher-core-test` and `cabal build all` passed; the remaining 13 facade imports are deferred broad-import sites rather than churned in this slice.
- Record remaining facade imports and compatibility state: met. `implementation-notes.md` lists remaining imports and states that `src/CodexWatcher/AppServerClient.hs`, Cabal files, docs, README, runtime compatibility files, event schemas, healthcheck/repair behavior, deprecation/removal state, and Cabal exposure state were not edited.
- Roadmap lineage and scope: met. The round records roadmap `2026-05-10-00-facade-removal-readiness`, revision `rev-001`, under milestone `milestone-002-internal-import-migration` and direction `direction-003-appserverclient-import-migration`; it does not append work to the closed `2026-05-09-01-compatibility-surface-cleanup` family.

### Decision
**APPROVED**

### Evidence
The integrated diff is behavior-neutral import migration only. Changed files are limited to the selected source/test import sites:

- `src/CodexWatcher/AutomaticLoop/IssuePlanningFanout.hs`
- `src/CodexWatcher/AutomaticLoop/PrReviewHandoff.hs`
- `src/CodexWatcher/AutomaticLoop/StartupThreads.hs`
- `src/CodexWatcher/Cli/Command/RunnerGuard.hs`
- `src/CodexWatcher/Cli/Command/Service.hs`
- `src/CodexWatcher/Cli/Parser/Common.hs`
- `src/CodexWatcher/Cli/Types.hs`
- `src/CodexWatcher/DaemonLoop.hs`
- `src/CodexWatcher/DaemonLoop/Types.hs`
- `src/CodexWatcher/Failure.hs`
- `src/CodexWatcher/Healthcheck/Types.hs`
- `src/CodexWatcher/Workflow/DocsMigration.hs`
- `src/CodexWatcher/Workflow/Moifold/PrReview/Agent.hs`
- `test/AppServerSpec.hs`
- `test/CliSpec.hs`

`src/CodexWatcher/AppServerClient.hs` remains unchanged and live as a compatibility reexport. No `.cabal`, docs, README, runtime compatibility file, event JSON/schema, healthcheck behavior, repair behavior, deprecation pragma, removal decision, or Cabal exposure changed. `test/AppServerSpec.hs` continues to cover request rendering, request sessions, response matching, request-id mismatch, JSON-RPC failures, materialization fallback, thread system-error parsing, thread/turn id parsing, thread-read parsing, and interpreter-backed thread start through direct owner imports.
