### Source Round
- Round id: `round-085`
- Merged commit: `fec075a`
- Evidence: `orchestrator/rounds/round-085/selection.md`, `orchestrator/rounds/round-085/plan.md`, `orchestrator/rounds/round-085/implementation-notes.md`, `orchestrator/rounds/round-085/review.md`, `orchestrator/rounds/round-085/review-record.json`, `orchestrator/rounds/round-085/merge.md`, and merged commit `fec075a`

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-001`
- Proposed revision: `rev-001`
- Files changed: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`, `orchestrator/roadmap-updates/round-085-roadmap-update.md`

### Rationale
Round 085 completed `direction-003-facade-import-policy-test-split` under `milestone-001-test-topology-inventory`. The merged change split the selected facade extraction, import-policy, and compatibility policy assertions out of `test/Main.hs` into `test/FacadeImportPolicySpec.hs`, kept `workflowFacadeExtractionTests` as the watcher-core test aggregation path reaching the extracted runner, and added only the required `watcher-core-test` `other-modules` metadata.

This is a status-only update within `rev-001`: the existing milestone and direction structure already represented this work, and the merge does not add a new dependency, ordering constraint, or coordination boundary that requires a new revision. The direction is now complete because reviewer evidence records `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, `git diff --cached --check`, runner reachability, preserved policy classifications, preserved source-scan detail, Cabal metadata scope, and a measured `test/Main.hs` reduction from 15910 to 15473 lines.

`milestone-001-test-topology-inventory` remains pending. Its completion signal also requires focused workflow behavior test extraction, and `direction-004-workflow-behavior-test-split` remains open after this facade/import-policy split.

The update preserves the roadmap's non-removal boundaries. Round 085 changed test modules, watcher-core test-suite metadata, and round-local artifacts only; it does not approve production import convergence, public deprecation, facade removal, Cabal exposure removal, runtime compatibility-file removal, compatibility-file rename/deletion, fixture changes, docs changes, release/publication work, or any change to the public availability of `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.EventLog`, or `CodexWatcher.Workflow.Permission`.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
