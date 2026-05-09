### Selected Extraction
- Milestone: Inventory Compatibility Surfaces
- Milestone id: `milestone-001-inventory-compatibility-surfaces`
- Direction id: `direction-001-import-facade-inventory`
- Extracted item id: `round-052-import-facade-inventory`
- Extracted item summary: Inventory the current Haskell compatibility import facades, their exposed-module status, repo-local users, preferred replacement imports, protecting tests, and unknowns for `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.Types`, `CodexWatcher.Workflow.EventLog`, `CodexWatcher.Workflow.Execution`, and `CodexWatcher.Workflow.Permission`.
- Roadmap id: `2026-05-09-01-compatibility-surface-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-001`

### Boundaries
- In scope: source-backed import scans across source, tests, examples, Cabal descriptors, package docs, and public package docs; a reviewable inventory artifact naming each facade, current users, preferred replacement path, existing test coverage, and unresolved ownership or coverage unknowns.
- Out of scope: deprecation pragmas, module removal, module renames, import rewrites, runtime compatibility-file inventory, runtime file behavior changes, policy wording, and final cleanup candidate approval.
- Concurrent batch context: none selected for this round; runtime compatibility-file inventory remains a separate lawful direction and should use disjoint artifacts if scheduled later in parallel.

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
Milestone 1 has no dependencies and must run before replacement-readiness, policy, or removal work. The import-facade direction is the smallest dependency-ready extraction because the roadmap names a bounded Haskell module set and explicitly forbids deprecation pragmas or import rewrites. Selecting this inventory first gives the planner a concrete source-scan and replacement-map task while preserving the roadmap rule that all compatibility cleanup starts with evidence, not policy or removal.
