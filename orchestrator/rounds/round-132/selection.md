### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-012-eventlog-permission-bridge-split-readiness`
- Extracted item id: `round-132-workflow-execution-audit-eventlog-direct-owner-import-convergence`
- Extracted item summary: Migrate only `test/WorkflowExecutionSpec.hs` off the exact `CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog` compatibility-facade import by using the direct `CodexWatcher.Workflow.Audit` owner module for existing audit accessors and daemon recommendations.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: `test/WorkflowExecutionSpec.hs` only; replace the exact `CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog` import and local `WorkflowEventLog.` audit accessor/recommendation use sites with direct `CodexWatcher.Workflow.Audit` owner references; preserve all existing WorkflowExecution assertions, helper definitions, aggregate wiring, event schemas, transaction behavior, daemon audit behavior, direct `WorkflowEventLogCommit` and `WorkflowEventLogFileCore` owner imports, and public facade availability.
- Out of scope: production `src` or `app` files; `test/FacadeImportPolicySpec.hs`, `test/WorkflowEventLogSpec.hs`, `test/WorkflowIndexedSpec.hs`, `test/Main.hs`, `test/WorkflowDocsMigrationSpec.hs`, and any other test/support EventLog references; policy-sensitive facade parity changes; replay/core helper migration outside the selected file; any `CodexWatcher.Workflow.Permission` migration; `CodexWatcher.Workflow.EventLog` or `CodexWatcher.Workflow.Permission` facade modules; public facade deprecation/removal; `moifold.cabal` or other package descriptors; Cabal exposure cleanup; docs/policy changes; runtime compatibility files; event JSON `type` fields; golden fixture shape changes; release approval; milestone completion; terminal completion; or public compatibility removal.
- Concurrent batch context: none; controller state is serial with `max_parallel_rounds: 1`, so this selection opens one round only.

### Scheduler Fields
```json
{
  "depends_on_round_ids": [],
  "merge_after_item_ids": [],
  "parallel_group": null,
  "merge_ready": false
}
```

### Rationale
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 012 remains in progress after rounds 127 through 131. The active roadmap records that production EventLog facade imports have already been migrated, and the remaining exact EventLog facade imports are limited to four out-of-scope tests: `test/FacadeImportPolicySpec.hs`, `test/WorkflowEventLogSpec.hs`, `test/WorkflowIndexedSpec.hs`, and `test/WorkflowExecutionSpec.hs`.

This selects a concrete behavior-preserving migration slice rather than another readiness-only gate. `test/WorkflowExecutionSpec.hs` is the smallest next lawful non-policy target: its remaining `WorkflowEventLog.` uses are audit field accessors and `WorkflowDaemonRetry`/`WorkflowDaemonStop` recommendation constructors, which belong to the direct `CodexWatcher.Workflow.Audit` owner module already used by the preceding accepted migration slices. It avoids bundling the larger `test/WorkflowIndexedSpec.hs` audit surface and leaves `test/FacadeImportPolicySpec.hs` plus `test/WorkflowEventLogSpec.hs` untouched because they are facade-policy or mixed core/facade behavior sensitive.

This selection continues the rounds 129-131 correction toward actual EventLog facade import removal while preserving public compatibility facades and package exposure until exact reviewed gates approve them. It does not approve public facade removal/deprecation, Cabal exposure removal, public API cleanup, package descriptor cleanup, remaining EventLog facade migration, Workflow.Permission migration, release approval, milestone completion, terminal completion, or public compatibility removal.
