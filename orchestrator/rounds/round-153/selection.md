### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-011-core-ids-import-convergence`
- Extracted item id: `round-153-issue-fanout-appserver-spec-github-id-direct-owner-migration`
- Extracted item summary: Migrate only `test/IssueFanoutAppServerSpec.hs` from the `CodexWatcher.Core.Ids` compatibility facade to the direct GitHub-id owner for `IssueNumber`, `RepoName`, and `unIssueNumber`, preserving existing issue-fanout app-server coverage and leaving public compatibility surfaces exposed.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: edit only `test/IssueFanoutAppServerSpec.hs` to replace `CodexWatcher.Core.Ids (IssueNumber (..), RepoName (..), unIssueNumber)` with the direct owner import `CodexWatcher.Workflow.GitHub.Ids (IssueNumber (..), RepoName (..), unIssueNumber)`; preserve existing issue-fanout app-server execute, child-argument rendering, retry classification, child-start classification, JSON-RPC failure, and decode-failure assertions.
- Out of scope: production changes, test-body rewrites, helper moves, package descriptor cleanup, public facade deletion or deprecation, Cabal exposed-module changes, docs or policy-string edits, `CodexWatcher.Core.Ids` facade changes, `CodexWatcher.AppServerClient` facade/Cabal/docs cleanup, broader `Core.Ids` migration, runtime compatibility cleanup, milestone completion, terminal completion, release approval, or public compatibility removal.
- Concurrent batch context: none. The active controller state has `max_parallel_rounds: 1`, and this one-file import migration should run serially after round 152.

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
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 011 remains in progress after round 152 migrated one newly exposed test-only agent-id user off `CodexWatcher.Core.Ids`. Public facade removal, Cabal exposure cleanup, docs cleanup, and broad `Core.Ids` migration remain explicitly gated and unapproved, so selecting those surfaces now would violate the roadmap and project contract.

The live import scan after round 152 shows `test/IssueFanoutAppServerSpec.hs` still imports `CodexWatcher.Core.Ids` only for GitHub-owned identifiers: `IssueNumber`, `RepoName`, and `unIssueNumber`. The direct owner module `CodexWatcher.Workflow.GitHub.Ids` exports those names, and the watcher-core test suite already depends on `agent-workflow-github`, so this is a concrete behavior-preserving direct-owner migration rather than readiness-only gate work. It keeps the family moving toward clean compatibility removal while leaving facade parity, public exposure, downstream, and removal decisions for later exact gates.
