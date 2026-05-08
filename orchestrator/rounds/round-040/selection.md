### Selected Extraction
- Milestone: Build Standalone Package Layout
- Milestone id: milestone-002-standalone-package-layout
- Direction id: direction-005-codex-package-layout
- Extracted item id: item-040-codex-package-layout
- Extracted item summary: Create or validate the standalone `agent-workflow-codex` package descriptor and build surface from the current internal sublibrary, preserving the existing `agent-workflow-codex/src` module layout and proving the Codex app-server protocol, client, interpreter, and transport modules build outside the main moifold library.
- Roadmap id: 2026-05-09-00-external-package-extraction
- Roadmap revision: rev-001
- Roadmap dir: orchestrator/roadmaps/2026-05-09-00-external-package-extraction/rev-001

### Boundaries
- In scope: standalone `agent-workflow-codex` package descriptor or equivalent local package build surface; package metadata required by the approved package identity and release metadata policies; local build/check wiring needed to validate the Codex package candidate against the standalone `agent-workflow-core` package; boundary-test updates only if the layout change requires them; evidence that Codex app-server protocol/client/interpreter/transport ownership remains in the Codex adapter package.
- Out of scope: standalone `agent-workflow-github` descriptor, moifold local-consumer rewiring, compatibility facade removal, deprecation pragmas, production behavior changes, prompt policy changes, event schema or golden fixture changes, source-distribution generation, CI matrix changes, public docs/examples, changelog or release-note preparation, package upload, roadmap edits, `orchestrator/state.json`, `plan.md`, implementation notes, review artifacts, and merge artifacts.
- Concurrent batch context: none; the active roadmap default lane is serial, controller state allows one active round, and `direction-005-codex-package-layout` should establish the Codex adapter package boundary before moifold consumer rewiring depends on it.

### Scheduler Fields
```json
{
  "depends_on_round_ids": [
    "round-039"
  ],
  "merge_after_item_ids": [
    "item-039-core-package-layout"
  ],
  "parallel_group": null,
  "merge_ready": false
}
```

### Rationale
Milestone 001 is complete after rounds 036, 037, and 038 recorded the package identity/versioning contract, release metadata policy, and compatibility/deprecation policy. Round 039 then completed `direction-004-core-package-layout` by adding the standalone `agent-workflow-core` descriptor, local project wiring, and boundary assertions, satisfying the roadmap precondition for `direction-005-codex-package-layout` that the core package layout is buildable or explicitly available as a local dependency.

Within milestone 002, the next pending direction in dependency order is `direction-005-codex-package-layout`. The active roadmap leaves `direction-006-github-package-layout` potentially parallel only when descriptor/source ownership is disjoint, but the current controller state permits only one active round and the roadmap default lane is serial. Selecting the Codex adapter first keeps the slice small and source-backed: the repository already has an internal `agent-workflow-codex` sublibrary and `agent-workflow-codex/src` source tree, so this round should make that package candidate independently buildable and checkable without pulling in GitHub layout, moifold consumer wiring, compatibility facade removal, release artifacts, or publication work.
