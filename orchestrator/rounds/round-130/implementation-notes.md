### Changes Made
- `test/WorkflowDocsMigrationSpec.hs`: removed the exact `CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog` facade import.
- `test/WorkflowDocsMigrationSpec.hs`: added direct owner imports `CodexWatcher.Workflow.Audit qualified as WorkflowAudit` and `CodexWatcher.Workflow.EventLog.Core qualified as WorkflowEventLogCore`.
- `test/WorkflowDocsMigrationSpec.hs`: moved replay, fixture-contract, and replay-failure helper calls to `WorkflowEventLogCore`; moved audit accessor calls to `WorkflowAudit`.

### Tests
- `printf ':module + WorkflowDocsMigrationSpec\nworkflowDocsMigrationTests\n:quit\n' | cabal repl watcher-core-test`: passed; GHCi loaded `WorkflowDocsMigrationSpec`, all DocsMigration assertions printed `PASS`, and the aggregate returned `True`.
- `cabal test watcher-core-test`: passed; `Test suite watcher-core-test: PASS`, `1 of 1 test suites (1 of 1 test cases) passed`.
- `cabal build all`: passed; built and linked the `moifold` executable.
- `git diff --check`: passed with no output.
- `git diff --cached --check`: passed with no output.
- `! rg -n '^import\s+CodexWatcher\.Workflow\.EventLog($|\s+(qualified|as|\(|hiding))' test/WorkflowDocsMigrationSpec.hs`: passed with no output.
- `! rg -n 'WorkflowEventLog\.' test/WorkflowDocsMigrationSpec.hs`: passed with no output.
- `rg -n '^import\s+CodexWatcher\.Workflow\.(Audit|EventLog\.Core|EventLog\.Commit\.Core|EventLog\.File\.Core)' test/WorkflowDocsMigrationSpec.hs`: found the expected direct owner imports at lines 80, 85, 86, and 87.
- `rg -n '^import\s+CodexWatcher\.Workflow\.EventLog($|\s+(qualified|as|\(|hiding))' src app test`: no `test/WorkflowDocsMigrationSpec.hs` match; remaining out-of-scope exact facade imports are in `test/WorkflowExecutionSpec.hs`, `test/FacadeImportPolicySpec.hs`, `test/WorkflowEventLogSpec.hs`, `test/Main.hs`, and `test/WorkflowIndexedSpec.hs`.
- `rg -n 'CodexWatcher\.Workflow\.EventLog' src app test docs *.cabal agent-workflow-*`: confirmed selected-file matches are direct owner imports only; remaining exact facade references are public exposure/facade, policy/docs, Cabal exposure, and out-of-scope tests.
- `git diff -- test/WorkflowDocsMigrationSpec.hs`: reviewed; diff is import and qualifier replacement only.
- `git diff --unified=0 -- test/WorkflowDocsMigrationSpec.hs`: reviewed; zero-context diff is import and qualifier replacement only.
- `git diff -- test/WorkflowDocsMigrationSpec.hs | rg 'WorkflowEventLog|WorkflowEventLogCore|WorkflowAudit|workflowAudit|replayWorkflowEventLogDetailed|validateEventLogFixtureContract|workflowReplayFailure|docs-migration-|schemaVersion|docsMigrationEventLogFixture|workflowDocsMigrationTests'`: reviewed; only expected EventLog/Core/Audit qualifier replacement lines appeared.
- `git status --short`: showed pre-existing `M orchestrator/state.json`, this round's `M test/WorkflowDocsMigrationSpec.hs`, and untracked `orchestrator/rounds/round-130/`.

### Notes
- No production `src` or `app` files, package descriptors, docs, public facade modules, runtime compatibility files, selection, plan, roadmap files, or `orchestrator/state.json` were edited by this implementation.
- `orchestrator/state.json` was already modified before implementation and was left untouched.
