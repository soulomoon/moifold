### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-012-eventlog-permission-bridge-split-readiness`
- Extracted item id: `round-133-workflow-indexed-audit-eventlog-direct-owner-import-convergence`
- Extracted item summary: Migrate only `test/WorkflowIndexedSpec.hs` off the exact `CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog` compatibility-facade import by using the direct `CodexWatcher.Workflow.Audit` owner module for existing audit accessors and daemon recommendations.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: `test/WorkflowIndexedSpec.hs` only; replace the exact `CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog` import and local `WorkflowEventLog.` audit accessor/recommendation use sites with direct `CodexWatcher.Workflow.Audit` owner references; preserve all existing WorkflowIndexed assertions, helper definitions, aggregate wiring, indexed workflow behavior, event schemas, direct `WorkflowEventLogCommit` and `WorkflowEventLogFileCore` owner imports, and public facade availability.
- Out of scope: production `src` or `app` files; `test/FacadeImportPolicySpec.hs`, `test/WorkflowEventLogSpec.hs`, `test/WorkflowExecutionSpec.hs`, `test/Main.hs`, `test/WorkflowDocsMigrationSpec.hs`, and any other test/support EventLog references; policy-sensitive facade parity changes; mixed core/facade behavior-test rewrites; replay/core helper migration outside the selected file; any `CodexWatcher.Workflow.Permission` migration; `CodexWatcher.Workflow.EventLog` or `CodexWatcher.Workflow.Permission` facade modules; public facade deprecation/removal; `moifold.cabal` or other package descriptors; Cabal exposure cleanup; docs/policy changes; runtime compatibility files; event JSON `type` fields; golden fixture shape changes; release approval; milestone completion; terminal completion; or public compatibility removal.
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
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 012 remains in progress after rounds 127 through 132. The active roadmap records that production EventLog facade imports have already been migrated and that the only remaining exact EventLog facade imports after round 132 are `test/FacadeImportPolicySpec.hs`, `test/WorkflowEventLogSpec.hs`, and `test/WorkflowIndexedSpec.hs`.

This selects the smallest next concrete migration candidate instead of another readiness-only gate. `test/WorkflowIndexedSpec.hs` is now the next lawful audit-owner migration target: its remaining `WorkflowEventLog.` use sites are audit field accessors and the `WorkflowDaemonStop` recommendation constructor, matching the accepted direct-owner pattern from recent behavior-preserving migrations. It also avoids bundling `test/FacadeImportPolicySpec.hs`, which is policy/facade parity sensitive, and `test/WorkflowEventLogSpec.hs`, which remains mixed core/facade behavior-test territory.

This selection continues the concrete EventLog facade import convergence path while preserving public compatibility facades and package exposure until exact reviewed gates approve them. It does not approve public facade removal/deprecation, Cabal exposure removal, public API cleanup, package descriptor cleanup, other EventLog facade migration, Workflow.Permission migration, release approval, milestone completion, terminal completion, or public compatibility removal.
