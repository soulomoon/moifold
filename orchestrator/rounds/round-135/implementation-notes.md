### Changes Made
- `test/WorkflowEventLogSpec.hs`: removed the `CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog` compatibility facade import.
- `test/WorkflowEventLogSpec.hs`: replaced the remaining Moifold facade initialize/apply assertions with direct `WorkflowEventLogCore.initializeWorkflowEvent @MoifoldSpec id`, `WorkflowEventLogCore.applyWorkflowEvent @MoifoldSpec id`, and `WorkflowEventLogCore.replayWorkflowEventLogDetailed @MoifoldSpec id` checks.
- `test/WorkflowEventLogSpec.hs`: renamed the local transition-contract test and its two facade-oriented assertion descriptions to describe direct EventLog core replay behavior.

### Tests
- `test/WorkflowEventLogSpec.hs`: preserves EventLog core transition failure checks, detailed replay checks, fixture-contract validation, DocsMigration core checks, event constructors, labels, and watcher-core aggregation while removing selected-file facade calls.
- `rg -n "WorkflowEventLog\\." test/WorkflowEventLogSpec.hs`: passed with expected nonzero exit and no output after edit.
- `rg -n "CodexWatcher\\.Workflow\\.EventLog qualified as WorkflowEventLog" test src app agent-workflow-core agent-workflow-codex agent-workflow-github docs *.cabal`: passed; output was only `test/FacadeImportPolicySpec.hs:21:import CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog`.
- `git diff -- test/FacadeImportPolicySpec.hs`: passed with empty output.
- `cabal test watcher-core-test`: first run failed while compiling `test/WorkflowEventLogSpec.hs` because direct transition effects were compared to replay effect batches; fixed by comparing `[initialEffects, applyEffects]` to replay summary batches. Re-run passed.
- `cabal build all`: passed.
- `git diff --check`: passed.
- `git diff --cached --check`: passed against an empty staged diff; no staging was used.

### Notes
`orchestrator/state.json` was already modified by the active round setup before implementation and was left untouched. `test/FacadeImportPolicySpec.hs` remains the only exact `WorkflowEventLog` facade import owner.
