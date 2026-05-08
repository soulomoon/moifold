### Selected Extraction
- Milestone: Build Standalone Package Layout
- Milestone id: milestone-002-standalone-package-layout
- Direction id: direction-006-github-package-layout
- Extracted item id: item-041-github-package-layout
- Extracted item summary: Create or validate the standalone `agent-workflow-github` package descriptor and build surface from the current internal sublibrary, preserving the existing `agent-workflow-github/src` module layout and proving the GitHub identifiers, remote metadata, and pure command rendering helpers build outside the main moifold library.
- Roadmap id: 2026-05-09-00-external-package-extraction
- Roadmap revision: rev-001
- Roadmap dir: orchestrator/roadmaps/2026-05-09-00-external-package-extraction/rev-001

### Boundaries
- In scope: standalone `agent-workflow-github` package descriptor or equivalent local package build surface; package metadata required by the approved package identity and release metadata policies; local build/check wiring needed to validate the GitHub package candidate against the standalone `agent-workflow-core` package; boundary-test updates only if the layout change requires them; evidence that GitHub identifiers, remote metadata, pure parsing, and command rendering helpers remain in the GitHub adapter package.
- Out of scope: moifold local-consumer rewiring, compatibility facade removal, deprecation pragmas, production behavior changes, command execution, healthcheck, PR/issue lifecycle policy, merge/review publication policy, event schema or golden fixture changes, source-distribution generation, CI matrix changes, public docs/examples, changelog or release-note preparation, package upload, roadmap edits, `orchestrator/state.json`, `plan.md`, implementation notes, review artifacts, and merge artifacts.
- Concurrent batch context: none; the active roadmap default lane is serial, controller state allows one active round, and `direction-006-github-package-layout` should complete the remaining standalone adapter descriptor before `direction-007-moifold-local-consumer-wiring` depends on all package descriptors being locally buildable.

### Scheduler Fields
```json
{
  "depends_on_round_ids": [
    "round-039",
    "round-040"
  ],
  "merge_after_item_ids": [
    "item-040-codex-package-layout"
  ],
  "parallel_group": null,
  "merge_ready": false
}
```

### Rationale
Milestone 001 is complete after rounds 036, 037, and 038 recorded the package identity/versioning contract, release metadata policy, and compatibility/deprecation policy. Round 039 completed `direction-004-core-package-layout`, and round 040 completed `direction-005-codex-package-layout`, leaving `direction-006-github-package-layout` and `direction-007-moifold-local-consumer-wiring` pending in milestone 002.

`direction-006-github-package-layout` is dependency-ready now because the roadmap requires package identity and metadata policy to be approved, and the core package layout is already available as the shared local dependency for adapter package candidates. The roadmap allows GitHub layout to run beside Codex layout only when ownership is disjoint, but the current controller state is serial and Codex layout has already merged, so this round should merge after `item-040-codex-package-layout`.

Selecting GitHub layout before moifold consumer wiring preserves the milestone order: `direction-007-moifold-local-consumer-wiring` requires package descriptors to be locally buildable, so the remaining standalone adapter package should be established first without pulling command execution, healthcheck, PR/issue lifecycle, merge/review publication policy, compatibility facade removal, release artifacts, or upload work into this round.
