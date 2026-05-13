### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-010-appserverclient-import-convergence`
- Extracted item id: `round-151-main-appserverclient-direct-owner-import-migration`
- Extracted item summary: Migrate the remaining exact source/test import of `CodexWatcher.AppServerClient` in `test/Main.hs` to direct Codex app-server owner imports, preserving test bodies and leaving public compatibility surfaces exposed.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: edit only `test/Main.hs` to replace `import CodexWatcher.AppServerClient` with direct owner imports for the symbols it still uses: `CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn (..))`, `CodexWatcher.Workflow.Agent.Codex.Transport (AppServerEndpoint (..))`, and `CodexWatcher.Workflow.Agent.Codex.Interpreter (AppServerInterpreter (..))`; keep existing `CodexWatcher.AppServerProtocol` coverage for `AppServerRequest`.
- Out of scope: no test-body rewrites, helper moves, production changes, facade deletion, Cabal exposed-module changes, docs or policy edits, `test/BoundaryPolicySpec.hs` policy-string changes, `src/CodexWatcher/AppServerClient.hs` changes, package descriptor cleanup, deprecation pragma, public API cleanup, milestone completion, terminal completion, or public compatibility removal.
- Concurrent batch context: none. The active controller state has `max_parallel_rounds: 1`, and this one-file import migration should run serially after round 150.

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
Round 150 removed a stale `CodexWatcher.AppServerClient` import from `test/WorkflowExecutionSpec.hs`, and the live scan now leaves `test/Main.hs` as the only exact source/test import of that facade. Current `test/Main.hs` still uses AppServerClient-owned symbols, so stale-import deletion would be wrong; a direct-owner import migration is the smallest lawful removal-enabling slice under direction 010.

This selection follows the roadmap preference for concrete migration/removal-enabling work over readiness-only artifacts while respecting the remaining gates. It reduces internal facade dependence without implying deprecation or removal: `moifold.cabal`, `src/CodexWatcher/AppServerClient.hs`, docs, and `test/BoundaryPolicySpec.hs` policy references remain exposed for later exact gate rounds.

Expected validation: run focused scans proving `test/Main.hs` no longer imports `CodexWatcher.AppServerClient`, proving `test/Main.hs` still references only the direct-owner mapped symbols above, and proving the broad exact `CodexWatcher.AppServerClient` source/test import scan has no remaining `src`, `app`, or `test` importers except policy strings and the facade module itself. Because this touches test code, also run `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and `git diff --cached --check` if staging occurs.
