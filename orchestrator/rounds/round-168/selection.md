### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-011-core-ids-import-convergence`
- Extracted item id: `round-168-pr-review-launch-cli-core-ids-split-import-migration`
- Extracted item summary: Migrate only `src/CodexWatcher/Domain/PrReview/LaunchCli.hs` from the combined `CodexWatcher.Core.Ids` compatibility facade to direct GitHub-id and agent-id owner imports for its existing `BranchName`, `PrNumber`, `RepoName`, `RequestId`, and `ThreadId` uses, preserving PR-review launch planning, config JSON rendering, thread startup, runtime-owner handling, compatibility writes, and command rendering while leaving public compatibility surfaces exposed.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: edit only `src/CodexWatcher/Domain/PrReview/LaunchCli.hs` to replace `CodexWatcher.Core.Ids (BranchName (..), PrNumber (..), RepoName (..), RequestId (..), ThreadId (..))` with direct owner imports from `CodexWatcher.Workflow.GitHub.Ids (BranchName (..), PrNumber (..), RepoName (..))` and `CodexWatcher.Workflow.Agent.Ids (RequestId (..), ThreadId (..))`; preserve `ensurePrReviewWatcherForHandoff`, `prReviewWatcherLaunchPlan`, `prReviewWatcherConfigJson`, `withPrReviewThreadIds`, `launchPrReviewWatcher`, `startPrReviewThread`, runtime-owner status handling, config/state writes, PR-review child command rendering, and all existing output text.
- Out of scope: other `Core.Ids` users including `Cli/Command/IssueFanout.hs`, `IssuePlanning/Loop.hs`, `IssueImplement/Watcher.hs`, `IssueImplement/Loop.hs`, `DaemonLoop/Types.hs`, daemon/runtime/event-log/state-machine/effects modules, tests unless needed to keep the selected production import compiling, package descriptor cleanup, public facade deletion or deprecation, Cabal exposed-module changes, docs or policy-string edits, `CodexWatcher.Core.Ids` facade changes, broader `Core.Ids` migration, runtime compatibility cleanup, milestone completion, terminal completion, release approval, or public compatibility removal.
- Concurrent batch context: none. The active controller state has `max_parallel_rounds: 1`, and this one-file production migration should run serially after round 167.

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
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 011 remains in progress after round 167 migrated `src/CodexWatcher/Domain/IssuePlanning/Fanout.hs`. The active roadmap permits narrow split-import migration slices with focused parser/rendering or command-output evidence, while operator steering asks for concrete migration or removal-enabling code slices instead of another readiness-only or removal-gate-only round when lawful production `Core.Ids` migrations remain. No reviewed gate currently permits public facade removal, Cabal exposure cleanup, docs cleanup, package descriptor cleanup, or runtime compatibility removal.

The live scan for this worktree still shows `src/CodexWatcher/Domain/PrReview/LaunchCli.hs` importing `CodexWatcher.Core.Ids (BranchName (..), PrNumber (..), RepoName (..), RequestId (..), ThreadId (..))`. Those identifiers have clear direct owners: `BranchName`, `PrNumber`, and `RepoName` are exported by `CodexWatcher.Workflow.GitHub.Ids`, while `RequestId` and `ThreadId` are exported by `CodexWatcher.Workflow.Agent.Ids`; `CodexWatcher.Core.Ids` only reexports those owner modules. This is a bounded production split-import migration with one file of ownership change, existing PR-review launch CLI coverage nearby, and no need to authorize broader facade, package, docs, test, or runtime compatibility cleanup.
