### Selected Extraction
- Milestone: Core.Ids Test And Fixture Import Burndown
- Milestone id: `milestone-004-core-ids-test-and-fixture-import-burndown`
- Direction id: `direction-011h-core-ids-workflow-test-imports`
- Extracted item id: `direction-011h-workflow-eventlog-spec-core-ids-import`
- Extracted item summary: Migrate `test/WorkflowEventLogSpec.hs` from the `CodexWatcher.Core.Ids` facade import to direct id-owner imports while preserving existing event-log assertions, fixture checks, PASS labels, and aggregate wiring.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-002`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-002`

### Boundaries
- In scope: update only `CodexWatcher.Core.Ids` import ownership in `test/WorkflowEventLogSpec.hs`; keep event JSON expectations, replay behavior, fixture contracts, assertion text, PASS labels, and test-suite wiring unchanged.
- Out of scope: migrate `test/WorkflowAgentSpec.hs`, `test/WorkflowExecutionSpec.hs`, `test/WorkflowIndexedSpec.hs`, runtime/CLI tests, `test/Main.hs`, `test/FacadeImportPolicySpec.hs`, source modules, docs, Cabal exposure, public facade deprecation/removal, runtime compatibility cleanup, fixture data changes, and policy/aggregator classification.
- Concurrent batch context: none. The active state is serial (`max_parallel_rounds = 1`), and the roadmap authorizes one workflow test family per round for this direction.

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
Milestone 004 is dependency-ready because milestone 003 is completed and round 187 left the remaining `Core.Ids` users classified as workflow specs, runtime/CLI tests, policy/aggregator candidates, the public facade, docs, and Cabal exposure. Direction 011h is the next sequencing point because the shared workflow test support import was migrated in round 187, leaving the individual workflow specs as the smallest safe follow-up queue.

`test/WorkflowEventLogSpec.hs` is the smallest remaining workflow spec and contains event-log replay and fixture-contract coverage that should keep its behavior assertions isolated from larger workflow execution and indexed-workflow slices. Selecting only this file advances test import convergence without implying public facade removal, Cabal/docs cleanup, runtime compatibility cleanup, or milestone completion.
