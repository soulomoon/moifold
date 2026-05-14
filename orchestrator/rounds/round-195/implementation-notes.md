### Changes Made
- `orchestrator/rounds/round-195/implementation-notes.md`: added classification evidence for the two remaining test `CodexWatcher.Core.Ids` imports selected by round 195.

### Tests
- No production code, test code, fixtures, docs, Cabal files, roadmap files, or `orchestrator/state.json` were edited. Per `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-002/verification.md`, Cabal build/test baselines were skipped because this diff is limited to round-local artifact-only classification.
- `git diff --name-only`: reported only `orchestrator/state.json`, which was already modified before this implementer pass and was not edited by this round. The new round notes are untracked, so they are visible in `git status --short` rather than tracked diff output.
- `git status --short`: reported pre-existing ` M orchestrator/state.json` plus untracked `?? orchestrator/rounds/round-195/`. No production source, test source, fixture, docs, Cabal, roadmap, or new `orchestrator/state.json` edits were introduced by this slice.
- `rg -n "^import CodexWatcher\\.Core\\.Ids" test golden`: found only `test/FacadeImportPolicySpec.hs:11` and `test/Main.hs:67`; no `golden` fixture imports matched.
- `rg -n "CodexWatcher\\.Core\\.Ids|Core/Ids|Core\\.Ids" test golden src app agent-workflow-core agent-workflow-codex agent-workflow-github moifold.cabal docs README.md`: found the two selected test imports plus out-of-scope non-test references in the public facade module, Cabal exposure, and docs/policy files. No additional safe test or fixture migration candidates remain in the scanned paths.
- `git diff --check`: passed.

### Notes
`test/FacadeImportPolicySpec.hs:11` intentionally imports `CodexWatcher.Core.Ids`. This file is a facade/import-policy evidence surface, not a missed narrow migration candidate. Its checks cover facade replay behavior, workflow package-boundary policy, workflow event-log facade behavior, workflow permission facade behavior, and related compatibility assertions against the combined `Core.Ids` facade.

`test/Main.hs:67` intentionally imports `CodexWatcher.Core.Ids`. This file is the `watcher-core-test` aggregate entrypoint and broad property-test wiring surface. It centralizes shared `Arbitrary` instances, helper constructors, and aggregate behavior/property coverage across agent id and GitHub id surfaces, so keeping the combined facade here is aggregate wiring evidence rather than a safe direct-owner import migration.

The remaining non-test `Core.Ids` references are out of scope for this round: `src/CodexWatcher/Core/Ids.hs` is the public facade module, `moifold.cabal` exposes that facade, and the docs/policy references record compatibility and import-policy status. This classification does not imply public facade deprecation, Cabal exposure cleanup, docs cleanup, removal approval, release approval, milestone completion, or terminal roadmap completion.
