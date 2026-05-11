### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-011-core-ids-import-convergence`
- Extracted item id: `round-101-app-main-repo-name-import-convergence`
- Extracted item summary: Move the GitHub-id-only `app/Main.hs` import from the combined `CodexWatcher.Core.Ids` compatibility facade to the direct owner `CodexWatcher.Workflow.GitHub.Ids`, preserving CLI healthcheck option conversion while leaving all public facade exposure unchanged.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: the single executable import convergence in `app/Main.hs` for the `RepoName (unRepoName)` accessor already classified by round 097 as a GitHub-only direct-owner candidate; preserving `healthcheckOptionsFromCli` behavior and confirming the executable still compiles through the direct owner dependency already available in the current package graph.
- Out of scope: `test/WorkflowDocsMigrationSpec.hs` and all combined `CodexWatcher.Core.Ids` users; `AppServerClient`, `Workflow.EventLog`, and `Workflow.Permission` convergence; constructor, parser, renderer, command-output, prompt, fixture, event-schema, runtime-state, healthcheck, repair, replay, restart, dry-run, or action-order behavior changes; package descriptor changes unless the planner proves the selected executable import cannot compile without one; Cabal exposed-module changes for compatibility facades; deprecation, migration, removal, release, milestone-completion, or terminal-completion claims.
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
Milestone 003 remains dependency-ready because it depends only on the completed test-topology inventory, and direction 009 supplied the accepted current selected-facade import inventory. Direction 011 is still in progress after rounds 098, 099, and 100: those rounds moved `test/BoundaryPolicySpec.hs`, `src/CodexWatcher/Workflow/Execution.hs`, and `src/CodexWatcher/Core/State.hs` to direct owner modules, but the roadmap still leaves the remaining safe single-domain candidates and combined-user blockers for later slices.

Round 097 classified `app/Main.hs` as a safe GitHub-only direct-owner candidate with observed `RepoName` use. A current import check confirms the selected file still imports only `RepoName (unRepoName)` from `CodexWatcher.Core.Ids`, and the local use is limited to converting the optional healthcheck CLI repo filter into `HealthcheckOptions`. This is the next smallest high-value direction-011 slice because it avoids combined users that require parser, renderer, prompt, output, runtime-config, and fixture evidence while reducing another non-test dependency on the combined compatibility facade.

This selection keeps import convergence separate from public compatibility action. `CodexWatcher.Core.Ids` remains exposed, the remaining test-only agent-id candidate stays for a later narrow round, and no public deprecation, Cabal exposure removal, facade removal, milestone completion, or terminal completion is implied.
