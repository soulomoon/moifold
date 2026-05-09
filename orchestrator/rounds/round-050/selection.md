### Selected Extraction
- Milestone: Validate Consumer And Release Gate
- Milestone id: milestone-005-consumer-release-gate
- Direction id: direction-015-release-candidate-bundle
- Extracted item id: item-050-release-candidate-bundle
- Extracted item summary: Assemble a reviewed release-candidate evidence bundle, organized by `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`, covering package artifacts, package checks, docs, changelog and release-note evidence, CI status, compatibility/deprecation notes, moifold consumer validation, and remaining blockers without uploading packages or making the final publish/hold decision.
- Roadmap id: 2026-05-09-00-external-package-extraction
- Roadmap revision: rev-001
- Roadmap dir: orchestrator/roadmaps/2026-05-09-00-external-package-extraction/rev-001

### Boundaries
- In scope: release-candidate evidence bundle assembly by package; source-backed package artifact and validation evidence; package-level `cabal check`, source-distribution, build/test, Haddock/docs, CI, changelog/release-note, compatibility/deprecation, moifold consumer-validation, and blocker status references; reviewable package-by-package summary that makes the later go/no-go decision inspectable.
- Out of scope: package upload or publication; explicit final publication or hold decision; release action; descriptor or version changes unless required by source-backed evidence; event schema or golden fixture changes; compatibility facade removal; runtime, healthcheck, repair, or prompt policy changes; unrelated source, CI, or documentation churn beyond the evidence bundle.
- Concurrent batch context: none; controller state is serial with `max_parallel_rounds=1`, milestone 005 is final serial release-gate work, and this extraction must complete before `direction-016-explicit-publication-gate` can record any final publish/hold decision or release action.

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
    "round-048",
    "round-049"
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
    "item-048-changelog-and-release-notes",
    "item-049-moifold-consumer-validation"
  ],
  "parallel_group": null,
  "merge_ready": false
}
```

### Rationale
The active controller state records `round-050` at `select-task`, no pending merge rounds, `max_parallel_rounds=1`, `last_completed_round` as `round-049`, and roadmap `2026-05-09-00-external-package-extraction` revision `rev-001`. The roadmap marks milestones 001 through 004 complete and milestone 005 pending. Within milestone 005, `direction-014-moifold-consumer-validation` is complete via round 049, `direction-015-release-candidate-bundle` is the next pending direction, and `direction-016-explicit-publication-gate` depends on a reviewed release-candidate bundle.

`direction-015-release-candidate-bundle` is dependency-ready because rounds 036 through 049 provide the package identity, release metadata policy, compatibility/deprecation policy, standalone package layouts, moifold local consumer wiring, package validation, CI matrix, boundary assertions, package READMEs and Haddock docs, example/consumer guide, changelog/release notes, and moifold consumer-validation evidence needed for a truthful release-candidate review. It is the smallest next valuable extraction because it assembles reviewed evidence and remaining blockers by package without collapsing into the terminal publication gate, package upload, descriptor/version churn, compatibility removal, event/schema changes, or unrelated runtime and policy changes.
