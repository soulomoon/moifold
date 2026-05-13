### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-011-core-ids-import-convergence`
- Extracted item id: `round-173-effects-core-ids-split-import-migration`
- Extracted item summary: Migrate only `src/CodexWatcher/Effects.hs` from the `CodexWatcher.Core.Ids` compatibility facade to direct owner imports for its existing `BranchName`, `CommitSha`, `PrNumber`, `RepoName`, `ReviewThreadId`, and `ThreadId` uses, preserving effect-plan constructors, action classification, mutation detection, exported API shape, and behavior while leaving public compatibility surfaces exposed.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: edit only `src/CodexWatcher/Effects.hs` to replace `CodexWatcher.Core.Ids (BranchName, CommitSha, PrNumber, RepoName, ReviewThreadId, ThreadId)` with direct owner imports from `CodexWatcher.Workflow.GitHub.Ids (BranchName, CommitSha, PrNumber, RepoName, ReviewThreadId)` and `CodexWatcher.Workflow.Agent.Ids (ThreadId)`; preserve `Effect`, `SomeEffect`, `EffectPlan`, `SomeEffectAction`, `actionKindText`, `effectActionSing`, `hasMutation`, `someEffectAction`, constructors, deriving behavior, exported names, and all function bodies.
- Out of scope: other `Core.Ids` users including CLI, healthcheck, event-log, state-machine, runtime compatibility, golden replay, issue-planning, issue-implementation, indexed workflow, and tests; parser, renderer, serialization, prompt wording, command-output, fixture, replay, state-machine, healthcheck, repair, runtime compatibility, or behavior changes; package descriptor cleanup; public facade deletion or deprecation; Cabal exposed-module changes; docs or policy-string edits; `CodexWatcher.Core.Ids` facade changes; broader `Core.Ids` migration; runtime compatibility cleanup; milestone completion; terminal completion; release approval; or public compatibility removal.
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
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 011 remains in progress after round 172 migrated `src/CodexWatcher/RunnerGuard.hs`. The live production import scan still shows `src/CodexWatcher/Effects.hs:22` importing `CodexWatcher.Core.Ids (BranchName, CommitSha, PrNumber, RepoName, ReviewThreadId, ThreadId)`.

This selection follows the operator steering to keep doing concrete removal-enabling migration work instead of another readiness-only or removal-gate-only round while safe production `Core.Ids` direct-owner migrations remain. `Effects.hs` is a bounded split-import candidate: `BranchName`, `CommitSha`, `PrNumber`, `RepoName`, and `ReviewThreadId` are owned by `CodexWatcher.Workflow.GitHub.Ids`, while `ThreadId` is owned by `CodexWatcher.Workflow.Agent.Ids`; `CodexWatcher.Core.Ids` only reexports those owner modules. The selected import is type-only in the effect-plan GADT surface, the main library already depends on the direct owner packages, and the selected work should be import-only with no parser/renderer, JSON, event schema, replay, prompt, command-output, Cabal, docs, compatibility-file, or public facade exposure changes.
