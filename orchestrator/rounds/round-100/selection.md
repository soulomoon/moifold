### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-011-core-ids-import-convergence`
- Extracted item id: `round-100-core-state-github-ids-import-convergence`
- Extracted item summary: Move the GitHub-id-only `src/CodexWatcher/Core/State.hs` import from the combined `CodexWatcher.Core.Ids` compatibility facade to the direct owner `CodexWatcher.Workflow.GitHub.Ids`, preserving typed watcher-state constructors and completion evidence while leaving all public facade exposure unchanged.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: the single source import convergence in `src/CodexWatcher/Core/State.hs` for the GitHub id types already classified by round 097 as GitHub-only (`CommitSha` and `PrNumber`); preserving current `WatcherState`, `CompletionEvidence`, `Eq`/`Show` derivation behavior, and existing watcher-core coverage; confirming the direct owner module is already exposed through the current package graph without descriptor changes.
- Out of scope: `app/Main.hs`, `test/WorkflowDocsMigrationSpec.hs`, and all combined `CodexWatcher.Core.Ids` users; `AppServerClient`, `Workflow.EventLog`, and `Workflow.Permission` convergence; constructor, parser, renderer, command-output, prompt, fixture, event-schema, runtime-state, healthcheck, repair, replay, restart, dry-run, or action-order behavior changes; package descriptor changes unless the planner proves the selected source import cannot compile without one; Cabal exposed-module changes for compatibility facades; deprecation, migration, removal, release, milestone-completion, or terminal-completion claims.
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
Milestone 003 remains dependency-ready because it depends only on the completed test-topology inventory, and direction 009 has supplied the accepted current selected-facade import inventory. Direction 011 is still in progress after rounds 098 and 099: those rounds moved `test/BoundaryPolicySpec.hs` to `CodexWatcher.Workflow.GitHub.Ids` and `src/CodexWatcher/Workflow/Execution.hs` to `CodexWatcher.Workflow.Agent.Ids`, but the roadmap explicitly leaves remaining safe direct-owner candidates and combined-user blockers for later slices.

Round 097 classified `src/CodexWatcher/Core/State.hs` as a safe GitHub-only direct-owner candidate with observed `CommitSha` and `PrNumber` use. A current token scan confirms the selected file still uses only those GitHub ids from the combined facade. This is the next smallest high-value production slice under the active direction: it avoids the combined users that need parser, renderer, prompt, output, runtime-config, and fixture evidence, while reducing another library dependency on the combined `Core.Ids` compatibility facade.

This selection keeps import convergence separate from public compatibility action. `CodexWatcher.Core.Ids` remains exposed, `app/Main.hs` and the remaining test-only agent-id candidate stay for later narrow rounds, and no public deprecation, Cabal exposure removal, facade removal, milestone completion, or terminal completion is implied.
