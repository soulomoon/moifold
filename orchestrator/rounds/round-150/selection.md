### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-010-appserverclient-import-convergence`
- Extracted item id: `round-150-workflow-execution-spec-stale-appserverclient-import-removal`
- Extracted item summary: Remove the stale `import CodexWatcher.AppServerClient` line from `test/WorkflowExecutionSpec.hs` only. The current file imports the facade but the selected symbol scan finds no `AppServerTurn`, `AppServerEndpoint`, client failure, formatting, transport, session, or endpoint helper use that would require a replacement direct-owner import.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: one import-only cleanup in `test/WorkflowExecutionSpec.hs`, preserving all test bodies, assertions, helpers, fixtures, runner wiring, behavior, and failure messages.
- Out of scope: `test/Main.hs`, `test/BoundaryPolicySpec.hs` policy strings, `src/CodexWatcher/AppServerClient.hs`, `moifold.cabal`, docs, public facade exposure, Cabal exposed-module cleanup, deprecation wording, direct owner modules, production code, fixtures, runtime compatibility files, and any compatibility removal claim.
- Concurrent batch context: none. The active controller state has `max_parallel_rounds: 1`, so this is a serial extraction with no batch coupling.

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
Milestone 003 is dependency-ready because milestone 001 is completed and direction 010 has accumulated focused AppServerClient import-convergence evidence through round 149. Current live scans after round 149 still show exact `CodexWatcher.AppServerClient` imports in `test/WorkflowExecutionSpec.hs` and `test/Main.hs`, plus policy, facade, Cabal, and docs references that are not removal-ready gates.

This slice should run before public facade, Cabal, docs, or policy cleanup because the active roadmap permits concrete internal import convergence but explicitly keeps the public facade exposed until exact removal gates are satisfied. `test/WorkflowExecutionSpec.hs` is the smallest remaining concrete test importer: it has an exact facade import, but a selected symbol scan finds no AppServerClient-owned symbol use in the file, so the lawful cleanup is to delete the stale import without adding replacement imports or changing behavior. `test/Main.hs` remains broader and should be left for a later selected slice with its own symbol mapping because it still contains visible `AppServerTurn` and `AppServerEndpoint` uses.

Expected validation for the implementation round: focused scans proving `test/WorkflowExecutionSpec.hs` no longer imports `CodexWatcher.AppServerClient` and contains no selected AppServerClient-owned symbol use; a broad `rg -n "^import CodexWatcher\\.AppServerClient$|CodexWatcher\\.AppServerClient" src app test docs moifold.cabal` scan recording the remaining public facade, Cabal, docs/policy, and `test/Main.hs` references; `cabal test watcher-core-test`; `cabal build all`; and `git diff --check`. No staged diff check is required unless the round stages changes.
