### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-011-core-ids-import-convergence`
- Extracted item id: `round-158-observe-parser-core-ids-split-import-migration`
- Extracted item summary: Migrate only `src/CodexWatcher/Cli/Parser/Observe.hs` from the combined `CodexWatcher.Core.Ids` compatibility facade to direct GitHub-id and agent-id owner imports for its existing `CommitSha`, `PrNumber`, and `TurnId` uses, preserving observe CLI parser behavior while leaving public compatibility surfaces exposed.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: edit only `src/CodexWatcher/Cli/Parser/Observe.hs` to replace `CodexWatcher.Core.Ids (CommitSha (..), PrNumber (..), TurnId (..))` with direct owner imports from `CodexWatcher.Workflow.GitHub.Ids (CommitSha (..), PrNumber (..))` and `CodexWatcher.Workflow.Agent.Ids (TurnId (..))`; preserve existing `observe-once` parser option names, constructors, optional fields, review-thread parsing, and CLI behavior.
- Out of scope: other parser modules, command execution logic, parser helper refactors, test rewrites, package descriptor cleanup, public facade deletion or deprecation, Cabal exposed-module changes, docs or policy-string edits, `CodexWatcher.Core.Ids` facade changes, broader `Core.Ids` migration, runtime compatibility cleanup, milestone completion, terminal completion, release approval, or public compatibility removal.
- Concurrent batch context: none. The active controller state has `max_parallel_rounds: 1`, and this one-file migration should run serially after round 157.

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
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 011 remains in progress after rounds 152 through 157 completed one-file direct-owner migrations while live evidence still shows many `CodexWatcher.Core.Ids` import users. The operator objected to more readiness-only gates, so selecting another concrete migration is the lawful highest-value next slice.

`src/CodexWatcher/Cli/Parser/Observe.hs` is a bounded production split-import candidate: it imports GitHub-owned `CommitSha` and `PrNumber`, plus agent-owned `TurnId`, through the combined compatibility facade. The direct owner modules expose those names, and the main library already depends on both `agent-workflow-github` and `agent-workflow-codex`, so no package descriptor change is expected. This is removal-enabling import convergence rather than inventory or gate-only work, while public facade exposure, Cabal cleanup, deprecation, removal, docs, downstream evidence, and compatibility-file cleanup remain reserved for later exact gates.
