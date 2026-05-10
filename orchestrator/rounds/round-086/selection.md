### Selected Extraction
- Milestone: Test Topology And Cleanup Inventory
- Milestone id: `milestone-001-test-topology-inventory`
- Direction id: `direction-004-workflow-behavior-test-split`
- Extracted item id: `round-086-workflow-behavior-test-split`
- Extracted item summary: Extract focused workflow behavior tests out of `test/Main.hs` after the shared scanner, boundary-policy, facade extraction, and import-policy test ownership from rounds 084 and 085 is stable, while preserving behavior coverage and runner aggregation.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: Test-only extraction of workflow behavior tests from `test/Main.hs` into focused watcher-core test modules or test support, plus minimal `watcher-core-test` metadata and aggregation wiring needed to keep the same behavior checks reachable.
- Out of scope: Production code, docs, fixtures, runtime compatibility files, roadmap updates, controller state, import convergence in `src` or `app`, public deprecation, facade removal, Cabal exposed-module removal, runtime compatibility-file rename or deletion, large runtime module decomposition, and behavior changes.
- Concurrent batch context: none; active controller state uses `max_parallel_rounds: 1`, and the roadmap keeps `direction-004-workflow-behavior-test-split` serial with other `test/Main.hs` work.

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
`direction-004-workflow-behavior-test-split` is dependency-ready because `round-083` completed the cleanup inventory, `round-084` extracted reusable boundary-policy scanner helpers, and `round-085` extracted facade extraction, import-policy, and compatibility policy tests. The active roadmap now records milestone 001 as still pending specifically because this focused workflow behavior test extraction remains open.

Selecting this item now completes the evidence-first test-topology sequence before later compatibility fixture, import convergence, and large-module decomposition milestones depend on it. The round should preserve workflow behavior assertions and aggregation while reducing the oversized `test/Main.hs` surface; it must not imply production import migration, public deprecation, Cabal exposure changes, compatibility-file cleanup, or facade removal.
