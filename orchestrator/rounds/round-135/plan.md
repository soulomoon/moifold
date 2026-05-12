### Goal

Remove the remaining exact `CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog` facade import from `test/WorkflowEventLogSpec.hs` while preserving its EventLog core transition, replay, fixture-contract, and watcher-core aggregation coverage. `test/FacadeImportPolicySpec.hs` remains the explicit facade parity owner for the Moifold bridge wrappers.

### Approach

Keep this as a sequential single-file implementation. Do not create `worker-plan.json`; the selected ownership is only `test/WorkflowEventLogSpec.hs`, and fan-out would add coordination risk without reducing scope.

Use `CodexWatcher.Workflow.EventLog.Core qualified as WorkflowEventLogCore` for the remaining Moifold initialization and apply assertions. The two existing comparison points should stop calling the compatibility facade:

- replace `WorkflowEventLog.initializeMoifoldWorkflow initialized` with a direct-core assertion based on `WorkflowEventLogCore.initializeWorkflowEvent @MoifoldSpec id initialized`
- replace `WorkflowEventLog.applyMoifoldWorkflowEvent facadeState noUnresolved` with a direct-core assertion based on `WorkflowEventLogCore.applyWorkflowEvent @MoifoldSpec id coreState noUnresolved`

To keep these assertions meaningful without the facade, compare the direct initialize/apply results against `WorkflowEventLogCore.replayWorkflowEventLogDetailed @MoifoldSpec id` for the same event sequence. For initialize, compare the initialized state domain/phase, effects, and event count against replaying `[initialized]`. For apply, compare the final state domain/phase, accumulated effects, and event count against replaying `[initialized, noUnresolved]`. Preserve the existing failure-transition assertions, DocsMigration core checks, fixture contract checks, event constructors, schema labels, and aggregation wiring.

Do not edit `test/FacadeImportPolicySpec.hs`, production code, package descriptors, docs, fixtures, runtime compatibility files, or facade modules. Do not imply public deprecation, Cabal exposure cleanup, facade removal, milestone completion, terminal completion, or release approval.

### Steps

1. Confirm the current selected-file facade use:
   - `rg -n "WorkflowEventLog\\." test/WorkflowEventLogSpec.hs`
   - Expected before editing: only `WorkflowEventLog.initializeMoifoldWorkflow` and `WorkflowEventLog.applyMoifoldWorkflowEvent`.
2. Inspect the local helper around the remaining calls in `test/WorkflowEventLogSpec.hs` and keep the existing fixture data (`initialized`, `noUnresolved`, DocsMigration events) intact.
3. Edit only `test/WorkflowEventLogSpec.hs`:
   - Remove `import CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog`.
   - Remove the local `moifoldFacadeInitial` binding.
   - Rewrite the Moifold initialize assertion to use only `WorkflowEventLogCore.initializeWorkflowEvent @MoifoldSpec id initialized` and `WorkflowEventLogCore.replayWorkflowEventLogDetailed @MoifoldSpec id [initialized]`.
   - Rewrite the Moifold apply assertion to use only `WorkflowEventLogCore.applyWorkflowEvent @MoifoldSpec id coreState noUnresolved` and `WorkflowEventLogCore.replayWorkflowEventLogDetailed @MoifoldSpec id [initialized, noUnresolved]`.
   - If assertion descriptions mention facade parity, rename only those assertion descriptions so they describe direct EventLog core behavior; do not change workflow event labels or fixture contract labels.
4. Re-scan the selected file:
   - `rg -n "WorkflowEventLog\\." test/WorkflowEventLogSpec.hs`
   - Expected after editing: no matches.
5. Run the exact facade import scan:
   - `rg -n "CodexWatcher\\.Workflow\\.EventLog qualified as WorkflowEventLog" test src app agent-workflow-core agent-workflow-codex agent-workflow-github docs *.cabal`
   - Expected after editing: only `test/FacadeImportPolicySpec.hs`.
6. Confirm the explicit facade parity owner stayed untouched:
   - `git diff -- test/FacadeImportPolicySpec.hs`
   - Expected: empty output.

### Verification

Run these checks from the round-135 worktree:

```sh
rg -n "WorkflowEventLog\\." test/WorkflowEventLogSpec.hs
rg -n "CodexWatcher\\.Workflow\\.EventLog qualified as WorkflowEventLog" test src app agent-workflow-core agent-workflow-codex agent-workflow-github docs *.cabal
git diff -- test/FacadeImportPolicySpec.hs
cabal test watcher-core-test
cabal build all
git diff --check
git diff --cached --check
```

Expected results: selected-file `WorkflowEventLog.` scan is empty; the exact facade import scan reports only `test/FacadeImportPolicySpec.hs`; `git diff -- test/FacadeImportPolicySpec.hs` is empty; watcher-core tests and the full build pass; whitespace checks pass. If nothing is staged, record that `git diff --cached --check` was run against an empty staged diff or was not applicable because staging was not used.
