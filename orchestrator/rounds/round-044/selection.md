### Selected Extraction
- Milestone: Establish Release Validation And CI Matrix
- Milestone id: milestone-003-release-validation-ci
- Direction id: direction-009-ci-build-matrix
- Extracted item id: item-044-ci-build-matrix
- Extracted item summary: Add or adapt CI so the supported compiler matrix builds, tests, checks, and packages the `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github` package candidates while preserving existing moifold validation.
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
  "direction_id": "direction-009-ci-build-matrix",
  "extracted_item_id": "item-044-ci-build-matrix"
}
```

### Boundaries
- In scope: CI workflow or validation entrypoint changes needed to run the existing moifold build/test gates plus package candidate build, test, check, and source-distribution validation across the supported compiler matrix; reuse of the package validation commands established by round 043; focused CI documentation or comments when needed for maintainability.
- Out of scope: public package upload or publication, package identity/version changes, unrelated CI churn, public README/Haddock/examples, changelog or release-note work, compatibility facade removal, event schema or golden fixture changes, moving moifold lifecycle/runtime/healthcheck/repair ownership into reusable packages, roadmap edits, `orchestrator/state.json`, implementation plans, review artifacts, and merge artifacts.
- Concurrent batch context: none; controller state is serial with `max_parallel_rounds=1`, and no active round or planner-authored disjoint batch context is present.

### Scheduler Fields
```json
{
  "depends_on_round_ids": [
    "round-043"
  ],
  "merge_after_item_ids": [
    "item-043-package-check-and-sdist"
  ],
  "parallel_group": null,
  "merge_ready": false
}
```

### Rationale
Milestone 003 is dependency-ready because milestone 002 is complete and round 043 completed `direction-008-package-check-and-sdist`, establishing repeatable package-level `cabal check` and source distribution validation for the three workflow package candidates. The active roadmap now leaves `direction-009-ci-build-matrix` and `direction-010-boundary-test-refresh-for-package-layout` pending within milestone 003.

`direction-009-ci-build-matrix` should run next because the local validation commands from round 043 are now stable enough to automate, and the verification contract requires CI evidence that covers moifold plus package candidate build, test, check, and packaging paths without dropping existing watcher tests. With serial controller state, this round should merge only after `item-043-package-check-and-sdist` and should not broaden into boundary-test refresh, docs, examples, release notes, or publication.
