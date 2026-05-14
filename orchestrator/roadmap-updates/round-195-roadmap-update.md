### Source Round
- Round id: `round-195`
- Merged commit: `3c3e6f8dad53bf55511d467ab7a4168e4ad505e0`
- Evidence: `orchestrator/rounds/round-195/selection.md` selected `milestone-004-core-ids-test-and-fixture-import-burndown`, `direction-011j-core-ids-policy-and-aggregator-classification`, and extracted item `direction-011j-core-ids-policy-aggregator-classification`; `orchestrator/rounds/round-195/implementation-notes.md` classified `test/FacadeImportPolicySpec.hs:11` as intentional facade-policy evidence and `test/Main.hs:67` as intentional watcher-core-test aggregate/property wiring evidence; `orchestrator/rounds/round-195/review.md` and `orchestrator/rounds/round-195/review-record.json` approved the artifact-only classification after focused scans found only those two remaining test imports and the broader scan found only out-of-scope public facade, Cabal exposure, and docs/policy references.

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-002`
- Proposed revision: `rev-002`
- Files changed: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-002/roadmap.md`, `orchestrator/roadmap-updates/round-195-roadmap-update.md`

### Rationale
Round 195 completes the remaining direction 011j question without changing production code, tests, fixtures, docs, Cabal files, public APIs, runtime compatibility files, or behavior surfaces. The only remaining test imports of `CodexWatcher.Core.Ids` are now explicitly classified with reviewer-approved reasons:

- `test/FacadeImportPolicySpec.hs:11` intentionally imports the facade as facade-policy evidence.
- `test/Main.hs:67` intentionally imports the facade as watcher-core-test aggregate/property wiring evidence.

Rounds 187 through 194 had already migrated the safe workflow, CLI, runtime, and runtime-compatibility fixture test imports. With round 195 approved, every safe test/fixture `Core.Ids` import has migrated and every remaining test import has been classified as an intentional policy or aggregate evidence owner. This satisfies the milestone 004 completion signal, so the active rev-002 roadmap is updated in place as status-only evidence: direction 011j is recorded complete and `milestone-004-core-ids-test-and-fixture-import-burndown` is marked `[completed]`.

This update preserves the public facade module, Cabal exposure, and docs/policy references for later public-surface milestones. It does not approve public facade removal, Cabal exposure cleanup, docs cleanup, package-boundary removal, runtime compatibility cleanup, release approval, terminal completion, or a new roadmap revision.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
