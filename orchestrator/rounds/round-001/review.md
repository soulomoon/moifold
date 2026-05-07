### Checks Run
- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`.

- Command: `cabal test watcher-core-test`
  Result: pass. `watcher-core-test` built and ran successfully: `Test suite watcher-core-test: PASS`; `1 of 1 test suites (1 of 1 test cases) passed.`

- Command: `git diff --check`
  Result: pass. No whitespace errors reported.

- Command: `git diff --cached --check`
  Result: pass. No staged whitespace errors reported; `git diff --cached --name-only` also had no output.

- Command: `rg -n "executeWorkflowCheckedActionsOf|WorkflowCheckedActionFailure|workflowCheckedActionFailureReports" agent-workflow-core/src/CodexWatcher/Workflow/Execution/Core.hs src/CodexWatcher/Workflow/Execution.hs test/Main.hs`
  Result: pass. Output shows the core export/definition in `agent-workflow-core/src/CodexWatcher/Workflow/Execution/Core.hs`, facade imports and adapter usage in `src/CodexWatcher/Workflow/Execution.hs`, and focused test coverage in `test/Main.hs`.

- Command: `rg -n "CodexWatcher.ActionExecutor|CodexWatcher.Runtime.Command|CodexWatcher.Failure|ActionExecutionReport|CommandReport|PlannedAction" agent-workflow-core/src/CodexWatcher/Workflow/Execution/Core.hs`
  Result: pass after concrete-boundary inspection. The only matches were existing generic `WorkflowPlannedActionOf` identifiers and fields in the core module; there were no concrete moifold imports, no `ActionExecutionReport`, no `CommandReport`, and no concrete `PlannedAction` type references.

- Command: `rg -n "\b(CodexWatcher\.ActionExecutor|CodexWatcher\.Runtime\.Command|CodexWatcher\.Failure|ActionExecutionReport|CommandReport|PlannedAction)\b" agent-workflow-core/src/CodexWatcher/Workflow/Execution/Core.hs`
  Result: pass. No exact-token forbidden concrete imports or type mentions were reported.

- Command: `rg -n "executeWorkflowCheckedActions|daemonFailureFromWorkflowActionFailure|DaemonActionFailed|observedDaemonTickExecuteCommandFailureDoesNotAppendEvent" src/CodexWatcher/Workflow/Execution.hs src/CodexWatcher/Daemon.hs test/Main.hs`
  Result: pass. Output shows `executeWorkflowCheckedActions` remains in the moifold facade, daemon execution still routes failures through `daemonFailureFromWorkflowActionFailure`, `DaemonActionFailed` remains the daemon failure shape, and the observed daemon failure regression test is still present.

- Command: `rg -n "workflowCoreCabalSublibraryKeepsPackageBoundary|workflowExecutionCoreCheckedActionsStopsOnFirstFailure|workflowExecutionCheckedActionsStopsOnHardFailure|observedDaemonTickExecuteCommandFailureDoesNotAppendEvent|workflowExecutionMetadataPartitionPreservesLegacyOrdering|workflowExecutionMetadataDryRunMatchesLegacy" test/Main.hs`
  Result: pass. Output shows the package-boundary test, new core checked-action traversal test, moifold facade hard-failure test, observed daemon failure test, metadata ordering test, and dry-run parity test are included in the `watcher-core-test` source.

- Command: `sed -n '28,76p' moifold.cabal`
  Result: pass. `agent-workflow-core` still exposes `CodexWatcher.Workflow.Execution.Core` and depends only on `base`, `bytestring`, and `text` in that section.

- Command: `git diff --name-only`
  Result: pass. The integrated implementation diff is limited to `agent-workflow-core/src/CodexWatcher/Workflow/Execution/Core.hs`, `src/CodexWatcher/Workflow/Execution.hs`, `test/Main.hs`, and the orchestrator state selecting this active round.

### Plan Compliance
- Step 1: met. `WorkflowCheckedActionFailureOf` is added and exported from `agent-workflow-core/src/CodexWatcher/Workflow/Execution/Core.hs` with failed action, failed report, prior reports, and failure reason fields.
- Step 2: met. `executeWorkflowCheckedActionsOf` is added and exported with a generic runner, classifier, action list, and `Either` result.
- Step 3: met. `workflowCheckedActionFailureReports` is added and preserves prior reports followed by the failed report; the traversal is left-to-right and short-circuits on first classified failure.
- Step 4: met. `src/CodexWatcher/Workflow/Execution.hs` keeps `executeWorkflowCheckedActions` as the moifold-facing name and delegates to `executeWorkflowCheckedActionsOf` with the existing executor path and hard-failure classifier.
- Step 5: met. `CommandReport`, `FailureClassification`, `HardFailure`, external-failure classification, command-report extraction, and concrete moifold types remain in the facade rather than moving into `agent-workflow-core`.
- Step 6: met. `src/CodexWatcher/Daemon.hs` is unchanged; `runDaemonTickWithEvents` and `executeMoifoldWorkflowActions` still call the facade and map through `daemonFailureFromWorkflowActionFailure`.
- Step 7: met. No dry-run code or fixtures changed. Existing dry-run parity tests passed in `watcher-core-test`.
- Step 8: met. `test/Main.hs` adds `workflowExecutionCoreCheckedActionsStopsOnFirstFailure`, strengthens `workflowExecutionCheckedActionsStopsOnHardFailure`, and keeps the observed daemon failure test in the suite.
- Step 9: met. The package-boundary assertion now rejects concrete executor/runtime/failure/report/action dependencies by exact source tokens, and `moifold.cabal` already exposes the core module without a Cabal edit.
- Step 10: met. The production diff does not touch event codecs, golden fixtures, daemon result types, dry-run rendering, compiled action ordering, partitioning, or daemon code.

### Decision
**APPROVED**

### Evidence
The active round identity in `orchestrator/state.json` and `selection.md` matches `roadmap_id` `2026-05-07-00-workflow-kernel-indexing`, `roadmap_revision` `rev-001`, `roadmap_dir` `orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-001`, and `roadmap_item_id` `item-001-checked-action-failure-core`.

The core extraction is generic: `agent-workflow-core/src/CodexWatcher/Workflow/Execution/Core.hs` imports only `Data.List`, exposes the new generic failure/traversal/report-projection API, and has no exact-token references to forbidden moifold concrete imports or types.

The compatibility path is preserved: the moifold facade still exports and implements `executeWorkflowCheckedActions` and `workflowActionFailureReports`, while daemon failure conversion remains in `src/CodexWatcher/Daemon.hs` and continues to map command failures to `DaemonActionFailed`.

The required baseline checks all passed, and the focused `watcher-core-test` source includes the new core traversal test plus the existing facade, daemon, metadata-ordering, package-boundary, and dry-run parity coverage required by the plan.
