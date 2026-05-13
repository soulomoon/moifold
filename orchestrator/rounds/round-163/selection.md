### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-011-core-ids-import-convergence`
- Extracted item id: `round-163-pr-review-protocol-core-ids-split-import-migration`
- Extracted item summary: Migrate only `src/CodexWatcher/Domain/PrReview/Protocol.hs` from the combined `CodexWatcher.Core.Ids` compatibility facade to direct GitHub-id and agent-id owner imports for its existing `CommitSha`, `ReviewThreadId`, `ThreadId`, and `TurnId` uses, preserving PR-review protocol session types, transitions, outcomes, and emitted events while leaving public compatibility surfaces exposed.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: edit only `src/CodexWatcher/Domain/PrReview/Protocol.hs` to replace `CodexWatcher.Core.Ids (CommitSha, ReviewThreadId, ThreadId, TurnId)` with direct owner imports from `CodexWatcher.Workflow.GitHub.Ids (CommitSha, ReviewThreadId)` and `CodexWatcher.Workflow.Agent.Ids (ThreadId, TurnId)`; preserve `WorkerSession`, `ReviewerSession`, worker/reviewer outcomes, turn-start/wait/emit helpers, `runPrReviewWorkerProtocol`, `runPrReviewReviewerProtocol`, and existing event-constructor behavior.
- Out of scope: other `Core.Ids` users including `EventLogRepair.hs`, `RunnerGuard.hs`, PR-review loop/launch/workflow modules, issue-planning loop/fanout modules, issue-implementation classifier/loop/watcher/workflow modules, daemon/healthcheck/runtime/event-log modules, CLI modules, test rewrites, package descriptor cleanup, public facade deletion or deprecation, Cabal exposed-module changes, docs or policy-string edits, `CodexWatcher.Core.Ids` facade changes, broader `Core.Ids` migration, runtime compatibility cleanup, milestone completion, terminal completion, release approval, or public compatibility removal.
- Concurrent batch context: none. The active controller state has `max_parallel_rounds: 1`, and this one-file production migration should run serially after round 162.

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
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 011 remains in progress after round 162 migrated `src/CodexWatcher/Domain/IssuePlanning/Watcher.hs` while production `CodexWatcher.Core.Ids` imports still remain. The operator steering asks for concrete migration or removal-enabling code slices over readiness-only gate work when lawful, and no exact gate currently permits public deprecation, facade removal, or Cabal exposure cleanup.

`src/CodexWatcher/Domain/PrReview/Protocol.hs` is a small next production split-import slice in the remaining `Core.Ids` importer set. Its imported identifiers already have direct owners: `CommitSha` and `ReviewThreadId` are exported by `CodexWatcher.Workflow.GitHub.Ids`, while `ThreadId` and `TurnId` are exported by `CodexWatcher.Workflow.Agent.Ids`; the current `CodexWatcher.Core.Ids` module only reexports those owner modules. Keeping the change to imports only should preserve PR-review protocol behavior and event emission while advancing concrete direct-owner migration under the active roadmap.
