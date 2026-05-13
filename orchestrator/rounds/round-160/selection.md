### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-011-core-ids-import-convergence`
- Extracted item id: `round-160-runtime-config-core-ids-split-import-migration`
- Extracted item summary: Migrate only `src/CodexWatcher/Cli/RuntimeConfig.hs` from the combined `CodexWatcher.Core.Ids` compatibility facade to direct GitHub-id and agent-id owner imports for its existing `IssueNumber`, `RepoName`, and `RequestId` uses, preserving default runtime configuration and planner-scope behavior while leaving public compatibility surfaces exposed.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: edit only `src/CodexWatcher/Cli/RuntimeConfig.hs` to replace `CodexWatcher.Core.Ids (IssueNumber, RepoName, RequestId (..))` with direct owner imports from `CodexWatcher.Workflow.GitHub.Ids (IssueNumber, RepoName)` and `CodexWatcher.Workflow.Agent.Ids (RequestId (..))`; preserve `defaultEffectRuntimeConfig`, `defaultEffectRuntimeConfigWithPlannerScope`, `plannerTurnInputForScope`, `effectRuntimeRepo`, `effectRuntimeNextRequestId = RequestId 1`, and planner thread instruction behavior.
- Out of scope: other CLI runtime, parser, command, daemon, healthcheck, event-log, PR review, issue-planning, issue-implementation, runner-guard, and runtime compatibility modules; test rewrites; package descriptor cleanup; public facade deletion or deprecation; Cabal exposed-module changes; docs or policy-string edits; `CodexWatcher.Core.Ids` facade changes; broader `Core.Ids` migration; runtime compatibility cleanup; milestone completion; terminal completion; release approval; or public compatibility removal.
- Concurrent batch context: none. The active controller state has `max_parallel_rounds: 1`, and this one-file production migration should run serially after round 159.

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
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 011 remains in progress after round 159 migrated `src/CodexWatcher/Cli/Command/RunnerGuard.hs` while many `CodexWatcher.Core.Ids` imports remain. The operator steering asks for concrete migration or removal-enabling code slices over readiness-only gate work when lawful, and no exact gate currently permits public deprecation, facade removal, or Cabal exposure cleanup.

`src/CodexWatcher/Cli/RuntimeConfig.hs` is the smallest next production runtime-config slice visible in the remaining `Core.Ids` importer set: it imports GitHub-owned `IssueNumber` and `RepoName` plus agent-owned `RequestId` through the combined compatibility facade, and the direct owner modules already expose the same types and constructor used by this module. The main library already depends on both `agent-workflow-github` and `agent-workflow-codex`, so this selection should stay import-only and leave function bodies, package descriptors, tests, docs, runtime compatibility files, and public compatibility facade exposure unchanged. This advances removal-enabling import convergence while reserving broader migration, deprecation, removal, and terminal decisions for later exact gates.
