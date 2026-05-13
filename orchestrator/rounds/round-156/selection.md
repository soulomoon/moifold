### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-011-core-ids-import-convergence`
- Extracted item id: `round-156-pr-review-launch-cli-spec-github-id-direct-owner-migration`
- Extracted item summary: Migrate only `test/PrReviewLaunchCliSpec.hs` from the `CodexWatcher.Core.Ids` compatibility facade to the direct GitHub-id owner for its existing `BranchName`, `IssueNumber`, `PrNumber`, and `RepoName` uses, preserving PR-review launch CLI coverage and leaving public compatibility surfaces exposed.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: edit only `test/PrReviewLaunchCliSpec.hs` to replace `CodexWatcher.Core.Ids (BranchName (..), IssueNumber (..), PrNumber (..), RepoName (..))` with the direct owner import `CodexWatcher.Workflow.GitHub.Ids (BranchName (..), IssueNumber (..), PrNumber (..), RepoName (..))`; preserve existing PR-review execute, dry-run command rendering, endpoint handling, runtime-owner skip, JSON-RPC failure, and decode-failure assertions.
- Out of scope: production changes, test-body rewrites, helper moves, package descriptor cleanup, public facade deletion or deprecation, Cabal exposed-module changes, docs or policy-string edits, `CodexWatcher.Core.Ids` facade changes, broader `Core.Ids` migration, runtime compatibility cleanup, milestone completion, terminal completion, release approval, or public compatibility removal.
- Concurrent batch context: none. The active controller state has `max_parallel_rounds: 1`, and this one-file migration should run serially after round 155.

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
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 011 remains in progress after round 155 migrated one newly exposed split test user off `CodexWatcher.Core.Ids`. The operator objected to selecting more readiness-only gates, and the live import scan still shows many `CodexWatcher.Core.Ids` users, so a concrete direct-owner migration is the highest-value lawful next slice.

`test/PrReviewLaunchCliSpec.hs` is a small GitHub-id-only candidate: it imports `BranchName`, `IssueNumber`, `PrNumber`, and `RepoName` through the compatibility facade. The direct owner module `CodexWatcher.Workflow.GitHub.Ids` exports those names, and `watcher-core-test` already depends on `agent-workflow-github`, so no package descriptor change is expected. This is removal-enabling import convergence rather than readiness-only gate work, while facade parity, public exposure, downstream, deprecation, Cabal exposure, and removal decisions remain reserved for later exact gates.
