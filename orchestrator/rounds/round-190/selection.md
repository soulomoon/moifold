### Selected Extraction
- Milestone: Core.Ids Test And Fixture Import Burndown
- Milestone id: `milestone-004-core-ids-test-and-fixture-import-burndown`
- Direction id: `direction-011h-core-ids-workflow-test-imports`
- Extracted item id: `direction-011h-workflow-execution-spec-core-ids-import`
- Extracted item summary: Migrate `test/WorkflowExecutionSpec.hs` from the `CodexWatcher.Core.Ids` facade import to direct id-owner imports while preserving existing workflow execution assertions, fixtures, PASS labels, and aggregate wiring.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-002`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-002`

### Boundaries
- In scope: update only `CodexWatcher.Core.Ids` import ownership in `test/WorkflowExecutionSpec.hs`; keep workflow execution behavior, event/replay expectations, runtime command rendering expectations, fixture values, assertion text, PASS labels, and test-suite wiring unchanged.
- Out of scope: migrate `test/WorkflowIndexedSpec.hs`, runtime/CLI tests, `test/Main.hs`, `test/FacadeImportPolicySpec.hs`, source modules, docs, Cabal exposure, public facade deprecation/removal, runtime compatibility cleanup, fixture data changes, milestone completion, and policy/aggregator classification.
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
Milestone 004 is dependency-ready because milestone 003 is completed and the active roadmap records that remaining `Core.Ids` users are test/fixture, policy/aggregator, docs, Cabal, or public-facade surfaces rather than production users. Rounds 187, 188, and 189 already migrated the shared workflow test support helper, `test/WorkflowEventLogSpec.hs`, and `test/WorkflowAgentSpec.hs`, leaving `test/WorkflowExecutionSpec.hs` and `test/WorkflowIndexedSpec.hs` as the remaining direction-011h workflow specs.

`test/WorkflowExecutionSpec.hs` is the smallest remaining workflow spec by line count and is a bounded one-file import migration. Selecting it now continues the workflow-spec queue at the same dependency depth while keeping the larger indexed workflow spec, runtime/CLI tests, policy/aggregator classification, and all public compatibility cleanup for later selected rounds.
