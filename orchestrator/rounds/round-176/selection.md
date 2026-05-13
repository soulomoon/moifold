### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-011-core-ids-import-convergence`
- Extracted item id: `round-176-state-machine-core-ids-split-import-migration`
- Extracted item summary: Migrate only `src/CodexWatcher/StateMachine.hs` from the `CodexWatcher.Core.Ids` compatibility facade to direct owner imports for the GitHub-owned ids and agent-owned thread id it already uses.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: Replace the `CodexWatcher.Core.Ids (BranchName (..), CommitSha, IssueNumber (..), PrNumber (..), ReviewThreadId, ThreadId)` import in `src/CodexWatcher/StateMachine.hs` with direct imports from `CodexWatcher.Workflow.GitHub.Ids` for `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, and `ReviewThreadId`, and from `CodexWatcher.Workflow.Agent.Ids` for `ThreadId`; preserve state-machine events, decisions, validation, branch-attempt parsing/rendering, PR mismatch text, review-thread resolution, exports, constructors, and function bodies.
- Out of scope: Any public facade deprecation/removal, Cabal exposure cleanup, docs cleanup, package descriptor changes, runtime compatibility file changes, broad `Core.Ids` migration, milestone completion, or changes outside `src/CodexWatcher/StateMachine.hs`.
- Concurrent batch context: none; the controller is running with `max_parallel_rounds: 1`, and this is one serial production import-convergence slice after round-175.

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
Milestone 003 is active and direction 011 remains in progress after round-175. The live import scan still shows production `CodexWatcher.Core.Ids` users, and `src/CodexWatcher/StateMachine.hs` is a bounded one-file combined user whose imports split directly by owner: GitHub ids for branch, commit, issue, PR, and review-thread values, and Agent ids for thread values. This continues the operator-requested removal-enabling work by reducing internal facade dependency in production code while keeping the public compatibility facade exposed. The selected file is not a runtime compatibility surface, does not require a package descriptor change because the library already depends on `agent-workflow-codex` and `agent-workflow-github`, and should be validated with the roadmap baseline plus focused scans for the selected file and remaining `Core.Ids` users.
