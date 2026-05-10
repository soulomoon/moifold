### Selected Extraction
- Milestone: Current Facade Evidence Refresh
- Milestone id: `milestone-001-current-facade-evidence`
- Direction id: `direction-001-import-scan-refresh`
- Extracted item id: `round-075-import-scan-refresh`
- Extracted item summary: Refresh the current import scan and replacement mapping for `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.EventLog`, and `CodexWatcher.Workflow.Permission` across source, app, test, Cabal, docs, and README surfaces.
- Roadmap id: `2026-05-10-00-facade-removal-readiness`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-10-00-facade-removal-readiness/rev-001`

### Boundaries
- In scope: Evidence artifacts for current imports, direct references, preferred replacement modules, Cabal exposure, docs/README references, protecting tests, downstream/operator inventory scope, and remaining blocker class for the four selected facades.
- Out of scope: Production source edits, import migration, behavior-owner classification beyond scan-backed notes needed for replacement mapping, deprecation pragmas, Cabal exposure changes, facade removal, runtime compatibility-file changes, event schema changes, healthcheck or repair behavior changes, publication, release, and roadmap updates.
- Concurrent batch context: none; the active controller state has `max_parallel_rounds` set to 1, and milestone 001 must establish the shared evidence base before later classification, migration, public decision, or removal/hold rounds.

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
The active roadmap is `2026-05-10-00-facade-removal-readiness` revision `rev-001`, and all later milestones depend on `milestone-001-current-facade-evidence`. Within milestone 001, `direction-001-import-scan-refresh` has no dependencies beyond re-reading the active roadmap bundle and prior compatibility policy, while `direction-002-behavior-owner-classification` depends on direction 001 evidence unless explicitly bundled. This is therefore the smallest dependency-ready serial extraction.

This round should run now because the prior compatibility-surface cleanup family closed with an empty removed-surface set and must not be treated as removal approval. Current import and replacement evidence is the required first step before any internal migration, public deprecation decision, Cabal exposure decision, exact removal, or terminal hold in this fresh facade-removal-readiness family.
