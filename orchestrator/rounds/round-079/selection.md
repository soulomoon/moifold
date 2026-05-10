### Selected Extraction
- Milestone: Internal Import Migration Readiness
- Milestone id: `milestone-002-internal-import-migration`
- Direction id: `direction-005-eventlog-permission-readiness`
- Extracted item id: `round-079-eventlog-permission-readiness-hold`
- Extracted item summary: Produce a focused readiness decision for `CodexWatcher.Workflow.EventLog` and `CodexWatcher.Workflow.Permission`, confirming whether each mixed surface should remain held as a concrete moifold bridge for now and recording the exact evidence that blocks behavior-neutral migration.
- Roadmap id: `2026-05-10-00-facade-removal-readiness`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-10-00-facade-removal-readiness/rev-001`

### Boundaries
- In scope: Evidence-only review of the current `Workflow.EventLog` and `Workflow.Permission` import sites, facade definitions, generic replacement modules, Cabal exposure, and focused protecting tests; a concise keep/defer/hold decision for internal migration readiness of these mixed surfaces.
- Out of scope: Production code edits, test edits, import migration, wrapper changes, event-schema changes, replay behavior changes, permission or phase-validation behavior changes, runtime compatibility files, healthcheck, repair, package descriptors, docs, public API, deprecation pragmas, Cabal exposure changes, facade removal, `CodexWatcher.Workflow.Types`, and `CodexWatcher.Workflow.Execution`.
- Concurrent batch context: none; active state keeps `max_parallel_rounds` at 1, and this is the remaining serial milestone-002 direction after completed directions 003 and 004.

### Scheduler Fields
```json
{
  "depends_on_round_ids": ["round-075", "round-076", "round-077", "round-078"],
  "merge_after_item_ids": [
    "round-075-import-scan-refresh",
    "round-076-behavior-owner-classification",
    "round-077-appserverclient-import-migration-readiness",
    "round-078-core-ids-split-import-migration"
  ],
  "parallel_group": null,
  "merge_ready": false
}
```

### Rationale
Milestone 001 is complete, and rounds 077 and 078 completed the pure-reexport migration slices for `CodexWatcher.AppServerClient` and `CodexWatcher.Core.Ids`. The only pending milestone-002 direction is `direction-005-eventlog-permission-readiness`.

Round 076 classified `CodexWatcher.Workflow.EventLog` and `CodexWatcher.Workflow.Permission` as mixed surfaces: each reexports reusable workflow APIs while also exposing concrete moifold replay, initialization, permission, or phase-validation behavior. Selecting a readiness/hold decision now advances milestone 002 without treating local import counts as removal evidence and without approving deprecation, Cabal exposure changes, public API changes, or facade removal.
