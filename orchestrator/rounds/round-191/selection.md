### Selected Extraction
- Milestone: Core.Ids Test And Fixture Import Burndown
- Milestone id: `milestone-004-core-ids-test-and-fixture-import-burndown`
- Direction id: `direction-011h-core-ids-workflow-test-imports`
- Extracted item id: `direction-011h-workflow-indexed-spec-core-ids-import`
- Extracted item summary: Migrate `test/WorkflowIndexedSpec.hs` from the `CodexWatcher.Core.Ids` facade import to direct id-owner imports while preserving existing indexed workflow assertions, fixtures, PASS labels, and aggregate wiring.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-002`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-002`

### Boundaries
- In scope: update only `CodexWatcher.Core.Ids` import ownership in `test/WorkflowIndexedSpec.hs`; keep indexed workflow behavior, event/replay expectations, runtime command expectations, fixture values, assertion text, PASS labels, and test-suite wiring unchanged.
- Out of scope: migrate runtime/CLI tests, `test/Main.hs`, `test/FacadeImportPolicySpec.hs`, source modules, docs, Cabal exposure, public facade deprecation/removal, runtime compatibility cleanup, fixture data changes, milestone completion, terminal closeout, and policy/aggregator classification.
- Concurrent batch context: none. The active state is serial (`max_parallel_rounds = 1`), and direction 011h authorizes one workflow test family per round.

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
Milestone 004 is dependency-ready because milestone 003 is completed and the active roadmap records that no production `CodexWatcher.Core.Ids` import users remain beyond the public facade module. Rounds 187 through 190 migrated `test/TestSupport/Workflow.hs`, `test/WorkflowEventLogSpec.hs`, `test/WorkflowAgentSpec.hs`, and `test/WorkflowExecutionSpec.hs`, leaving `test/WorkflowIndexedSpec.hs` as the remaining direction-011h workflow spec.

Selecting this one file finishes the current workflow-test import lane before moving to direction 011i runtime/CLI tests or direction 011j policy/aggregator classification. It is the smallest remaining valuable extraction within direction 011h and keeps public facade, Cabal/docs, runtime compatibility, milestone completion, and terminal cleanup decisions out of scope.
