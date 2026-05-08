### Changes Made
- `test/Main.hs`: Added `workflowCabalProjectListsStandaloneWorkflowPackages` to assert `cabal.project` lists exactly `.` plus `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`, with no `moifold:agent-workflow-*` internal sublibrary references.
- `test/Main.hs`: Added narrow Cabal multiline-field helpers (`cabalFieldLines`, `cabalFieldEntries`, `cabalExposedModules`) and source inventory helpers (`sourceModulesUnder`, `sourceModuleFromPath`) that reuse the existing recursive `sourceFilesUnder` scan.
- `test/Main.hs`: Strengthened the core, Codex, and GitHub standalone package boundary tests so each package's recursive `src/**/*.hs` module inventory must exactly match the Cabal library `exposed-modules` inventory, while preserving the existing forbidden import, forbidden token, dependency, metadata, and no-reexport assertions.
- `test/Main.hs`: Strengthened the moifold consumer assertion so parsed `build-depends` package names for the main library and `watcher-core-test` must include all three standalone workflow packages, while preserving approved `>=0.1 && <0.2` bound checks and internal-sublibrary rejection.

### Tests
- `test/Main.hs`: Verifies `cabal.project`, `moifold.cabal`, standalone package descriptors, and recursive source trees agree on the standalone workflow package layout.
- Passed: `cabal test watcher-core-test`.
- Passed: `cabal build all`.
- Passed: `scripts/validate-workflow-packages.sh`. This generated local validation tarballs under `dist-newstyle/sdist/`.
- Passed: `git diff --check`.
- Passed: `git diff --cached --quiet -- . && printf '%s\n' 'No staged diff; git diff --cached --check not applicable' || git diff --cached --check` reported no staged diff.
- Passed: `rg -n 'workflowCabalProjectListsStandaloneWorkflowPackages|cabalExposedModules|sourceModulesUnder|sourceModuleFromPath|workflowCoreStandalonePackageKeepsPackageBoundary|workflowCodexStandalonePackageKeepsPackageBoundary|workflowGithubStandalonePackageKeepsPackageBoundary' test/Main.hs`.
- Reviewed: `rg -n 'cabal[[:space:]]+upload|stack[[:space:]]+upload|hackage-upload|curl[[:space:]].*hackage' .` matched only orchestrator round notes/plans/review records that quote scan terms, including this implementation note; no actual publication command was introduced in code, scripts, or config.

### Notes
No package descriptor correction was needed; the current standalone source trees already matched their Cabal exposed-module inventories. I did not edit implementation modules, package metadata, docs, CI, fixtures, roadmap files, review/merge artifacts, or `orchestrator/state.json`.
