### Selected Extraction
- Milestone: Validate Consumer And Release Gate
- Milestone id: milestone-005-consumer-release-gate
- Direction id: direction-014-moifold-consumer-validation
- Extracted item id: item-049-moifold-consumer-validation
- Extracted item summary: Prove moifold builds and tests while consuming the `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github` external-package candidates through the intended local/package mechanism, with focused evidence for compatibility facades and current CLI/watcher workflows.
- Roadmap id: 2026-05-09-00-external-package-extraction
- Roadmap revision: rev-001
- Roadmap dir: orchestrator/roadmaps/2026-05-09-00-external-package-extraction/rev-001

### Boundaries
- In scope: moifold consumer validation against the external-package candidates; build and test evidence showing moifold and `watcher-core-test` consume the intended local package surfaces; focused compatibility-facade checks for existing moifold imports and compatibility files; focused CLI/watcher workflow evidence that current user-facing flows still exercise moifold-owned policy while reusable package ownership remains external; minimal validation documentation or evidence updates needed to make those results reviewable.
- Out of scope: release-candidate evidence bundle assembly, explicit publication gate, package upload or publication, descriptor or version changes, broad runtime, healthcheck, repair, or prompt policy changes, event schema or golden fixture changes, compatibility facade removal, unrelated docs, CI, or source churn beyond validation evidence, package metadata policy rewrites, release announcement, and roadmap or controller-state edits.
- Concurrent batch context: none; controller state is serial with `max_parallel_rounds=1`, this final milestone is marked serial, and this extraction should run before release-candidate bundle assembly, final publication approval, or any package upload decision.

### Scheduler Fields
```json
{
  "depends_on_round_ids": [
    "round-036",
    "round-037",
    "round-038",
    "round-039",
    "round-040",
    "round-041",
    "round-042",
    "round-043",
    "round-044",
    "round-045",
    "round-046",
    "round-047",
    "round-048"
  ],
  "merge_after_item_ids": [
    "item-036-package-names-versioning-contract",
    "item-037-release-metadata-policy",
    "item-038-compatibility-deprecation-policy",
    "item-039-core-package-layout",
    "item-040-codex-package-layout",
    "item-041-github-package-layout",
    "item-042-moifold-local-consumer-wiring",
    "item-043-package-check-and-sdist",
    "item-044-ci-build-matrix",
    "item-045-boundary-test-refresh-for-package-layout",
    "item-046-package-readmes-and-haddock",
    "item-047-examples-and-consumer-guides",
    "item-048-changelog-and-release-notes"
  ],
  "parallel_group": null,
  "merge_ready": false
}
```

### Rationale
The active controller state records `round-049` at `select-task`, no pending merge rounds, `max_parallel_rounds=1`, `last_completed_round` as `round-048`, and roadmap `2026-05-09-00-external-package-extraction` revision `rev-001`. The roadmap marks milestones 001 through 004 complete and milestone 005 pending. Within milestone 005, `direction-014-moifold-consumer-validation` is the first pending direction; `direction-015-release-candidate-bundle` requires consumer validation to pass, and `direction-016-explicit-publication-gate` requires the release-candidate bundle to be reviewed.

`direction-014-moifold-consumer-validation` is dependency-ready because rounds 036 through 048 supply the package identity, metadata policy, compatibility and deprecation policy, standalone package layouts, local moifold consumer wiring, package validation, CI matrix, boundary assertions, package READMEs and Haddock docs, consumer guide and example, and changelog/release-note evidence needed for a truthful consumer validation pass. It is the smallest next valuable extraction because it proves moifold remains the behavioral oracle for the external package candidates without bundling release-candidate assembly, publication approval, descriptor or version changes, package upload, compatibility-facade removal, or unrelated runtime and policy changes.
