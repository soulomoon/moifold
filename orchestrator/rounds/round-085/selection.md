### Selected Extraction
- Milestone: Test Topology And Cleanup Inventory
- Milestone id: `milestone-001-test-topology-inventory`
- Direction id: `direction-003-facade-import-policy-test-split`
- Extracted item id: `round-085-facade-import-policy-test-split`
- Extracted item summary: Move facade extraction, import-policy, and compatibility policy checks for the public compatibility facades into focused watcher-core test modules while preserving current policy classifications, runner reachability, assertion strength, and failure detail.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: Test-only extraction of the remaining facade extraction, import-policy, and compatibility policy checks from `test/Main.hs` into focused test modules or test support, plus minimal `watcher-core-test` metadata needed to compile those modules.
- Out of scope: Production code, docs, fixtures, runtime compatibility files, roadmap updates, controller state, public deprecation, facade removal, Cabal exposed-module changes, runtime compatibility-file rename or deletion, import convergence in `src` or `app`, workflow behavior test splits, and large runtime module decomposition.
- Concurrent batch context: none; active controller state uses `max_parallel_rounds: 1`, and this test split should run serially before `direction-004-workflow-behavior-test-split`.

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
`direction-003-facade-import-policy-test-split` is dependency-ready because `round-083` completed the cleanup inventory and `round-084` completed the boundary-policy helper split, satisfying this direction's precondition that boundary helper extraction is available. Milestone 001 remains pending specifically because directions 003 and 004 still need focused test extraction work before the milestone completion signal is met.

Selecting this item now keeps the roadmap in its evidence-first sequence. It makes the tests that distinguish preferred imports from removal approval easier to review before any import convergence, deprecation, Cabal exposure, or removal decision. `direction-004-workflow-behavior-test-split` should wait until this facade/import-policy ownership is clear, and later milestones still depend on milestone 001 evidence.
