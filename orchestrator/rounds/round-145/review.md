### Checks Run
- Command: `if rg -n "^import CodexWatcher\\.AppServerClient\\b" test/WorkflowDocsMigrationSpec.hs; then echo "unexpected selected-file AppServerClient import remains"; exit 1; else echo "selected file no longer imports CodexWatcher.AppServerClient"; fi`
  Result: pass; output was `selected file no longer imports CodexWatcher.AppServerClient`.
- Command: `rg -n "^import CodexWatcher\\.Workflow\\.Agent\\.Codex\\.Client \\(AppServerTurn \\(\\.\\.\\)\\)" test/WorkflowDocsMigrationSpec.hs`
  Result: pass; found `23:import CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn (..))`.
- Command: `rg -n "workflowDocsMigrationAgentRoleClassifiesCompleteOutput|workflowDocsMigrationTests|AppServerTurn" test/WorkflowDocsMigrationSpec.hs`
  Result: pass; found the exported `workflowDocsMigrationTests`, the preserved test-list entry, the direct owner import, and the `AppServerTurn` constructor use at the classification assertion.
- Command: `rg -n "CodexWatcher\\.AppServerClient" src app test docs agent-workflow-core agent-workflow-codex agent-workflow-github examples *.cabal cabal.project 2>/dev/null || true`
  Result: pass for inventory; remaining users are out of scope for this round: `moifold.cabal`, `src/CodexWatcher/AppServerClient.hs`, several other test modules/helpers, and docs policy/readiness/release files. The selected file is no longer listed.
- Command: `git diff -- test/WorkflowDocsMigrationSpec.hs`
  Result: pass; the selected test diff is a one-line import replacement from `CodexWatcher.AppServerClient` to `CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn (..))`.
- Command: `git diff --name-only`
  Result: pass; tracked diff lists only `orchestrator/state.json` and `test/WorkflowDocsMigrationSpec.hs`.
- Command: `cabal test watcher-core-test`
  Result: pass; `Test suite watcher-core-test: PASS`, `1 of 1 test suites (1 of 1 test cases) passed`.
- Command: `cabal build all`
  Result: pass; output was `Up to date`.
- Command: `git diff --check`
  Result: pass; no whitespace errors.
- Command: `git diff --cached --check`
  Result: pass; no staged whitespace errors.

### Plan Compliance
- Confirm selected-file facade import and `AppServerTurn` use: met; the selected file now has no `CodexWatcher.AppServerClient` import and still contains the `AppServerTurn` use in `workflowDocsMigrationAgentRoleClassifiesCompleteOutput`.
- Replace only the selected import with the direct owner import: met; `git diff -- test/WorkflowDocsMigrationSpec.hs` shows only the import replacement.
- Leave `workflowDocsMigrationAgentRoleClassifiesCompleteOutput`, `workflowDocsMigrationTests`, and test bodies unchanged: met; search evidence confirms the names remain reachable, and the diff does not alter test bodies.
- Avoid all out-of-scope files and surfaces: met; tracked implementation/test/package/docs/public facade changes are limited to the selected test import plus orchestrator state, with round artifacts under `orchestrator/rounds/round-145`.
- Record broad remaining `CodexWatcher.AppServerClient` users without migrating them: met; the broad scan still reports out-of-scope users and no additional migrations were made.

### Decision
**APPROVED**

### Evidence
The integrated result matches the selected scope. `test/WorkflowDocsMigrationSpec.hs` no longer imports the `CodexWatcher.AppServerClient` compatibility facade and imports `AppServerTurn (..)` from `CodexWatcher.Workflow.Agent.Codex.Client` instead. The selected test-file diff is import-only.

The remaining `CodexWatcher.AppServerClient` references are in explicitly out-of-scope surfaces: the public compatibility facade itself, Cabal exposure, other tests/test helpers, and docs/policy/readiness files. This review does not claim public facade deprecation or removal, Cabal exposure cleanup, docs cleanup, package descriptor cleanup, milestone completion, release approval, terminal completion, or public compatibility removal.

Baseline verification passed with `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and `git diff --cached --check`.
