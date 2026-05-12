### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-012-eventlog-permission-bridge-split-readiness`
- Extracted item id: `round-130-workflow-docs-migration-spec-eventlog-direct-owner-import-convergence`
- Extracted item summary: Migrate only `test/WorkflowDocsMigrationSpec.hs` off the exact `CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog` compatibility-facade import by using direct owner modules for replay/fixture helpers and workflow audit accessors, preserving the existing docs-migration test behavior.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: `test/WorkflowDocsMigrationSpec.hs` only; replace the exact `CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog` import and its local qualified use sites with direct owner imports such as `CodexWatcher.Workflow.EventLog.Core` for replay/fixture/failure helpers and `CodexWatcher.Workflow.Audit` for audit accessors and recommendations; preserve existing DocsMigration assertions, runner exports, test aggregation, direct `WorkflowEventLogCommit` and `WorkflowEventLogFileCore` owner imports, event schemas, fixture behavior, and daemon audit behavior.
- Out of scope: production `src` or `app` files; `test/WorkflowEventLogSpec.hs`, `test/WorkflowIndexedSpec.hs`, `test/WorkflowExecutionSpec.hs`, `test/FacadeImportPolicySpec.hs`, legacy `test/Main.hs`, and other test/support EventLog references; any `CodexWatcher.Workflow.Permission` import migration; `CodexWatcher.Workflow.EventLog` or `CodexWatcher.Workflow.Permission` facade modules; public facade deprecation/removal; `moifold.cabal` or other package descriptors; Cabal exposure cleanup; docs/policy changes; runtime compatibility files; event JSON `type` fields; golden fixture shape changes; release approval; milestone completion; terminal completion; or public compatibility removal.
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
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 012 remains in progress after rounds 127 through 129. The current base commit already contains the production EventLog convergence work and the first test/support unused-import removal; live scans now show the remaining exact EventLog facade imports are behavior-test or policy-test users rather than production users.

This selects a concrete migration slice rather than another readiness-only artifact. `test/WorkflowDocsMigrationSpec.hs` is the smallest next lawful DocsMigration-side test target because its remaining `WorkflowEventLog.` uses are replay/fixture helpers and audit field accessors with direct owner modules already exposed by `agent-workflow-core`; it does not require public facade removal, Cabal exposure changes, docs/policy edits, runtime compatibility-file changes, or Workflow.Permission migration.

This selection continues the round-129 correction by reducing a real remaining internal EventLog facade use while preserving compatibility surfaces and leaving larger or facade-policy-sensitive test migrations for later exact selections.
