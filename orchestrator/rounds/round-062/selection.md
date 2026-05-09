### Selected Extraction
- Milestone: Complete Import-Facade Follow-Up Evidence
- Milestone id: `milestone-005-import-facade-follow-up-evidence`
- Direction id: `direction-011-event-log-concrete-helper-boundary`
- Extracted item id: `round-062-event-log-concrete-helper-boundary`
- Extracted item summary: Produce evidence for `CodexWatcher.Workflow.EventLog` by proving which helpers are concrete moifold compatibility helpers versus preferred reusable event-log imports, including old-log and golden replay evidence before any helper movement, facade narrowing, or later cleanup decision.
- Roadmap id: `2026-05-09-01-compatibility-surface-cleanup`
- Roadmap revision: `rev-002`
- Roadmap dir: `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002`

### Boundaries
- In scope: source-backed evidence for `CodexWatcher.Workflow.EventLog`; refreshed import and usage scans across source, tests, examples, package docs, Cabal descriptors, public package docs, and available downstream/operator references; helper-by-helper ownership classification between concrete moifold compatibility behavior and preferred reusable event-log imports; readback of old-log and golden replay coverage protecting current event-log behavior; explicit remaining blockers for any later helper movement, facade narrowing, migration, deprecation, or removal decision.
- Out of scope: helper movement, production import migration, facade removal or narrowing, deprecation pragmas, Cabal exposed-module changes, event JSON `type` or schema changes, golden fixture rewrites, runtime compatibility-file changes, healthcheck or repair redesign, package publication, release approval, or any gated-removal decision.
- Concurrent batch context: none. The controller is in serial mode with `max_parallel_rounds=1`; this follows the completed round-060 `direction-009-core-ids-split-import-evidence` and round-061 `direction-010-app-server-client-migration-readiness` items inside milestone 005.

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
The active state resolves to roadmap `2026-05-09-01-compatibility-surface-cleanup` revision `rev-002`, whose roadmap records milestones 001 through 004 as complete and milestone 005 as pending. Milestone 005 depends on milestone 004, and its progress notes record round 060 as completing `direction-009-core-ids-split-import-evidence` and round 061 as completing `direction-010-app-server-client-migration-readiness`. The next dependency-ready serial item in the active revision is therefore `direction-011-event-log-concrete-helper-boundary`.

This extraction should run now because it is the next import-facade evidence gate before `direction-012-workflow-permission-public-api-review`, runtime compatibility evidence, external inventory, or gated removals can proceed. The roadmap treats event-log behavior and fixtures as compatibility contracts, and the project contract requires event schemas, parse behavior, golden logs, and replay fixtures to remain stable unless a roadmap explicitly authorizes migration. The selected scope keeps the round evidence-only while giving the planner a bounded handoff for classifying `CodexWatcher.Workflow.EventLog` helpers and proving old-log and golden replay protection before any later cleanup selection.
