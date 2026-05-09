### Selected Extraction
- Milestone: Complete Import-Facade Follow-Up Evidence
- Milestone id: `milestone-005-import-facade-follow-up-evidence`
- Direction id: `direction-012-workflow-permission-public-api-review`
- Extracted item id: `direction-012-workflow-permission-public-api-review`
- Extracted item summary: Review `CodexWatcher.Workflow.Permission` as a public API surface, including downstream-user inventory and concrete permission behavior parity evidence.
- Roadmap id: `2026-05-09-01-compatibility-surface-cleanup`
- Roadmap revision: `rev-002`
- Roadmap dir: `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002`

### Boundaries
- In scope: Evidence for the exposed `CodexWatcher.Workflow.Permission` surface: public exposure readback, downstream or operator-user inventory, current permission behavior tests or manual evidence, replacement or ownership notes, and explicit remaining blockers for any later cleanup decision.
- Out of scope: Deprecation pragmas, facade removal, Cabal exposed-module changes, production import migration, event schema changes, runtime compatibility-file changes, package publication, upload, release approval, or any gated-removal work.
- Concurrent batch context: none; `max_parallel_rounds` is 1 and the active roadmap keeps import-facade evidence ordered serially before runtime compatibility evidence.

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
Milestones 001 through 004 are complete, and milestone 005 is dependency-ready because round 059 activated rev-002 and rounds 060, 061, and 062 completed directions 009, 010, and 011. The roadmap says milestone 005 remains pending specifically because direction 012 still needs evidence before milestone completion, while milestone 006 depends on milestone 005. Selecting `direction-012-workflow-permission-public-api-review` therefore preserves the serial roadmap order and completes the remaining import-facade follow-up evidence gate before runtime compatibility follow-up work can begin.
