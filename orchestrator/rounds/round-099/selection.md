### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-011-core-ids-import-convergence`
- Extracted item id: `round-099-workflow-execution-agent-id-import-convergence`
- Extracted item summary: Move the agent-id-only `src/CodexWatcher/Workflow/Execution.hs` import from the combined `CodexWatcher.Core.Ids` compatibility facade to the direct owner `CodexWatcher.Workflow.Agent.Ids`, preserving request-id propagation, effect compilation, action partitioning, dry-run output, and execution behavior while leaving all public facade exposure unchanged.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: the single source import convergence in `src/CodexWatcher/Workflow/Execution.hs` for the `RequestId` type already classified by round 097 as agent-only; confirming the module still compiles through the direct owner dependency already available to the library; preserving existing workflow execution semantics and focused watcher-core coverage.
- Out of scope: `app/Main.hs`, `src/CodexWatcher/Core/State.hs`, `test/WorkflowDocsMigrationSpec.hs`, and all combined `CodexWatcher.Core.Ids` users; `AppServerClient`, `Workflow.EventLog`, and `Workflow.Permission` convergence; constructor, parser, renderer, command-output, prompt, fixture, event-schema, runtime-state, healthcheck, repair, replay, restart, dry-run, or action-order behavior changes; package descriptor changes unless the planner proves the selected source import cannot compile without one; Cabal exposed-module changes for compatibility facades; deprecation, migration, removal, release, milestone-completion, or terminal-completion claims.
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
Milestone 003 is dependency-ready because it depends only on the completed test-topology inventory. Direction 009 is complete, and round 098 already proved the first direction-011 single-domain `Core.Ids` migration pattern by moving `test/BoundaryPolicySpec.hs` to `CodexWatcher.Workflow.GitHub.Ids` without behavior or package-exposure changes.

Round 097 classifies `src/CodexWatcher/Workflow/Execution.hs` as a safe agent-only direct-owner candidate with observed `RequestId` use. This is the smallest valuable next source slice: it is narrower than `src/CodexWatcher/Core/State.hs`, avoids the executable dependency impact likely needed for `app/Main.hs`, and carries more package-boundary value than another test-only move from `test/WorkflowDocsMigrationSpec.hs`.

The selected slice keeps import convergence separate from public compatibility action. `CodexWatcher.Core.Ids` remains exposed, combined users remain blocked on later parser, renderer, prompt, output, runtime-config, and fixture evidence, and no deprecation or removal is implied.
