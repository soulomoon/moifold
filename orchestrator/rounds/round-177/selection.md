### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-011-core-ids-import-convergence`
- Extracted item id: `round-177-event-log-replay-core-ids-split-import-migration`
- Extracted item summary: Migrate only `src/CodexWatcher/EventLog/Replay.hs` from the `CodexWatcher.Core.Ids` compatibility facade to direct owner imports for its existing `IssueNumber`, `ThreadId`, and `TurnId` uses.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: Replace the `CodexWatcher.Core.Ids (IssueNumber (..), ThreadId (..), TurnId (..))` import in `src/CodexWatcher/EventLog/Replay.hs` with direct imports from `CodexWatcher.Workflow.GitHub.Ids (IssueNumber (..))` and `CodexWatcher.Workflow.Agent.Ids (ThreadId (..), TurnId (..))`; preserve event-log replay initialization, event application, transition parity, replay failure text, exports, constructors, and function bodies.
- Out of scope: Any public facade deprecation/removal, Cabal exposure cleanup, docs cleanup, package descriptor changes, runtime compatibility file changes, golden fixture changes, event JSON `type` changes, old-log parsing changes, broad `Core.Ids` migration, milestone completion, terminal completion, release approval, or changes outside `src/CodexWatcher/EventLog/Replay.hs`.
- Concurrent batch context: none; the controller is running with `max_parallel_rounds: 1`, and this is one serial production import-convergence slice after round-176.

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
Milestone 003 is active and dependency-ready because milestone 001 is complete, and direction 011 remains in progress after round-176. The live import scan still shows production `CodexWatcher.Core.Ids` users, including `src/CodexWatcher/EventLog/Replay.hs`.

This selection continues the requested concrete removal-enabling import convergence without selecting a readiness gate, public facade removal, Cabal exposure cleanup, docs cleanup, package descriptor cleanup, runtime compatibility cleanup, release approval, milestone completion, or terminal completion. `EventLog.Replay.hs` is a bounded one-file production user whose selected identifiers split directly by owner: `IssueNumber` belongs to `CodexWatcher.Workflow.GitHub.Ids`, while `ThreadId` and `TurnId` belong to `CodexWatcher.Workflow.Agent.Ids`. The selected work should be import-only because `CodexWatcher.Core.Ids` only reexports those owner modules for this import, and the main library already depends on the direct owner packages. Because the file is on the replay path, planner and reviewer should require the roadmap baseline plus focused checks that replay behavior, event JSON shape, old-log parsing behavior, package exposure, and public compatibility facade availability are unchanged.
