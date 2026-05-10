### Selected Extraction
- Milestone: Test Topology And Cleanup Inventory
- Milestone id: `milestone-001-test-topology-inventory`
- Direction id: `direction-002-boundary-policy-test-module-split`
- Extracted item id: `round-084-boundary-policy-test-module-split`
- Extracted item summary: Extract reusable package-boundary scanners and boundary-policy helpers from `test/Main.hs` into focused test support or test modules while preserving the current package-boundary assertions, selected facade checks, runner reachability, and failure intent.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: Test-only extraction of package-boundary scanner helpers and related boundary-policy assertions currently clustered in `test/Main.hs`, including reusable source-scan helpers, standalone workflow package boundary checks, Cabal/package-boundary checks, and selected compatibility-facade policy checks needed to keep those assertions coherent.
- Out of scope: Production code, Cabal files, docs, fixtures, runtime compatibility files, controller state, roadmap updates, import convergence in `src` or `app`, public deprecation, facade removal, Cabal exposure changes, runtime compatibility-file rename or deletion, workflow behavior test splits, and large runtime module decomposition.
- Concurrent batch context: none; active controller state sets `max_parallel_rounds: 1`, and this direction should run serially before facade import-policy and workflow behavior test splits unless a later reviewed selection records disjoint ownership.

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
`direction-002-boundary-policy-test-module-split` is dependency-ready because `round-083` completed `direction-001-cleanup-inventory-refresh` and recorded the current `test/Main.hs` package-boundary and facade-policy helper cluster around the active cleanup surfaces. Milestone 001 remains pending until focused test extraction work lands, and this is the smallest next valuable extraction in that milestone.

Selecting the boundary-policy split now strengthens the evidence base before later cleanup: `direction-003` depends on boundary helper extraction or a separately justified independent split, and `direction-004` should wait until shared helper ownership is clear. This round should reduce the oversized `test/Main.hs` surface without weakening assertions or implying any production import migration, public deprecation, Cabal exposure change, or compatibility-surface removal.
