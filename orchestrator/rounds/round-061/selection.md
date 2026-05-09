### Selected Extraction
- Milestone: Complete Import-Facade Follow-Up Evidence
- Milestone id: `milestone-005-import-facade-follow-up-evidence`
- Direction id: `direction-010-app-server-client-migration-readiness`
- Extracted item id: `round-061-app-server-client-migration-readiness`
- Extracted item summary: Produce evidence for `CodexWatcher.AppServerClient` by refreshing import usage, grouping callers by client, transport, and parser ownership, confirming current app-server client behavior tests, and recording replacement module exposure and dry-run migration readiness without changing production imports or removing the facade.
- Roadmap id: `2026-05-09-01-compatibility-surface-cleanup`
- Roadmap revision: `rev-002`
- Roadmap dir: `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002`

### Boundaries
- In scope: source-backed evidence for `CodexWatcher.AppServerClient`; refreshed import count across source, tests, examples, package docs, Cabal descriptors, public package docs, and available downstream/operator references; grouping each use by client, transport, and parser ownership; current app-server client behavior test readback; replacement module exposure evidence; dry-run migration readiness and remaining blockers for later cleanup decisions.
- Out of scope: production import migration, facade removal or narrowing, deprecation pragmas, Cabal exposed-module changes, app-server startup policy changes, request rendering changes, action ordering changes, request-id progression changes, event schema changes, runtime compatibility-file changes, package publication, release approval, or any gated-removal decision.
- Concurrent batch context: none. The controller is in serial mode with `max_parallel_rounds=1`; this follows the completed round-060 `direction-009-core-ids-split-import-evidence` item inside milestone 005.

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
The active state resolves to roadmap `2026-05-09-01-compatibility-surface-cleanup` revision `rev-002`, whose roadmap records milestones 001 through 004 as complete and milestone 005 as pending. Milestone 005 depends on milestone 004, and its progress notes record round 060 as completing `direction-009-core-ids-split-import-evidence`, so the next dependency-ready serial item in the active revision is `direction-010-app-server-client-migration-readiness`.

This extraction should run now because it is the next import-facade evidence gate before runtime compatibility evidence, external inventory, or any gated removal work can proceed. The roadmap requires refreshed import counts, current app-server client behavior tests, and replacement module exposure evidence for this surface; the selected scope captures those requirements while preserving the facade and all app-server request rendering, dry-run, startup, and compatibility contracts.
