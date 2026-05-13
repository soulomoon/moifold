### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-011-core-ids-import-convergence`
- Extracted item id: `round-159-runner-guard-command-core-ids-split-import-migration`
- Extracted item summary: Migrate only `src/CodexWatcher/Cli/Command/RunnerGuard.hs` from the combined `CodexWatcher.Core.Ids` compatibility facade to direct GitHub-id and agent-id owner imports for its existing `RepoName`, `ThreadId`, and `TurnId` uses, preserving runner-guard command rendering and repair-thread reporting while leaving public compatibility surfaces exposed.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: edit only `src/CodexWatcher/Cli/Command/RunnerGuard.hs` to replace `CodexWatcher.Core.Ids (RepoName (..), ThreadId (..), TurnId (..))` with direct owner imports from `CodexWatcher.Workflow.GitHub.Ids (RepoName (..))` and `CodexWatcher.Workflow.Agent.Ids (ThreadId (..), TurnId (..))`; preserve `runWatcherRunnerGuard`, `watcherStartCommand`, `guardStartCommand`, `loopCliCommandArgs`, `unRepoName`, `unThreadId`, and `unTurnId` behavior.
- Out of scope: other CLI command or parser modules, `CodexWatcher.Cli.Types`, runner-guard behavior rewrites, test rewrites, helper moves, package descriptor cleanup, public facade deletion or deprecation, Cabal exposed-module changes, docs or policy-string edits, `CodexWatcher.Core.Ids` facade changes, broader `Core.Ids` migration, runtime compatibility cleanup, milestone completion, terminal completion, release approval, or public compatibility removal.
- Concurrent batch context: none. The active controller state has `max_parallel_rounds: 1`, and this one-file production migration should run serially after round 158.

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
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 011 remains in progress after round 158 migrated `src/CodexWatcher/Cli/Parser/Observe.hs` while many `CodexWatcher.Core.Ids` imports remain. The operator steering asks for concrete migration/removal-enabling code slices over readiness-only gate work when lawful, and this is a bounded production migration under the active direction.

`src/CodexWatcher/Cli/Command/RunnerGuard.hs` currently imports GitHub-owned `RepoName` plus agent-owned `ThreadId` and `TurnId` through the combined compatibility facade. The direct owner modules expose the same constructors and accessors, the main library already depends on both `agent-workflow-github` and `agent-workflow-codex`, and round 157 already moved `test/RunnerGuardSpec.hs` to direct owner imports for the corresponding runner-guard id coverage. This keeps public facade exposure, Cabal cleanup, deprecation, removal, docs, downstream evidence, runtime compatibility cleanup, and terminal decisions reserved for later exact gates.
