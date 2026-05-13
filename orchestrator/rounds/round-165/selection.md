### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-011-core-ids-import-convergence`
- Extracted item id: `round-165-pr-review-loop-core-ids-split-import-migration`
- Extracted item summary: Migrate only `src/CodexWatcher/Domain/PrReview/Loop.hs` from the combined `CodexWatcher.Core.Ids` compatibility facade to direct GitHub-id and agent-id owner imports for its existing `CommitSha`, `PrNumber`, and `ThreadId` uses, preserving PR-review loop behavior while leaving public compatibility surfaces exposed.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: edit only `src/CodexWatcher/Domain/PrReview/Loop.hs` to replace `CodexWatcher.Core.Ids (CommitSha, PrNumber (..), ThreadId)` with direct owner imports from `CodexWatcher.Workflow.GitHub.Ids (CommitSha, PrNumber (..))` and `CodexWatcher.Workflow.Agent.Ids (ThreadId)`; preserve review-target loading, review-thread observation, pre-merge gate handling, mergeability waiting, PR number rendering, and all existing error text.
- Out of scope: other `Core.Ids` users, including `PrReview/LaunchCli.hs`, `IssuePlanning/Fanout.hs`, `IssueImplement/TurnClassifier.hs`, daemon/runtime/event-log/CLI modules, tests unless needed to keep the selected production import compiling, package descriptor cleanup, public facade deletion or deprecation, Cabal exposed-module changes, docs or policy-string edits, `CodexWatcher.Core.Ids` facade changes, broader `Core.Ids` migration, runtime compatibility cleanup, milestone completion, terminal completion, release approval, or public compatibility removal.
- Concurrent batch context: none. `max_parallel_rounds` is 1, and this is a serial one-file production import migration.

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
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 011 remains in progress after round 164 migrated `src/CodexWatcher/EventLogRepair.hs` while live production `CodexWatcher.Core.Ids` imports still remain. The live scan for this round still shows `src/CodexWatcher/Domain/PrReview/Loop.hs:23` importing `CodexWatcher.Core.Ids (CommitSha, PrNumber (..), ThreadId)`.

This is a lawful concrete migration slice under the active roadmap: the selected file has a small split-import surface, with `CommitSha` and `PrNumber` owned by `CodexWatcher.Workflow.GitHub.Ids` and `ThreadId` owned by `CodexWatcher.Workflow.Agent.Ids`. It directly advances import convergence without authorizing public facade removal, Cabal exposure cleanup, docs cleanup, runtime compatibility cleanup, or another readiness-only gate. The remaining `Core.Ids` production importers stay as explicit follow-up work for later rounds.
