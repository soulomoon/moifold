### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-012-eventlog-permission-bridge-split-readiness`
- Extracted item id: `round-131-main-audit-eventlog-direct-owner-import-convergence`
- Extracted item summary: Migrate only legacy `test/Main.hs` daemon audit assertions off the exact `CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog` compatibility-facade import by using the direct `CodexWatcher.Workflow.Audit` owner module for existing audit accessors and daemon recommendations.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

```json
{
  "roadmap_id": "2026-05-11-00-highest-value-cleanup",
  "roadmap_revision": "rev-001",
  "roadmap_dir": "orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001",
  "milestone_id": "milestone-003-import-convergence-package-boundaries",
  "direction_id": "direction-012-eventlog-permission-bridge-split-readiness",
  "extracted_item_id": "round-131-main-audit-eventlog-direct-owner-import-convergence"
}
```

### Boundaries
- In scope: `test/Main.hs` only; replace the exact `CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog` import and the local `WorkflowEventLog.` audit accessor/recommendation use sites with `CodexWatcher.Workflow.Audit` direct-owner references; preserve all existing assertions, helper definitions, test aggregation, daemon audit behavior, event schemas, golden fixture behavior, and public facade availability.
- Out of scope: production `src` or `app` files; `test/FacadeImportPolicySpec.hs`, `test/WorkflowEventLogSpec.hs`, `test/WorkflowIndexedSpec.hs`, `test/WorkflowExecutionSpec.hs`, and any other test/support EventLog references; any `CodexWatcher.Workflow.Permission` import migration; `CodexWatcher.Workflow.EventLog` or `CodexWatcher.Workflow.Permission` facade modules; public facade deprecation/removal; `moifold.cabal` or other package descriptors; Cabal exposure cleanup; docs/policy changes; runtime compatibility files; event JSON `type` fields; golden fixture shape changes; release approval; milestone completion; terminal completion; or public compatibility removal.
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
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 012 remains in progress after rounds 127 through 130. The current base commit already contains the production EventLog convergence work plus the first test/support removals and the DocsMigration spec migration. Live scans now show the remaining exact EventLog facade imports are test-side behavior or policy users, with no known production source exact EventLog facade importer left.

This selects another concrete migration slice rather than a readiness-only gate. Legacy `test/Main.hs` is a small audit-accessor-only candidate: its remaining `WorkflowEventLog.` uses are daemon audit field accessors and `WorkflowDaemonContinue`, all owned by `CodexWatcher.Workflow.Audit`, and it does not need replay/fixture/core transition changes. The policy-sensitive facade tests and EventLog contract specs stay visible for later exact selections because they intentionally exercise facade or mixed EventLog behavior.

This selection continues the round-129 and round-130 steering correction by reducing a real remaining internal EventLog facade use while preserving compatibility surfaces and leaving larger or facade-policy-sensitive migrations for later reviewed rounds.
