### Selected Extraction
- Milestone: Establish Release Validation And CI Matrix
- Milestone id: milestone-003-release-validation-ci
- Direction id: direction-008-package-check-and-sdist
- Extracted item id: item-043-package-check-and-sdist
- Extracted item summary: Add repeatable `cabal check` and source distribution validation for `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`, recording the exact commands and generated artifact paths without uploading packages.
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
  "direction_id": "direction-008-package-check-and-sdist",
  "extracted_item_id": "item-043-package-check-and-sdist"
}
```

### Boundaries
- In scope: repeatable package-level `cabal check` and source distribution validation for the three workflow package candidates; any minimal scripts, docs, or package-validation metadata needed to make those commands reviewable; exact command and artifact-path evidence for every touched package candidate.
- Out of scope: uploading or publishing packages, changing package identity/versioning policy, broad CI matrix work, public README/Haddock/examples, compatibility facade removal, event schema or golden fixture changes, moving moifold lifecycle/runtime/healthcheck/repair ownership into reusable packages, unrelated package descriptor churn, roadmap edits, `orchestrator/state.json`, implementation plans, review artifacts, and merge artifacts.
- Concurrent batch context: none; controller state is serial with `max_parallel_rounds=1`, and this validation slice should establish package check and source-distribution commands before CI automation or docs-release work relies on them.

### Scheduler Fields
```json
{
  "depends_on_round_ids": [
    "round-042"
  ],
  "merge_after_item_ids": [
    "item-042-moifold-local-consumer-wiring"
  ],
  "parallel_group": null,
  "merge_ready": false
}
```

### Rationale
Milestone 001 is complete after rounds 036 through 038 established package identity, release metadata policy, and compatibility/deprecation policy. Milestone 002 is complete after rounds 039 through 042 created standalone package descriptors for core, Codex, and GitHub and then wired moifold to consume those local package candidates. That satisfies the dependency for milestone 003.

Within milestone 003, `direction-008-package-check-and-sdist` is the next dependency-ready extraction because local source distribution and `cabal check` validation should define the exact package artifact commands before CI matrix work automates them. The roadmap marks CI validation as a possible parallel lane only after package descriptors are stable, but the current controller permits one active round and no planner-authored disjoint batch context is present, so this selection remains serial.

This item should merge after `item-042-moifold-local-consumer-wiring` because it validates the source-backed package candidates as consumed by moifold. It should not broaden into CI, docs, examples, release notes, or any package upload; the round should prepare reviewable local artifact evidence only.
