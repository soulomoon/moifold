### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-011-core-ids-import-convergence`
- Extracted item id: `round-102-workflow-docs-migration-agent-ids-import-convergence`
- Extracted item summary: Move the agent-id-only `test/WorkflowDocsMigrationSpec.hs` import from the combined `CodexWatcher.Core.Ids` compatibility facade to the direct owner `CodexWatcher.Workflow.Agent.Ids`, preserving docs-migration workflow behavior tests while leaving all public facade exposure unchanged.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: the single test import convergence in `test/WorkflowDocsMigrationSpec.hs` for the agent id types already classified by round 097 as agent-only (`ThreadId` and `TurnId`); preserving the existing docs-migration workflow assertions, replay/application behavior coverage, and watcher-core test reachability; confirming the direct owner module is available through the current test-suite package graph.
- Out of scope: all combined `CodexWatcher.Core.Ids` users; `AppServerClient`, `Workflow.EventLog`, and `Workflow.Permission` convergence; constructor, parser, renderer, command-output, prompt, fixture, event-schema, runtime-state, healthcheck, repair, replay, restart, dry-run, action-order, or docs-migration behavior changes; package descriptor changes unless the planner proves the selected test import cannot compile without one; Cabal exposed-module changes for compatibility facades; public deprecation, migration, facade removal, release/publication, milestone-completion, or terminal-completion claims.
- Concurrent batch context: none; active state is serial with `max_parallel_rounds: 1`, and this selection opens one narrow import-convergence round only.

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
Milestone 003 remains dependency-ready because it depends only on the completed test-topology inventory, and direction 009 supplied the accepted current selected-facade import inventory. Direction 011 is still in progress after rounds 098 through 101 moved the previously selected safe `Core.Ids` candidates in `test/BoundaryPolicySpec.hs`, `src/CodexWatcher/Workflow/Execution.hs`, `src/CodexWatcher/Core/State.hs`, and `app/Main.hs` to direct owner modules.

Round 097 classified `test/WorkflowDocsMigrationSpec.hs` as a safe agent-only direct-owner candidate with observed `ThreadId` and `TurnId` use. A current exact import check confirms that file still imports `CodexWatcher.Core.Ids` and its visible id uses in the file are `ThreadId` and `TurnId`. This is the smallest remaining clearly safe direction-011 slice: it avoids combined users that require parser, renderer, prompt, output, runtime-config, fixture, and command-behavior evidence, while reducing one more dependency on the combined compatibility facade.

This selection keeps import convergence separate from public compatibility action. `CodexWatcher.Core.Ids` remains exposed, all combined users stay for later evidence-backed slices, and no public deprecation, Cabal exposure removal, facade removal, milestone completion, or terminal completion is implied.
