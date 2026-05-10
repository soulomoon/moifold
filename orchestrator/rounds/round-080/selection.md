### Selected Extraction
- Milestone: Public Facade Decision Gates
- Milestone id: `milestone-003-public-facade-decision-gates`
- Direction id: `direction-006-deprecation-readiness`
- Extracted item id: `round-080-public-deprecation-readiness-decision`
- Extracted item summary: Produce a focused public deprecation readiness decision for the selected import facades, using milestone-002 migration and hold evidence to decide whether any facade has enough current evidence for deprecation wording, or whether deprecation should be deferred/declined with explicit blockers.
- Roadmap id: `2026-05-10-00-facade-removal-readiness`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-10-00-facade-removal-readiness/rev-001`

### Boundaries
- In scope: Artifact-only decision record for `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.EventLog`, and `CodexWatcher.Workflow.Permission`; current deprecation-readiness evidence from rounds 075-079; docs, Haddock, changelog/release-note, Cabal exposure, downstream inventory, migration-path, and blocker assessment needed to recommend deprecate, keep, or defer.
- Out of scope: Production code edits, test edits, docs edits, package descriptor edits, public deprecation wording, `DEPRECATED` pragmas, Cabal exposed-module changes, facade removal, event schema changes, runtime compatibility files, healthcheck, repair, release/publication decisions, `CodexWatcher.Workflow.Types`, and `CodexWatcher.Workflow.Execution`.
- Concurrent batch context: none; active state keeps `max_parallel_rounds` at 1, and direction 007 depends on this deprecation-readiness outcome.

### Scheduler Fields
```json
{
  "depends_on_round_ids": ["round-075", "round-076", "round-077", "round-078", "round-079"],
  "merge_after_item_ids": [
    "round-075-import-scan-refresh",
    "round-076-behavior-owner-classification",
    "round-077-appserverclient-import-migration-readiness",
    "round-078-core-ids-split-import-migration",
    "round-079-eventlog-permission-readiness-hold"
  ],
  "parallel_group": null,
  "merge_ready": false
}
```

### Rationale
Milestone 001 refreshed current facade evidence, and milestone 002 is complete: rounds 077 and 078 migrated selected pure-reexport internal imports while preserving the facades, and round 079 recorded an approved hold for the mixed `Workflow.EventLog` and `Workflow.Permission` bridge surfaces.

Milestone 003 is now dependency-ready. Direction 006 must run before direction 007 because deprecation readiness determines whether public wording or warnings are justified before any Cabal exposure decision. Selecting an artifact-only decision keeps the public API signal boundary intact: missing or insufficient evidence should result in keep/defer/no-deprecation findings, not public warnings or exposed-module removal.
