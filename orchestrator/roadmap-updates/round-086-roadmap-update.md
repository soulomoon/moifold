### Source Round
- Round id: `round-086`
- Merged commit: `0dc85da`
- Evidence: `orchestrator/rounds/round-086/selection.md`, `orchestrator/rounds/round-086/plan.md`, `orchestrator/rounds/round-086/implementation-notes.md`, `orchestrator/rounds/round-086/review.md`, `orchestrator/rounds/round-086/review-record.json`, `orchestrator/rounds/round-086/merge.md`, and merged commit `0dc85da`

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-001`
- Proposed revision: `rev-001`
- Files changed: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`, `orchestrator/roadmap-updates/round-086-roadmap-update.md`

### Rationale
Round 086 completed `direction-004-workflow-behavior-test-split` under `milestone-001-test-topology-inventory`. The merged change split the selected workflow behavior coverage out of `test/Main.hs` into focused watcher-core test modules for event-log behavior, agent/facade behavior, indexed workflow behavior, DocsMigration behavior, and execution behavior, added shared test-only support, kept `workflowFacadeExtractionTests` as the aggregation path, and added only the required `watcher-core-test` `other-modules` metadata.

This is a status-only update within `rev-001`: the existing milestone and direction structure already represented this work, and the merge does not add a new dependency, ordering constraint, or coordination boundary that requires a new revision.

`milestone-001-test-topology-inventory` is now complete. Its completion signal required a cleanup inventory, focused ownership for reusable package-boundary scanners and facade/import-policy checks, measurable `test/Main.hs` reduction, preserved runner coverage, and named remaining facade, fixture, and large-module gates. Rounds 083, 084, and 085 already satisfied the inventory, boundary scanner, and facade/import-policy pieces; round 086 satisfies the remaining workflow behavior test split. Reviewer evidence records runner reachability, preserved assertion and PASS labels, `test/Main.hs` reduction from 15473 to 7120 lines, `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and `git diff --cached --check`.

The next roadmap dependency layer can now use milestone 001 as complete, including compatibility fixture/runtime-state contract work, import convergence/package-boundary cleanup, and large runtime module decomposition when selected under their own directions. This update does not mark the family done; later milestones remain pending and the terminal compatibility-removal success criteria still apply.

The update preserves the roadmap's non-removal boundaries. Round 086 changed test modules, watcher-core test-suite metadata, and round-local artifacts only; it does not approve production import convergence, public deprecation, facade removal, Cabal exposure removal, runtime compatibility-file removal, compatibility-file rename/deletion, fixture changes, docs changes, release/publication work, or any change to the public availability of `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.EventLog`, or `CodexWatcher.Workflow.Permission`.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
