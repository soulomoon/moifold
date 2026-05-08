### Selected Extraction
- Milestone: Establish Release Validation And CI Matrix
- Milestone id: milestone-003-release-validation-ci
- Direction id: direction-010-boundary-test-refresh-for-package-layout
- Extracted item id: item-045-boundary-test-refresh-for-package-layout
- Extracted item summary: Refresh recursive package-boundary and Cabal/package assertions so the external `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github` package layout remains protected after the standalone package migration and CI validation work.
- Roadmap id: 2026-05-09-00-external-package-extraction
- Roadmap revision: rev-001
- Roadmap dir: orchestrator/roadmaps/2026-05-09-00-external-package-extraction/rev-001

### Selection Metadata
```json
{
  "roadmap_id": "2026-05-09-00-external-package-extraction",
  "roadmap_revision": "rev-001",
  "roadmap_dir": "orchestrator/roadmaps/2026-05-09-00-external-package-extraction/rev-001",
  "milestone_id": "milestone-003-release-validation-ci",
  "direction_id": "direction-010-boundary-test-refresh-for-package-layout",
  "extracted_item_id": "item-045-boundary-test-refresh-for-package-layout"
}
```

### Boundaries
- In scope: boundary tests and assertions that recursively inspect the current source trees, Cabal descriptors, package exposure, package dependencies, and local package wiring for `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`; focused updates to test fixtures or helpers needed to reflect the standalone external-package layout; verification that existing moifold behavior gates still pass.
- Out of scope: weakening ownership scans to accommodate layout drift, public package upload or publication, package identity/version changes, source distribution or CI matrix redesign, package READMEs/Haddock/examples, changelog or release-note work, compatibility facade removal, event schema or golden fixture changes, moving moifold lifecycle/runtime/healthcheck/repair ownership into reusable packages, roadmap edits, `orchestrator/state.json`, implementation plans, review artifacts, and merge artifacts.
- Concurrent batch context: none; controller state is serial with `max_parallel_rounds=1`, no active round is present, and this item reads package/test boundaries that overlap prior package layout and validation work.

### Scheduler Fields
```json
{
  "depends_on_round_ids": [
    "round-042",
    "round-043",
    "round-044"
  ],
  "merge_after_item_ids": [
    "item-042-moifold-local-consumer-wiring",
    "item-043-package-check-and-sdist",
    "item-044-ci-build-matrix"
  ],
  "parallel_group": null,
  "merge_ready": false
}
```

### Rationale
The active controller state has no active or pending merge rounds, records `last_completed_round` as `round-044`, and points to roadmap `2026-05-09-00-external-package-extraction` revision `rev-001`. The roadmap marks milestone 002 complete, and milestone 003 is already in progress with `direction-008-package-check-and-sdist` completed by round 043 and `direction-009-ci-build-matrix` completed by round 044.

`direction-010-boundary-test-refresh-for-package-layout` is the next dependency-ready item because its precondition, chosen package layout, was satisfied by the standalone package layout and moifold local consumer wiring rounds. It is also the only remaining pending direction in milestone 003, and the roadmap explicitly keeps milestone 003 open until refreshed package-boundary assertions are complete. Running this before docs, examples, consumer validation, or release-gate work preserves the ownership split while later rounds rely on the external package candidates as stable public-facing surfaces.
