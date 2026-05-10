### Selected Extraction
- Milestone: Public Facade Decision Gates
- Milestone id: `milestone-003-public-facade-decision-gates`
- Direction id: `direction-007-cabal-exposure-decision`
- Extracted item id: `round-081-cabal-exposure-decision`
- Extracted item summary: Produce an artifact-only Cabal exposure decision for the four selected compatibility facades, deciding whether each exposed module can be removed from `moifold.cabal` or must remain exposed/deferred based on current migration, deprecation-readiness, import, behavior, documentation, and downstream-scope evidence.
- Roadmap id: `2026-05-10-00-facade-removal-readiness`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-10-00-facade-removal-readiness/rev-001`

### Boundaries
- In scope: Round-local decision artifact for Cabal exposure of `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.EventLog`, and `CodexWatcher.Workflow.Permission`; evidence review from rounds 075-080; current `moifold.cabal` exposed-module status; import, docs/Haddock, package-boundary, behavior-protection, and downstream/operator inventory evidence needed to decide remove, keep, or defer each exposure.
- Out of scope: Editing `moifold.cabal` or any package descriptor; removing exposed modules; deleting facade modules; production code, test, roadmap, documentation, or `orchestrator/state.json` edits; deprecation pragmas or public deprecation wording; runtime compatibility files; event schema, repair, healthcheck, release, or publication changes; `CodexWatcher.Workflow.Types` and `CodexWatcher.Workflow.Execution`.
- Concurrent batch context: none; active state keeps `max_parallel_rounds` at 1, and this extraction completes the remaining serial direction in milestone 003 before any exact removal or terminal hold selection.

### Scheduler Fields
```json
{
  "depends_on_round_ids": ["round-075", "round-076", "round-077", "round-078", "round-079", "round-080"],
  "merge_after_item_ids": [
    "round-075-import-scan-refresh",
    "round-076-behavior-owner-classification",
    "round-077-appserverclient-import-migration-readiness",
    "round-078-core-ids-split-import-migration",
    "round-079-eventlog-permission-readiness-hold",
    "round-080-public-deprecation-readiness-decision"
  ],
  "parallel_group": null,
  "merge_ready": false
}
```

### Rationale
Milestone 003 is dependency-ready because milestone 002 is complete and round 080 completed direction 006 with an approved artifact-only `defer` decision for all four selected facades. Direction 007 is now the only pending public decision gate before the roadmap can select exact removal or a terminal hold.

Cabal exposure is the public compatibility boundary for downstream imports, and the current roadmap forbids exposed-module deletion from local absence alone. This round should therefore decide exposure status first, without editing Cabal files: if the evidence remains insufficient, the lawful result is to keep all selected facades exposed or defer removal with exact blockers recorded for reviewer approval.
