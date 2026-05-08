### Selected Extraction
- Milestone: Publish Public Docs And Examples
- Milestone id: milestone-004-public-docs-examples
- Direction id: direction-011-package-readmes-and-haddock
- Extracted item id: item-046-package-readmes-and-haddock
- Extracted item summary: Create package-facing README and Haddock/module documentation for the public API surfaces of `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`, accurately separating reusable workflow package APIs from moifold-owned lifecycle, runtime, healthcheck, repair, prompt policy, event schema, and compatibility-file responsibilities.
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
  "direction_id": "direction-011-package-readmes-and-haddock",
  "extracted_item_id": "item-046-package-readmes-and-haddock"
}
```

### Boundaries
- In scope: package-facing README documentation for the three workflow package candidates; Haddock-facing module documentation for exposed public API surfaces where it clarifies package identity, supported contracts, and ownership boundaries; docs text that points to existing package identity, metadata, compatibility, validation, and boundary evidence; verification that docs describe implemented APIs and public non-goals truthfully.
- Out of scope: examples or consumer guides, changelog entries, release notes, package upload or publication, release-candidate bundle assembly, final publication gate decisions, package renaming or version policy changes, package descriptor/layout rewrites except minimal documentation references if a planner proves they are required, compatibility facade removal, event schema or golden fixture changes, CI matrix redesign, validation-script redesign, moving moifold issue/PR lifecycle/runtime/healthcheck/repair/prompt policy into reusable packages, `orchestrator/state.json`, implementation plans, review artifacts, and merge artifacts.
- Concurrent batch context: none; controller state is serial with `max_parallel_rounds=1`, no active round is present, and this extraction should run as a single docs-release slice before examples, release notes, consumer validation, or release-gate work.

### Scheduler Fields
```json
{
  "depends_on_round_ids": [
    "round-036",
    "round-039",
    "round-040",
    "round-041",
    "round-042",
    "round-045"
  ],
  "merge_after_item_ids": [
    "item-036-package-names-and-versioning",
    "item-039-core-package-layout",
    "item-040-codex-package-layout",
    "item-041-github-package-layout",
    "item-042-moifold-local-consumer-wiring",
    "item-045-boundary-test-refresh-for-package-layout"
  ],
  "parallel_group": null,
  "merge_ready": false
}
```

### Rationale
The active controller state records `last_completed_round` as `round-045`, has no active or pending merge rounds, and points to roadmap `2026-05-09-00-external-package-extraction` revision `rev-001`. The roadmap marks milestones 001, 002, and 003 complete: package identity and metadata policy are settled, standalone package descriptors and local moifold consumption are in place, release validation and CI are repeatable, and round 045 refreshed package-boundary assertions for the external-package layout.

`direction-011-package-readmes-and-haddock` is dependency-ready because its preconditions, stable package names and exposed modules, are satisfied by the completed identity, package-layout, moifold-consumer-wiring, and boundary-test rounds. It is the smallest next valuable extraction in pending milestone 004 and should precede examples, changelog/release notes, consumer validation, and release-gate work so later public-facing artifacts inherit accurate package scope, supported API claims, and non-goals without implying package publication or moving moifold-owned lifecycle policy into the reusable workflow packages.
