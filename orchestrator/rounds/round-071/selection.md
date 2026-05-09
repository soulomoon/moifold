### Selected Extraction
- Milestone: Complete External Operator And Downstream Inventory
- Milestone id: `milestone-007-external-operator-downstream-inventory`
- Direction id: `direction-020-external-operator-downstream-inventory`
- Extracted item id: `direction-020-external-operator-downstream-inventory`
- Extracted item summary: Inventory external scripts, operator runbooks, downstream imports, state-file path readers, and known unsupported-user decisions across the import-facade and runtime compatibility surfaces.
- Roadmap id: `2026-05-09-01-compatibility-surface-cleanup`
- Roadmap revision: `rev-002`
- Roadmap dir: `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002`

### Boundaries
- In scope: Evidence-only inventory for public imports, state-file paths, shell/operator consumers, runbooks, downstream users, unavailable evidence, blocked evidence, and unsupported-user decisions across the compatibility surfaces already covered by milestones 005 and 006.
- Out of scope: Deprecation, migration, removal, package publication, upload, release approval, production import rewrites, Cabal exposure changes, runtime compatibility-file schema or filename changes, event type changes, healthcheck behavior changes, repair behavior changes, write-timing changes, and any gated-removal work from later milestones.
- Concurrent batch context: none; the active roadmap uses the default serial lane and `state.json` sets `max_parallel_rounds` to 1 for this active round.

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
The active roadmap revision is `rev-002`. Milestone 007 depends on `milestone-006-runtime-compatibility-follow-up-evidence`, and the roadmap records that round 070 completed `direction-019-live-issue-snapshot-fixture-timing`, making directions 013 through 019 and milestone 006 complete. Milestone 007 is therefore the next dependency-ready pending milestone.

Within milestone 007, `direction-020-external-operator-downstream-inventory` is the only candidate direction. Selecting it now preserves the roadmap's evidence-first sequencing: milestones 005 and 006 produced current import-facade and runtime compatibility evidence, while milestone 007 must check external operator and downstream expectations before any public import facade or runtime compatibility path can be selected for removal. This selection remains evidence-only and does not approve deprecation, migration, removal, package publication, upload, or release.
