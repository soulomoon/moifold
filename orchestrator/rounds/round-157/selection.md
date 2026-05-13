### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-011-core-ids-import-convergence`
- Extracted item id: `round-157-runner-guard-spec-core-ids-split-import-migration`
- Extracted item summary: Migrate only `test/RunnerGuardSpec.hs` from the `CodexWatcher.Core.Ids` compatibility facade to direct owner imports for its existing `RepoName`, `RequestId`, `ThreadId`, `TurnId`, `unThreadId`, and `unTurnId` uses, preserving runner-guard active-turn and repair-launch coverage while leaving public compatibility surfaces exposed.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: edit only `test/RunnerGuardSpec.hs` to replace `CodexWatcher.Core.Ids (RepoName (..), RequestId (..), ThreadId (..), TurnId (..), unThreadId, unTurnId)` with direct owner imports from `CodexWatcher.Workflow.GitHub.Ids (RepoName (..))` and `CodexWatcher.Workflow.Agent.Ids (RequestId (..), ThreadId (..), TurnId (..), unThreadId, unTurnId)`; preserve existing runner-guard health, stale-turn, app-server failure, repair-thread launch, request-id, thread-id, turn-id, and endpoint-backed app-server assertions.
- Out of scope: production changes, test-body rewrites, helper moves, package descriptor cleanup, public facade deletion or deprecation, Cabal exposed-module changes, docs or policy-string edits, `CodexWatcher.Core.Ids` facade changes, broader `Core.Ids` migration, runtime compatibility cleanup, milestone completion, terminal completion, release approval, or public compatibility removal.
- Concurrent batch context: none. The active controller state has `max_parallel_rounds: 1`, and this one-file migration should run serially after round 156.

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
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 011 remains in progress after rounds 152 through 156 completed one-file direct-owner migrations while leaving many `CodexWatcher.Core.Ids` import users. The operator objected to more readiness-only gates, and the live import scan still shows concrete `Core.Ids` users, so another bounded migration is the lawful highest-value next slice.

`test/RunnerGuardSpec.hs` is a small split-import candidate: the current file imports GitHub-owned `RepoName` and agent-owned `RequestId`, `ThreadId`, `TurnId`, `unThreadId`, and `unTurnId` through the combined compatibility facade. The direct owner modules expose those names, and `watcher-core-test` already depends on both `agent-workflow-github` and `agent-workflow-codex`, so no package descriptor change is expected. This is removal-enabling import convergence rather than readiness-only inventory, while public facade exposure, Cabal cleanup, deprecation, removal, docs, and downstream decisions remain reserved for later exact gates.
