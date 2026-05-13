### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-011-core-ids-import-convergence`
- Extracted item id: `round-166-issue-implement-turn-classifier-core-ids-split-import-migration`
- Extracted item summary: Migrate only `src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs` from the combined `CodexWatcher.Core.Ids` compatibility facade to direct GitHub-id and agent-id owner imports for its existing `CommitSha`, `PrNumber`, and `ThreadId` uses, preserving issue-plan, implementation-turn, and final-review classification behavior while leaving public compatibility surfaces exposed.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: edit only `src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs` to replace `CodexWatcher.Core.Ids (CommitSha (..), PrNumber, ThreadId)` with direct owner imports from `CodexWatcher.Workflow.GitHub.Ids (CommitSha (..), PrNumber)` and `CodexWatcher.Workflow.Agent.Ids (ThreadId)`; preserve `classifyIssuePlanTurn`, `classifyIssueImplementationTurn`, `classifyIssueFinalReviewTurn`, structured-turn outcome handling, final-review commit validation, reviewer prompt-version validation, missing-output handling, malformed JSON handling, and all existing error text.
- Out of scope: other `Core.Ids` users including `IssueImplement/Watcher.hs`, `IssueImplement/Loop.hs`, `IssuePlanning/Fanout.hs`, `IssuePlanning/Loop.hs`, `PrReview/LaunchCli.hs`, daemon/runtime/event-log/CLI modules, tests unless needed to keep the selected production import compiling, package descriptor cleanup, public facade deletion or deprecation, Cabal exposed-module changes, docs or policy-string edits, `CodexWatcher.Core.Ids` facade changes, broader `Core.Ids` migration, runtime compatibility cleanup, milestone completion, terminal completion, release approval, or public compatibility removal.
- Concurrent batch context: none. The active controller state has `max_parallel_rounds: 1`, and this one-file production migration should run serially after round 165.

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
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 011 remains in progress after round 165 migrated `src/CodexWatcher/Domain/PrReview/Loop.hs` while live production `CodexWatcher.Core.Ids` imports still remain. The active roadmap permits narrow split-import migration slices, and the operator steering asks for concrete migration or removal-enabling code work instead of another readiness-only gate while direct-owner import migrations are available. No exact reviewed gate currently permits public facade removal, Cabal exposure cleanup, docs cleanup, package descriptor cleanup, or runtime compatibility removal.

The live scan for this worktree still shows `src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs` importing `CodexWatcher.Core.Ids (CommitSha (..), PrNumber, ThreadId)`. Those identifiers already have direct owners: `CommitSha` and `PrNumber` are exported by `CodexWatcher.Workflow.GitHub.Ids`, while `ThreadId` is exported by `CodexWatcher.Workflow.Agent.Ids`; `CodexWatcher.Core.Ids` only reexports those owner modules. This is the smallest live production candidate among the remaining examples because it is a one-file classifier import split with clear owner modules and no package descriptor, runtime compatibility, public API, or facade exposure change.
