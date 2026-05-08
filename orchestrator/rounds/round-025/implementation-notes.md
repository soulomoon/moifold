### Changes Made
- test/Main.hs: Added `workflowSpecInventoryCoversCurrentSpecSurfaces`, a source-scan baseline for the current unindexed `WorkflowSpec` hooks, indexed `IndexedWorkflowSpec` hooks and existential helpers, the `MoifoldSpec` and `DocsMigrationSpec` instances, and the existing moifold indexed adapter modules.
- test/Main.hs: Added `workflowDocsMigrationIndexedLawMatchesUnindexedDraftReplayTerminalAndPermissions`, covering the draft-produced DocsMigration observation path across unindexed and indexed plans, replay-state labels, terminal checks, validation, and effect permission hooks.
- test/Main.hs: Extended the compact PR-review mergeability law to assert indexed projection event labels, source/target labels, pre/post effect labels, effect plans, and terminal status against the unindexed facade.
- orchestrator/rounds/round-025/implementation-notes.md: Recorded this implementation summary and validation results.

### Tests
- test/Main.hs: `workflowSpecInventoryCoversCurrentSpecSurfaces` verifies the current spec API inventory stays visible in focused workflow facade extraction coverage.
- test/Main.hs: `workflowDocsMigrationIndexedLawMatchesUnindexedDraftReplayTerminalAndPermissions` verifies DocsMigration unindexed/indexed parity for observation, replay label projection, terminal state checks, validation, and effect permissions.
- test/Main.hs: `workflowPrReviewMergeabilityFacadeLawPreservesObservationReplayEffectsAndPermissions` now also verifies indexed PR-review mergeability labels, effects, and terminal status.
- Command: `cabal test watcher-core-test --test-option=--match --test-option='workflow facade extraction'` before edits. Result: passed.
- Command: `cabal test watcher-core-test --test-option=--match --test-option='workflow facade extraction'` after edits. Result: passed.
- Command: `cabal test watcher-core-test`. Result: passed.
- Command: `cabal build all`. Result: passed.
- Command: `git diff --check`. Result: passed.
- Command: `git diff --cached --check`. Result: passed; no staged changes.

### Notes
No runtime, production, event codec, golden fixture, roadmap, state, selection, plan, review, or merge artifact behavior was changed. The only implementation code change is the focused test/source-scan baseline in `test/Main.hs`; `orchestrator/state.json`, `selection.md`, and `plan.md` were left untouched.
