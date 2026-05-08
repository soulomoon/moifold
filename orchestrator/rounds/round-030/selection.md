### Selected Extraction
- Milestone: Harden Generic Event-Log, Transaction, and Daemon Contracts
- Milestone id: milestone-003-core-runtime-contracts
- Direction id: direction-006-transaction-law-coverage
- Extracted item id: item-030-transaction-law-coverage
- Extracted item summary: Add focused law and parity coverage for generic transaction failure stages, commit boundaries, audit reports, retryability, action partitioning, and dry-run versus execute behavior using fake interpreters.
- Roadmap id: 2026-05-08-00-framework-kernel-migration
- Roadmap revision: rev-001
- Roadmap dir: orchestrator/roadmaps/2026-05-08-00-framework-kernel-migration/rev-001

### Boundaries
- In scope: focused `watcher-core-test` coverage for the current transaction core surface, including failure-stage classification, commit boundary behavior, audit report stability, retryability decisions, pre/post action partitioning, and dry-run plus execute-mode fake interpreter parity for moifold and DocsMigration-relevant transaction paths.
- Out of scope: moving filesystem writes, process execution, concrete moifold lifecycle policy, daemon child ownership, healthcheck, repair, PID/lock/runtime-owner handling, concrete `WatcherEvent` ownership, Codex or GitHub adapter API stabilization, new DSL transition ports, event schema or golden fixture changes, compatibility facade removal, roadmap edits, `plan.md`, implementation notes, merge notes, reviews, and `state.json`.
- Concurrent batch context: none; controller state allows one active round and the roadmap keeps runtime-contract work in the default serial lane unless a later planner proves non-overlap.

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
Milestone 001 is complete through round 027, satisfying the declared dependency for milestone 003. Round 029 completed milestone 002's remaining DSL transition-port proof, so the next roadmap-ready framework stabilization work is the first direction under milestone 003.

`direction-006-transaction-law-coverage` should run before daemon-boundary extraction because `direction-007-daemon-core-boundary` explicitly depends on transaction law tests covering current behavior. This slice is round-sized because it hardens the existing generic transaction contract with focused tests and fake interpreters without moving concrete moifold process ownership, filesystem effects, event schemas, compatibility facades, or adapter APIs.
