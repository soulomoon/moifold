### Source Round
- Round id: `round-084`
- Merged commit: `83cac48`
- Evidence: `orchestrator/rounds/round-084/selection.md`, `orchestrator/rounds/round-084/plan.md`, `orchestrator/rounds/round-084/implementation-notes.md`, `orchestrator/rounds/round-084/review.md`, `orchestrator/rounds/round-084/review-record.json`, `orchestrator/rounds/round-084/merge.md`, and merged commit `83cac48`

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-001`
- Proposed revision: `rev-001`
- Files changed: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`, `orchestrator/roadmap-updates/round-084-roadmap-update.md`

### Rationale
Round 084 completed `direction-002-boundary-policy-test-module-split` under `milestone-001-test-topology-inventory`. The merged change split reusable source-scan helpers and boundary-policy assertions out of `test/Main.hs` into `test/BoundaryPolicySpec.hs` and `test/TestSupport/SourceScan.hs`, kept the existing `workflowFacadeExtractionTests` aggregation path reaching the extracted runner, and added only the required `watcher-core-test` `other-modules` metadata.

This is a status-only update within `rev-001`: the existing milestone and direction structure already represented the completed work, and the merge does not create a new sequencing dependency or coordination boundary that needs a new revision. The direction is now complete because reviewer evidence records `cabal test watcher-core-test`, `cabal build all`, diff hygiene, reachability checks, assertion preservation, changed-path inventory, and a measured `test/Main.hs` reduction from 16956 to 15910 lines.

`milestone-001-test-topology-inventory` remains pending. Its completion signal also requires focused test modules to own facade/import-policy checks and workflow behavior tests, and directions 003 and 004 remain open after this boundary-policy split.

The update preserves the roadmap's non-removal boundaries. Round 084 changed test modules and watcher-core test-suite metadata only; it does not approve production import convergence, public deprecation, facade removal, Cabal exposure removal, runtime compatibility-file removal, compatibility-file rename/deletion, fixture changes, docs changes, or release/publication work.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
