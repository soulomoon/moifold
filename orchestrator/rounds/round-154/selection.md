### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-011-core-ids-import-convergence`
- Extracted item id: `round-154-automatic-loop-runner-spec-core-ids-split-import-migration`
- Extracted item summary: Migrate only `test/AutomaticLoopRunnerSpec.hs` from the combined `CodexWatcher.Core.Ids` compatibility facade to direct GitHub-id and agent-id owner imports for its existing `RepoName`, `ThreadId`, and `unThreadId` uses, preserving automatic-loop runner coverage and leaving public compatibility surfaces exposed.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: edit only `test/AutomaticLoopRunnerSpec.hs` to replace `CodexWatcher.Core.Ids (RepoName (..), ThreadId (..), unThreadId)` with direct owner imports from `CodexWatcher.Workflow.GitHub.Ids` for `RepoName (..)` and `CodexWatcher.Workflow.Agent.Ids` for `ThreadId (..), unThreadId`; preserve existing automatic-loop execute, dry-run, retry-classification, request-id, thread-id, and endpoint-backed app-server assertions.
- Out of scope: production changes, test-body rewrites, helper moves, package descriptor cleanup, public facade deletion or deprecation, Cabal exposed-module changes, docs or policy-string edits, `CodexWatcher.Core.Ids` facade changes, `CodexWatcher.AppServerClient` facade/Cabal/docs cleanup, broader `Core.Ids` migration, runtime compatibility cleanup, milestone completion, terminal completion, release approval, or public compatibility removal.
- Concurrent batch context: none. The active controller state has `max_parallel_rounds: 1`, and this one-file migration should run serially after round 153.

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
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 011 remains in progress after round 153 migrated a newly exposed test-only GitHub-id user off `CodexWatcher.Core.Ids`. Public facade removal, Cabal exposure cleanup, docs cleanup, and broad `Core.Ids` migration remain explicitly gated and unapproved, so selecting those surfaces now would violate the roadmap and project contract.

`test/AutomaticLoopRunnerSpec.hs` is a small combined-facade user: it imports `RepoName` from the GitHub-id side and `ThreadId` / `unThreadId` from the agent-id side through `CodexWatcher.Core.Ids`. The direct owner modules export those names, and `watcher-core-test` already depends on both `agent-workflow-github` and `agent-workflow-codex`, so this is a concrete split-import migration rather than readiness-only gate work. It keeps the family moving toward clean compatibility removal while leaving facade parity, public exposure, downstream, and removal decisions for later exact gates.
