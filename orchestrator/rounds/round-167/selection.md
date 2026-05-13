### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-011-core-ids-import-convergence`
- Extracted item id: `round-167-issue-planning-fanout-core-ids-split-import-migration`
- Extracted item summary: Migrate only `src/CodexWatcher/Domain/IssuePlanning/Fanout.hs` from the combined `CodexWatcher.Core.Ids` compatibility facade to direct GitHub-id and agent-id owner imports for its existing `BranchName`, `IssueNumber`, `RepoName`, and `ThreadId` uses, preserving issue-planning fanout launch planning and compatibility-write behavior while leaving public compatibility surfaces exposed.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: edit only `src/CodexWatcher/Domain/IssuePlanning/Fanout.hs` to replace `CodexWatcher.Core.Ids (BranchName (..), IssueNumber (..), RepoName (..), ThreadId (..))` with direct owner imports from `CodexWatcher.Workflow.GitHub.Ids (BranchName (..), IssueNumber (..), RepoName (..))` and `CodexWatcher.Workflow.Agent.Ids (ThreadId (..))`; preserve `planIssueImplementerLaunches`, `planReadyIssueFanout`, `issueImplementerLaunchPlan`, `issueImplementerConfigJson`, config parsing, slug rendering, compatibility writes, and all existing command/rendering behavior.
- Out of scope: other `Core.Ids` users including `PrReview/LaunchCli.hs`, `IssueImplement/Watcher.hs`, `IssueImplement/Loop.hs`, `IssuePlanning/Loop.hs`, daemon/runtime/event-log/CLI modules, tests unless needed to keep the selected production import compiling, package descriptor cleanup, public facade deletion or deprecation, Cabal exposed-module changes, docs or policy-string edits, `CodexWatcher.Core.Ids` facade changes, broader `Core.Ids` migration, runtime compatibility cleanup, milestone completion, terminal completion, release approval, or public compatibility removal.
- Concurrent batch context: none. The active controller state has `max_parallel_rounds: 1`, and this one-file production migration should run serially after round 166.

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
Milestone 003 is already in progress, and direction 011 remains in progress after round 166 migrated `src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`. The active roadmap permits narrow split-import migration slices, while the operator steering asks for concrete migration or removal-enabling code slices instead of another readiness-only gate when direct-owner import migrations are available. No reviewed gate currently permits public facade removal, Cabal exposure cleanup, docs cleanup, package descriptor cleanup, or runtime compatibility removal.

The live scan for this worktree still shows `src/CodexWatcher/Domain/IssuePlanning/Fanout.hs` importing `CodexWatcher.Core.Ids (BranchName (..), IssueNumber (..), RepoName (..), ThreadId (..))`. Those identifiers have clear direct owners: `BranchName`, `IssueNumber`, and `RepoName` are exported by `CodexWatcher.Workflow.GitHub.Ids`, while `ThreadId` is exported by `CodexWatcher.Workflow.Agent.Ids`; `CodexWatcher.Core.Ids` only reexports those owner modules. This is a bounded production split-import migration with one file of ownership change and no need to authorize broader facade, package, docs, test, or runtime compatibility cleanup.
