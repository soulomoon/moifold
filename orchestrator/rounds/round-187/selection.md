### Selected Extraction
- Milestone: Core.Ids Test And Fixture Import Burndown
- Milestone id: `milestone-004-core-ids-test-and-fixture-import-burndown`
- Direction id: `direction-011h-core-ids-workflow-test-imports`
- Extracted item id: `direction-011h-testsupport-workflow-core-ids-import`
- Extracted item summary: Migrate `test/TestSupport/Workflow.hs` from the `CodexWatcher.Core.Ids` facade import to direct `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids` owner imports, preserving the existing helper API and behavior.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-002`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-002`

### Boundaries
- In scope: update only the `CodexWatcher.Core.Ids` import ownership in `test/TestSupport/Workflow.hs`; keep helper exports, fixture values, assertions, PASS labels, and downstream workflow-test behavior unchanged.
- Out of scope: migrate `test/WorkflowAgentSpec.hs`, `test/WorkflowEventLogSpec.hs`, `test/WorkflowExecutionSpec.hs`, `test/WorkflowIndexedSpec.hs`, runtime/CLI tests, `test/Main.hs`, `test/FacadeImportPolicySpec.hs`, source modules, docs, Cabal exposure, public facade deprecation/removal, runtime compatibility cleanup, and policy/aggregator classification.
- Concurrent batch context: none. The active state is serial (`max_parallel_rounds = 1`), and the roadmap only authorizes one workflow test family per round for this direction.

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
Milestone 004 is dependency-ready because milestone 003 is completed and its latest evidence classifies remaining `Core.Ids` users as tests/fixtures, docs, Cabal exposure, or the public facade rather than production code. Direction 011h is the smallest valuable next step because `test/TestSupport/Workflow.hs` is a single shared workflow test-support file that imports the facade directly and supplies helpers consumed by the workflow specs. Moving this helper to direct id-owner imports first reduces facade use in the shared workflow test foundation while leaving behavior assertions and later one-file workflow spec migrations separate and reviewable.
