### Selected Extraction
- Milestone: Build Standalone Package Layout
- Milestone id: milestone-002-standalone-package-layout
- Direction id: direction-007-moifold-local-consumer-wiring
- Extracted item id: item-042-moifold-local-consumer-wiring
- Extracted item summary: Wire moifold to consume the local `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github` package candidates while preserving existing compatibility facades and current behavior.
- Roadmap id: 2026-05-09-00-external-package-extraction
- Roadmap revision: rev-001
- Roadmap dir: orchestrator/roadmaps/2026-05-09-00-external-package-extraction/rev-001

### Selection Metadata
```json
{
  "roadmap_id": "2026-05-09-00-external-package-extraction",
  "roadmap_revision": "rev-001",
  "roadmap_dir": "orchestrator/roadmaps/2026-05-09-00-external-package-extraction/rev-001",
  "milestone_id": "milestone-002-standalone-package-layout",
  "direction_id": "direction-007-moifold-local-consumer-wiring",
  "extracted_item_id": "item-042-moifold-local-consumer-wiring"
}
```

### Boundaries
- In scope: local moifold package/project dependency wiring needed for the main product to consume the standalone workflow package candidates; minimal package-boundary assertion updates required by that wiring; compatibility facade imports kept available; evidence that `cabal build all` and `cabal test watcher-core-test` still cover moifold behavior after the consumer change.
- Out of scope: removing or deprecating compatibility modules, changing event schemas or golden fixtures, moving moifold issue/PR lifecycle policy into reusable packages, changing prompt/runtime/healthcheck/repair/daemon ownership behavior, generating source distributions, adding CI matrix work, public docs/examples, changelog or release-note preparation, package upload, roadmap edits, `orchestrator/state.json`, `plan.md`, implementation notes, review artifacts, and merge artifacts.
- Concurrent batch context: none; the active roadmap default lane is serial, controller state allows one active round, and this consumer-wiring slice depends on the standalone core, Codex, and GitHub package layouts already being locally buildable.

### Scheduler Fields
```json
{
  "depends_on_round_ids": [
    "round-039",
    "round-040",
    "round-041"
  ],
  "merge_after_item_ids": [
    "item-041-github-package-layout"
  ],
  "parallel_group": null,
  "merge_ready": false
}
```

### Rationale
Milestone 001 is complete after rounds 036, 037, and 038 recorded the package identity/versioning contract, release metadata policy, and compatibility/deprecation policy. In milestone 002, rounds 039, 040, and 041 completed `direction-004-core-package-layout`, `direction-005-codex-package-layout`, and `direction-006-github-package-layout`, leaving `direction-007-moifold-local-consumer-wiring` as the only pending standalone package layout direction.

`direction-007-moifold-local-consumer-wiring` is dependency-ready because the roadmap precondition requires locally buildable package descriptors, and the active roadmap now records standalone package layout completion for core, Codex, and GitHub. The serial controller state and roadmap default lane mean this round should depend on rounds 039 through 041 and merge after `item-041-github-package-layout`.

Selecting this item now closes the remaining milestone 002 extraction without broadening into release validation, CI, docs, source distributions, or package publication. The round should prove moifold can consume the local package candidates while retaining the compatibility facades and behavior guarantees protected by the project contract and verification contract.
