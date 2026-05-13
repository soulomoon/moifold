### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-011-core-ids-import-convergence`
- Extracted item id: `round-175-effect-interpreter-core-ids-split-import-migration`
- Extracted item summary: Migrate only `src/CodexWatcher/EffectInterpreter.hs` from the `CodexWatcher.Core.Ids` compatibility facade to direct owner imports for its existing `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, `RepoName`, `RequestId`, `ThreadId`, and `nextRequestId` uses, preserving compiled effect planning, turn runtime configuration, request-id progression, rendered turn input selection, exported API shape, and behavior while leaving public compatibility surfaces exposed.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: edit only `src/CodexWatcher/EffectInterpreter.hs` to replace `CodexWatcher.Core.Ids (BranchName (..), CommitSha, IssueNumber (..), PrNumber (..), RepoName, RequestId, ThreadId, nextRequestId)` with direct owner imports from `CodexWatcher.Workflow.GitHub.Ids (BranchName (..), CommitSha, IssueNumber (..), PrNumber (..), RepoName)` and `CodexWatcher.Workflow.Agent.Ids (RequestId, ThreadId, nextRequestId)`; preserve `CompiledEffectPlan`, `EffectRuntimeConfig`, `PlannedAction`, `TurnRuntimeConfig`, `agentTurnPlanForEffect`, `compileEffect`, `compileEffectPlan`, `issuePlanFileText`, request-id threading, runtime command planning, rendered prompt/input selection, constructors, exports, and all function bodies.
- Out of scope: other `Core.Ids` users including runtime compatibility, state machine, healthcheck, event-log types/replay, golden replay, CLI, issue-planning loop, issue-implementation loop, and tests; parser, renderer, serialization, prompt wording, command-output, fixture, replay, state-machine, healthcheck, repair, runtime compatibility, or behavior changes; package descriptor cleanup; public facade deletion or deprecation; Cabal exposed-module changes; docs or policy-string edits; `CodexWatcher.Core.Ids` facade changes; broader `Core.Ids` migration; runtime compatibility cleanup; milestone completion; terminal completion; release approval; or public compatibility removal.
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
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 011 remains in progress after round 174 migrated `src/CodexWatcher/Workflow/Moifold/IssueImplement/Indexed.hs`. The live production import scan still shows `src/CodexWatcher/EffectInterpreter.hs:20` importing `CodexWatcher.Core.Ids (BranchName (..), CommitSha, IssueNumber (..), PrNumber (..), RepoName, RequestId, ThreadId, nextRequestId)`.

This selection follows the operator steering to keep doing concrete removal-enabling migration work instead of another readiness-only or removal-gate-only round while safe production `Core.Ids` direct-owner migrations remain. `EffectInterpreter.hs` is a bounded split-import candidate: `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, and `RepoName` are owned by `CodexWatcher.Workflow.GitHub.Ids`, while `RequestId`, `ThreadId`, and `nextRequestId` are owned by `CodexWatcher.Workflow.Agent.Ids`; `CodexWatcher.Core.Ids` only reexports those owner modules for this selected import. The adjacent effect-plan type surface already moved to direct owner imports in round 173, the main library already depends on the direct owner packages, and the selected work should be import-only with no parser/renderer, JSON, event schema, replay, prompt wording, command-output, Cabal, docs, compatibility-file, or public facade exposure changes.
