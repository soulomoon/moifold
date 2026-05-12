### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-012-eventlog-permission-bridge-split-readiness`
- Extracted item id: `round-129-workflow-agent-support-eventlog-import-removal`
- Extracted item summary: Remove only the unused exact `CodexWatcher.Workflow.EventLog` compatibility-facade imports from `test/WorkflowAgentSpec.hs` and `test/TestSupport/Workflow.hs`, preserving the existing workflow test topology and leaving public facade exposure unchanged.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: test/support import cleanup in `test/WorkflowAgentSpec.hs` and `test/TestSupport/Workflow.hs`; remove the exact `CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog` imports only after confirming these files still have no `WorkflowEventLog.` use sites; preserve existing test exports, test aggregation, support helper exports, direct-owner event-log imports, and behavior.
- Out of scope: production `src` or `app` files; `test/WorkflowDocsMigrationSpec.hs`, `test/WorkflowEventLogSpec.hs`, `test/WorkflowIndexedSpec.hs`, `test/WorkflowExecutionSpec.hs`, `test/FacadeImportPolicySpec.hs`, and legacy `test/Main.hs` EventLog references; any `CodexWatcher.Workflow.Permission` import migration; `CodexWatcher.Workflow.EventLog` or `CodexWatcher.Workflow.Permission` facade modules; public facade deprecation/removal; `moifold.cabal` or other package descriptors; Cabal exposure cleanup; docs/policy changes; runtime compatibility files; event JSON `type` fields; golden fixture shapes; release approval; milestone completion; terminal completion; or public compatibility removal.
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
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 012 remains in progress after rounds 127 and 128. The current base commit already contains the production EventLog convergence work for `DocsMigration.hs` and `Daemon.hs`; live scans now show no production exact `CodexWatcher.Workflow.EventLog` facade imports, leaving the remaining exact imports in tests/test support, docs/policy, public facade/exposure, and Cabal exposure.

This selects an actual removal slice rather than another readiness gate. The accepted round-104 readiness artifact classified `test/WorkflowAgentSpec.hs` and `test/TestSupport/Workflow.hs` as import-topology holds with no local qualified `WorkflowEventLog.` references, while later rounds closed the production EventLog subset. Removing those two unused exact EventLog imports is therefore the smallest lawful next step that reduces the remaining facade surface without touching behavior-sensitive workflow specs, public API, Cabal exposure, docs, runtime compatibility, or the still-unapproved `Workflow.Permission` migration.

This selection does not approve public facade removal, Cabal exposure removal, package descriptor cleanup, remaining behavior-test EventLog migration, Workflow.Permission migration, milestone completion, terminal completion, release approval, or public compatibility removal.
