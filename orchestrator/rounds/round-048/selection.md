### Selected Extraction
- Milestone: Publish Public Docs And Examples
- Milestone id: milestone-004-public-docs-examples
- Direction id: direction-013-changelog-and-release-notes
- Extracted item id: item-048-changelog-and-release-notes
- Extracted item summary: Prepare changelog entries and release-note material for the `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github` package candidates, aligned with implemented APIs, public non-goals, package metadata policy, package README/Haddock docs, consumer guide and example evidence, package validation evidence, and no package-publication claim.
- Roadmap id: 2026-05-09-00-external-package-extraction
- Roadmap revision: rev-001
- Roadmap dir: orchestrator/roadmaps/2026-05-09-00-external-package-extraction/rev-001

### Boundaries
- In scope: changelog entries and release-note preparation for the three workflow package candidates; source-backed summary of package candidate scope, implemented public APIs, compatibility/deprecation status, validation evidence, README/Haddock and consumer-guide evidence, pre-1.0 expectations, remaining public non-goals, and explicit no-publication/no-upload wording.
- Out of scope: release announcement, package upload or publication, final go/no-go release gate, release-candidate bundle assembly, consumer validation, package descriptor, version, or policy changes unless the planner finds a concrete roadmap-required metadata-truth fix, event schema, golden log, runtime, healthcheck, repair, or prompt policy changes, compatibility facade removal, root project or CI changes unrelated to changelog/release-note documentation, implementation plans, review artifacts, merge artifacts, roadmap edits, and `orchestrator/state.json`.
- Concurrent batch context: none; controller state is serial with `max_parallel_rounds=1`, no other active round or pending merge round is present, and this extraction should run as the final milestone-004 docs-release slice before consumer validation, release-candidate bundle assembly, final release-gate approval, or any package upload decision.

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
    "round-047"
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
    "item-047-examples-and-consumer-guides"
  ],
  "parallel_group": null,
  "merge_ready": false
}
```

### Rationale
The active controller state records `round-048` as the only active round, has no pending merge rounds, records `last_completed_round` as `round-047`, and points to roadmap `2026-05-09-00-external-package-extraction` revision `rev-001`. The roadmap marks milestones 001, 002, and 003 complete, marks milestone 004 in progress, and records `direction-011-package-readmes-and-haddock` and `direction-012-examples-and-consumer-guides` as complete. Milestone 005 remains blocked until milestone 004 is complete.

`direction-013-changelog-and-release-notes` is the next dependency-ready extraction because its precondition, approved package metadata policy, was satisfied by round 037, while rounds 036 through 047 provide the current package identity, compatibility/deprecation posture, standalone package layout, local moifold consumption, package validation, CI, boundary assertions, README/Haddock docs, consumer guide, and example evidence that changelog and release-note text must summarize truthfully. It is the smallest next valuable round because it completes the remaining milestone-004 public-docs work without claiming release approval, assembling a release-candidate bundle, validating consumers, changing package descriptors or versions, or publishing packages.
