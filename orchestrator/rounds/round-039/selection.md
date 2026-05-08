### Selected Extraction
- Milestone: Build Standalone Package Layout
- Milestone id: milestone-002-standalone-package-layout
- Direction id: direction-004-core-package-layout
- Extracted item id: item-039-core-package-layout
- Extracted item summary: Create or validate the first standalone `agent-workflow-core` package descriptor and build surface from the current internal sublibrary, preserving the existing `agent-workflow-core/src` module layout and core-only dependency boundary before adapter descriptors or moifold consumer rewiring begin.
- Roadmap id: 2026-05-09-00-external-package-extraction
- Roadmap revision: rev-001
- Roadmap dir: orchestrator/roadmaps/2026-05-09-00-external-package-extraction/rev-001

### Boundaries
- In scope: standalone `agent-workflow-core` package descriptor or equivalent local package build surface; package metadata required by the approved package identity and release metadata policies; local build/check wiring needed to validate the core package candidate; boundary-test updates only if the layout change requires them; evidence that core remains free of Aeson, Codex, GitHub, moifold lifecycle, filesystem, runtime, and concrete event ownership.
- Out of scope: standalone `agent-workflow-codex` or `agent-workflow-github` descriptors, moifold local-consumer rewiring, compatibility facade removal, deprecation pragmas, production behavior changes, event schema or golden fixture changes, source-distribution generation, CI matrix changes, public docs/examples, changelog or release-note preparation, package upload, roadmap edits, `orchestrator/state.json`, `plan.md`, implementation notes, review artifacts, and merge artifacts.
- Concurrent batch context: none; the active roadmap default lane is serial, controller state allows one active round, and `direction-004-core-package-layout` should establish the core package boundary before adapter package layout work depends on it.

### Scheduler Fields
```json
{
  "depends_on_round_ids": [],
  "merge_after_item_ids": [],
  "parallel_group": null,
  "merge_ready": false
}
```

### Rationale
Milestone 001 is complete after rounds 036, 037, and 038 recorded the package identity/versioning contract, release metadata policy, and compatibility/deprecation policy. That satisfies milestone 002's dependency on `milestone-001-package-identity-release-contract` and makes standalone package layout the next dependency-ready milestone in the active strategy-backlog roadmap.

Within milestone 002, `direction-004-core-package-layout` should run first because the roadmap states that core package layout matters before Codex adapter and moifold consumer wiring, and `direction-005-codex-package-layout` depends on the core package layout being buildable or explicitly stubbed as a local dependency. The repository already has an internal `agent-workflow-core` sublibrary and `agent-workflow-core/src` source tree, so this round should focus on making that core package candidate independently buildable and checkable without broadening ownership into adapters or moifold runtime policy.
