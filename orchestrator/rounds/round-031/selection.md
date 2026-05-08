### Selected Extraction
- Milestone: Harden Generic Event-Log, Transaction, and Daemon Contracts
- Milestone id: milestone-003-core-runtime-contracts
- Direction id: direction-007-daemon-core-boundary
- Extracted item id: item-031-daemon-core-boundary
- Extracted item summary: Identify and, if justified, move an ownership-neutral daemon tick/result surface into `agent-workflow-core`, with mandatory source scans proving concrete daemon ownership remains in moifold.
- Roadmap id: 2026-05-08-00-framework-kernel-migration
- Roadmap revision: rev-001
- Roadmap dir: orchestrator/roadmaps/2026-05-08-00-framework-kernel-migration/rev-001

### Boundaries
- In scope: a narrow daemon-boundary extraction for reusable tick/result or failure-classification contract shapes, focused tests for the selected generic surface, and recursive source scans proving `agent-workflow-core` does not import concrete daemon/runtime ownership modules or concrete watcher event/state types.
- Out of scope: moving `ChildDaemon`, healthcheck, repair, PID, lock, runtime-owner files, process execution, filesystem writes, concrete `WatcherEvent`, concrete moifold lifecycle policy, Codex or GitHub adapter APIs, event schemas, golden fixtures, compatibility facade removal, roadmap edits, implementation notes, merge notes, reviews, and `state.json`.
- Concurrent batch context: none; controller state allows one active round, and the roadmap keeps runtime-contract work in the default serial lane because daemon-boundary work depends on the completed transaction-law baseline.

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
Milestone 003 is dependency-ready because milestone 001 is complete through round 027. Within milestone 003, direction 006 is complete via round 030 as `7b0b105`, satisfying direction 007's precondition that transaction law tests cover current behavior before daemon-boundary work starts.

`direction-007-daemon-core-boundary` is the next round-sized extraction after round 030 because it is the only remaining candidate direction in milestone 003. It should run before adapter API stabilization or extraction-readiness work so the framework's generic runtime-contract surface is proven without pulling moifold child ownership, healthcheck, repair, PID/lock/runtime-owner handling, or concrete watcher events into `agent-workflow-core`.
