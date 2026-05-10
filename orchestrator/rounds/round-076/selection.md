### Selected Extraction
- Milestone: Current Facade Evidence Refresh
- Milestone id: `milestone-001-current-facade-evidence`
- Direction id: `direction-002-behavior-owner-classification`
- Extracted item id: `round-076-behavior-owner-classification`
- Extracted item summary: Classify `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.EventLog`, and `CodexWatcher.Workflow.Permission` as pure reexport, moifold behavior bridge, or mixed surface using the round-075 scan evidence, with explicit notes for adapter-id convenience versus concrete event-log, replay, permission, and phase-validation behavior.
- Roadmap id: `2026-05-10-00-facade-removal-readiness`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-10-00-facade-removal-readiness/rev-001`

### Boundaries
- In scope: Evidence-only behavior-owner classification for the four selected facades, grounded in round-075 import/replacement evidence and the active roadmap's ownership boundaries.
- Out of scope: Implementation planning, production code edits, import migration, deprecation pragmas, Cabal exposure changes, facade removal, roadmap updates, reviews, runtime compatibility-file changes, event JSON changes, healthcheck or repair behavior changes, release, publication, and classification of `CodexWatcher.Workflow.Types` or `CodexWatcher.Workflow.Execution`.
- Concurrent batch context: none; active state keeps `max_parallel_rounds` at 1, and this extraction completes the remaining serial direction in milestone 001 before any milestone 002 migration-readiness work can begin.

### Scheduler Fields
```json
{
  "depends_on_round_ids": ["round-075"],
  "merge_after_item_ids": ["round-075-import-scan-refresh"],
  "parallel_group": null,
  "merge_ready": false
}
```

### Rationale
The active roadmap marks `direction-001-import-scan-refresh` complete via round 075 commit `066952b`, and `direction-002-behavior-owner-classification` is the only pending candidate direction in `milestone-001-current-facade-evidence`. Its precondition is now satisfied because round 075 recorded current import counts, replacement mappings, Cabal exposure, protecting checks, downstream/operator inventory limits, and blocker classes for the four selected facades.

This is the smallest dependency-ready serial extraction because milestone 002 depends on milestone 001 completion, and the roadmap forbids moving to import migration, deprecation, Cabal exposure, or removal decisions before behavior ownership is explicit. The round should distinguish reexport-only convenience surfaces from mixed or moifold-owned behavior surfaces without changing imports or public compatibility promises.
