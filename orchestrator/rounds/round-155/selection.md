### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-011-core-ids-import-convergence`
- Extracted item id: `round-155-observe-command-spec-core-ids-split-import-migration`
- Extracted item summary: Migrate only `test/ObserveCommandSpec.hs` from the combined `CodexWatcher.Core.Ids` compatibility facade to direct GitHub-id and agent-id owner imports for its existing `RepoName`, `ThreadId`, `TurnId`, and `unThreadId` uses, preserving observe-command dry-run and app-server execution coverage while leaving public compatibility surfaces exposed.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: edit only `test/ObserveCommandSpec.hs` to replace `CodexWatcher.Core.Ids (RepoName (..), ThreadId (..), TurnId (..), unThreadId)` with direct owner imports from `CodexWatcher.Workflow.GitHub.Ids` for `RepoName (..)` and `CodexWatcher.Workflow.Agent.Ids` for `ThreadId (..), TurnId (..), unThreadId`; preserve existing observe execute, dry-run, configured-endpoint, planner-thread, event-log, and app-server request assertions.
- Out of scope: production changes, test-body rewrites, helper moves, package descriptor cleanup, public facade deletion or deprecation, Cabal exposed-module changes, docs or policy-string edits, `CodexWatcher.Core.Ids` facade changes, `CodexWatcher.AppServerClient` facade/Cabal/docs cleanup, broader `Core.Ids` migration, runtime compatibility cleanup, milestone completion, terminal completion, release approval, or public compatibility removal.
- Concurrent batch context: none. The active controller state has `max_parallel_rounds: 1`, and this one-file migration should run serially after round 154.

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
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 011 remains in progress after round 154 migrated one newly exposed combined test user off `CodexWatcher.Core.Ids`. The operator objected to selecting more readiness-only gates, and the live import scan still shows many `CodexWatcher.Core.Ids` users, so a concrete direct-owner migration is the highest-value lawful next slice.

`test/ObserveCommandSpec.hs` is a small split-import candidate: it imports `RepoName` from the GitHub-id side and `ThreadId`, `TurnId`, and `unThreadId` from the agent-id side through `CodexWatcher.Core.Ids`. The direct owner modules export those names, and `watcher-core-test` already depends on both `agent-workflow-github` and `agent-workflow-codex`, so no package descriptor change is expected. This is removal-enabling import convergence rather than readiness-only gate work, while facade parity, public exposure, downstream, deprecation, and removal decisions remain reserved for later exact gates.
