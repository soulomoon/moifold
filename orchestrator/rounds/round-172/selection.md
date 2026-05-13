### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-011-core-ids-import-convergence`
- Extracted item id: `round-172-runner-guard-core-ids-split-import-migration`
- Extracted item summary: Migrate only `src/CodexWatcher/RunnerGuard.hs` from the `CodexWatcher.Core.Ids` compatibility facade to direct owner imports for its existing `RepoName`, `RequestId`, `ThreadId`, and `TurnId` uses, preserving runner-guard stale-turn checks, repair prompt rendering, app-server request sequencing, replay behavior, and JSON encoding while leaving public compatibility surfaces exposed.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: edit only `src/CodexWatcher/RunnerGuard.hs` to replace `CodexWatcher.Core.Ids (RepoName (..), RequestId (..), ThreadId (..), TurnId (..))` with direct owner imports from `CodexWatcher.Workflow.GitHub.Ids (RepoName (..))` and `CodexWatcher.Workflow.Agent.Ids (RequestId (..), ThreadId (..), TurnId (..))`; preserve `RunnerGuardConfig`, `RunnerGuardRepair`, `checkRunnerGuard`, `startRunnerGuardRepairThread`, `runnerGuardRepairPrompt`, app-server request ids, thread/turn parsing, event-log replay handling, JSON field names, and all function bodies.
- Out of scope: other `Core.Ids` users including CLI, healthcheck, event-log, state-machine, effects, runtime compatibility, issue-planning, issue-implementation, and tests; parser, renderer, serialization, prompt wording, command-output, fixture, replay, state-machine, healthcheck, repair, or runtime compatibility behavior changes; package descriptor cleanup; public facade deletion or deprecation; Cabal exposed-module changes; docs or policy-string edits; `CodexWatcher.Core.Ids` facade changes; broader `Core.Ids` migration; runtime compatibility cleanup; milestone completion; terminal completion; release approval; or public compatibility removal.
- Concurrent batch context: none; controller state has `max_parallel_rounds: 1`, and this is a single serial production import-convergence slice.

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
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 011 remains in progress after round 171 migrated `src/CodexWatcher/Workflow/Moifold/PrReview.hs`. The live production import scan still shows `src/CodexWatcher/RunnerGuard.hs:49` importing `CodexWatcher.Core.Ids (RepoName (..), RequestId (..), ThreadId (..), TurnId (..))`.

This selection follows the operator steering to keep doing concrete removal-enabling migration work instead of another readiness-only or removal-gate-only round while safe production `Core.Ids` direct-owner migrations remain. `RunnerGuard.hs` is a bounded split-import candidate: `RepoName` is owned by `CodexWatcher.Workflow.GitHub.Ids`, while `RequestId`, `ThreadId`, and `TurnId` are owned by `CodexWatcher.Workflow.Agent.Ids`; `CodexWatcher.Core.Ids` only reexports those owner modules. The main library already depends on the direct owner packages, and the selected work should be import-only with no public facade exposure, Cabal, docs, compatibility-file, parser/renderer, event schema, replay, or app-server protocol changes.
