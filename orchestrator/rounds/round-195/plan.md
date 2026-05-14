### Goal
Classify the remaining test `CodexWatcher.Core.Ids` imports in `test/FacadeImportPolicySpec.hs` and `test/Main.hs` as intentional policy and aggregate evidence surfaces, and record scan evidence that no other safe test or fixture `Core.Ids` imports remain in this milestone slice.

### Approach
Keep this round artifact-only and sequential. Do not migrate either selected file. The implementer should inspect the two remaining imports and write round-local classification evidence that distinguishes their roles:

- `test/FacadeImportPolicySpec.hs` intentionally imports `CodexWatcher.Core.Ids` because the spec is a facade/import-policy surface. It exercises the combined compatibility facade alongside boundary, replay, workflow event-log, and workflow permission facade checks, so retaining the import is policy evidence rather than missed direct-owner migration.
- `test/Main.hs` intentionally imports `CodexWatcher.Core.Ids` because it is the `watcher-core-test` aggregate entrypoint and broad property-test wiring surface. It centralizes shared `Arbitrary` instances, constructors, helper values, and aggregate property coverage across agent ids and GitHub ids, so retaining the combined facade is aggregate evidence rather than a narrow safe migration.

Use the active roadmap verification contract for `2026-05-11-00-highest-value-cleanup` rev-002 and the stable invariants in `orchestrator/project-contract.md`. This round must not edit production modules, test modules, fixtures, docs, Cabal files, public facade exports, runtime compatibility files, policy assertions, aggregate wiring, roadmap files, milestone status, or `orchestrator/state.json`. It does not approve facade deprecation, Cabal exposure cleanup, docs cleanup, public removal, release approval, milestone completion, or terminal roadmap completion.

No worker fan-out is justified. The work is a single artifact-only classification pass over two coupled evidence surfaces with shared scan verification, and the active state is serial.

### Steps
1. Re-read `orchestrator/rounds/round-195/selection.md`, `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-002/verification.md`, and `orchestrator/project-contract.md` to confirm the selected boundaries and artifact-only allowance.
2. Inspect `test/FacadeImportPolicySpec.hs` and record that its exact remaining import is `import CodexWatcher.Core.Ids` at line 11.
3. Classify `test/FacadeImportPolicySpec.hs` as intentional facade-policy evidence because it tests facade replay, package-boundary policy, workflow event-log facade behavior, workflow permission facade behavior, and related compatibility assertions against the combined `Core.Ids` facade.
4. Inspect `test/Main.hs` and record that its exact remaining import is `import CodexWatcher.Core.Ids` at line 67.
5. Classify `test/Main.hs` as intentional aggregate/property wiring evidence because it is the watcher-core-test entrypoint, owns broad shared `Arbitrary` instances and helper constructors for ids, and wires many behavior/property tests that use both agent-id and GitHub-id surfaces.
6. Run an import-focused scan over tests and fixtures, for example `rg -n "^import CodexWatcher\\.Core\\.Ids" test golden`, and record that the only test matches are `test/FacadeImportPolicySpec.hs` and `test/Main.hs`; no fixture imports remain.
7. Run a broader context scan, for example `rg -n "CodexWatcher\\.Core\\.Ids|Core/Ids|Core\\.Ids" test golden src app agent-workflow-core agent-workflow-codex agent-workflow-github moifold.cabal docs README.md`, and record remaining non-test matches separately as out of scope: the public facade module, Cabal exposure, and docs/policy references.
8. Write only round-local classification evidence for this round, preserving all source, test, fixture, docs, Cabal, roadmap, and state files unchanged.

### Verification
Verify the artifact-only result with changed-path and scan evidence:

1. `git diff --name-only`
   - Expected: only round-local orchestrator artifact paths for round 195 are changed by this slice.
2. `git status --short`
   - Expected: no production source, test source, fixture, docs, Cabal, roadmap, or `orchestrator/state.json` edits are introduced by this slice.
3. `rg -n "^import CodexWatcher\\.Core\\.Ids" test golden`
   - Expected: only `test/FacadeImportPolicySpec.hs:11` and `test/Main.hs:67`; no fixture import matches.
4. `rg -n "CodexWatcher\\.Core\\.Ids|Core/Ids|Core\\.Ids" test golden src app agent-workflow-core agent-workflow-codex agent-workflow-github moifold.cabal docs README.md`
   - Expected: selected test imports plus out-of-scope public facade, Cabal exposure, and docs/policy references; no additional safe test or fixture migration candidates.
5. `git diff --check`

Per the active rev-002 verification contract, Cabal build and test baselines may be skipped only because the diff is limited to round-local artifact-only classification and does not touch production code, test code, package descriptors, runtime compatibility files, public APIs, fixtures, docs, or behavior surfaces. If any implementation/test/source/docs/Cabal path changes, require the relevant baseline, including `cabal test watcher-core-test` and `cabal build all`.

### Worker Fan-Out
No worker fan-out. Do not write `worker-plan.json`.
