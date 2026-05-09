### Selected Extraction
- Milestone: Publish Public Docs And Examples
- Milestone id: milestone-004-public-docs-examples
- Direction id: direction-012-examples-and-consumer-guides
- Extracted item id: item-047-examples-and-consumer-guides
- Extracted item summary: Add minimal package examples or consumer guides that demonstrate `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github` usage through the stable public package imports without depending on moifold lifecycle, runtime, healthcheck, repair, prompt policy, event-schema ownership, or compatibility-file responsibilities.
- Roadmap id: 2026-05-09-00-external-package-extraction
- Roadmap revision: rev-001
- Roadmap dir: orchestrator/roadmaps/2026-05-09-00-external-package-extraction/rev-001

### Selection Metadata
```json
{
  "roadmap_id": "2026-05-09-00-external-package-extraction",
  "roadmap_revision": "rev-001",
  "roadmap_dir": "orchestrator/roadmaps/2026-05-09-00-external-package-extraction/rev-001",
  "milestone_id": "milestone-004-public-docs-examples",
  "direction_id": "direction-012-examples-and-consumer-guides",
  "extracted_item_id": "item-047-examples-and-consumer-guides"
}
```

### Boundaries
- In scope: small buildable examples or focused consumer-guide docs for the three workflow package candidates; examples that use package-facing imports and implemented APIs; documentation that explains reusable workflow package usage while preserving public non-goals; validation that examples or guides remain accurate against package descriptors, exposed modules, READMEs, Haddock docs, and existing package-validation commands.
- Out of scope: changelog entries, release notes, release-candidate bundle assembly, package upload or publication, final publication gate decisions, package renaming or version policy changes, broad tutorial prose without executable or source-backed examples, generic prompt-runner or YAML workflow-engine scaffolding, moifold issue/PR lifecycle migration, runtime/healthcheck/repair/prompt policy movement into reusable packages, compatibility facade removal, event schema or golden fixture changes, CI matrix redesign, source-distribution validation script redesign, `orchestrator/state.json`, implementation plans, review artifacts, and merge artifacts.
- Concurrent batch context: none; controller state is serial with `max_parallel_rounds=1`, no active or pending merge round is present, and this extraction should run as one docs-release slice before changelog/release-note and final consumer/release-gate work.

### Scheduler Fields
```json
{
  "depends_on_round_ids": [
    "round-036",
    "round-039",
    "round-040",
    "round-041",
    "round-042",
    "round-045",
    "round-046"
  ],
  "merge_after_item_ids": [
    "item-036-package-names-and-versioning",
    "item-039-core-package-layout",
    "item-040-codex-package-layout",
    "item-041-github-package-layout",
    "item-042-moifold-local-consumer-wiring",
    "item-045-boundary-test-refresh-for-package-layout",
    "item-046-package-readmes-and-haddock"
  ],
  "parallel_group": null,
  "merge_ready": false
}
```

### Rationale
The active controller state records `last_completed_round` as `round-046`, has no active rounds, no pending merge rounds, and points to roadmap `2026-05-09-00-external-package-extraction` revision `rev-001`. The active roadmap marks milestones 001, 002, and 003 complete, and marks milestone 004 in progress after round 046 completed `direction-011-package-readmes-and-haddock`. The remaining pending work in milestone 004 is `direction-012-examples-and-consumer-guides` and `direction-013-changelog-and-release-notes`; milestone 005 remains blocked until milestone 004 is complete.

`direction-012-examples-and-consumer-guides` is dependency-ready because package identity is stable, the standalone package descriptors and local moifold consumer wiring are complete, boundary assertions reflect the external package layout, and the package READMEs/Haddock docs now define the public-facing import and ownership story for examples to follow. It is the smallest next valuable extraction because examples can prove package usability outside moifold before changelog/release-note text summarizes the public change scope, while still staying short of release-candidate assembly, publication approval, or any package upload.
