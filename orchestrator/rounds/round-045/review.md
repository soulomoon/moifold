### Checks Run
- Command: `git diff --stat`
  Result: pass for scope inspection. The implementation code diff is in `test/Main.hs`; no package descriptors are modified. The worktree also contains controller activation in `orchestrator/state.json` and round artifacts.
- Command: `git diff -- test/Main.hs`
  Result: pass for review. The diff adds `workflowCabalProjectListsStandaloneWorkflowPackages`, exact Cabal exposed-module parsing, recursive source-module inventory helpers, and exact source/exposed inventory assertions for the core, Codex, and GitHub standalone packages.
- Command: `git diff --name-only`
  Result: pass for descriptor scope. Modified tracked files are `orchestrator/state.json` and `test/Main.hs`; no `agent-workflow-*/*.cabal`, `cabal.project`, or `moifold.cabal` descriptor changes are present.
- Command: `cabal test watcher-core-test`
  Result: pass. `Test suite watcher-core-test: PASS`; 1 of 1 test suites passed. Output included a runtime lease warning, but the suite completed successfully.
- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`.
- Command: `scripts/validate-workflow-packages.sh`
  Result: pass. The script ran `cabal check` for all three workflow packages, generated and inspected the expected source distributions, and printed `No upload or package publication command was run.`
- Command: `git diff --check`
  Result: pass. No whitespace errors.
- Command: `git diff --cached --quiet -- . && printf '%s\n' 'No staged diff; git diff --cached --check not applicable' || git diff --cached --check`
  Result: pass. No staged diff, so cached diff check was not applicable.
- Command: `rg -n 'workflowCabalProjectListsStandaloneWorkflowPackages|cabalExposedModules|sourceModulesUnder|sourceModuleFromPath|workflowCoreStandalonePackageKeepsPackageBoundary|workflowCodexStandalonePackageKeepsPackageBoundary|workflowGithubStandalonePackageKeepsPackageBoundary' test/Main.hs`
  Result: pass. The new project assertion, Cabal/source helpers, and strengthened package boundary tests are present in `test/Main.hs`.
- Command: `rg -n 'cabal[[:space:]]+upload|stack[[:space:]]+upload|hackage-upload|curl[[:space:]].*hackage' .`
  Result: pass for no-upload review. Matches are limited to orchestrator notes, plans, and review records quoting the scan terms from rounds 043, 044, and 045. No real upload or publication command was introduced in code, scripts, CI, package descriptors, or config.

### Plan Compliance
- Reconfirm current package layout inputs: met. `cabal.project` lists `.` plus `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`; no package descriptors changed.
- Keep the existing boundary tests: met. `workflowMoifoldCabalConsumesStandaloneWorkflowPackages`, `workflowCoreStandalonePackageKeepsPackageBoundary`, `workflowCodexStandalonePackageKeepsPackageBoundary`, `workflowGithubStandalonePackageKeepsPackageBoundary`, and `workflowMoifoldCabalLibraryDoesNotReexportAdapters` remain in the `workflowFacadeExtractionTests` list.
- Add `workflowCabalProjectListsStandaloneWorkflowPackages`: met. The new test asserts exact `cabal.project` package entries and rejects old `moifold:agent-workflow-*` references.
- Add narrow test-local Cabal/source helpers: met. `cabalFieldLines`, `cabalFieldEntries`, `cabalExposedModules`, `sourceModulesUnder`, and `sourceModuleFromPath` are added in `test/Main.hs`.
- Strengthen standalone package boundary tests with exact source/exposed inventories: met. Each standalone package now compares recursive `src/**/*.hs` module names against parsed Cabal `exposed-modules`.
- Preserve explicit exposed-module ownership checks: met. Hand-approved inventories remain as `coreStandaloneExposedModules`, `codexStandaloneExposedModules`, and `githubStandaloneExposedModules`, now checked exactly against parsed Cabal modules instead of broad substring presence.
- Strengthen moifold consumer assertions without weakening existing checks: met. The test now parses `build-depends` package names for the main library and `watcher-core-test`, while keeping internal-sublibrary rejection and approved `>=0.1 && <0.2` bound checks.
- Preserve forbidden import/token/dependency/metadata/no-reexport checks: met. The existing recursive forbidden import and text/token scans remain present, approved dependency sets remain enforced, package metadata checks remain present, and no-reexport coverage remains in the test list.
- Avoid unnecessary descriptor or behavior changes: met. No package descriptor, `cabal.project`, `moifold.cabal`, implementation module, docs, CI, event/golden fixture, or package version changes are present in the implementation diff.
- Avoid upload/publication behavior: met. The validation script reports no upload, and the repository-wide upload scan only finds quoted scan terms in orchestrator artifacts.

### Decision
**APPROVED**

### Evidence
The implementation strengthens the intended package-boundary assertions. A new `cabal.project` assertion proves the local package list is exactly the root package plus the three standalone workflow packages, and the old internal `moifold:agent-workflow-*` references remain rejected. The core, Codex, and GitHub boundary tests now require recursive source-module inventories to match parsed Cabal `exposed-modules`, which closes the layout-drift gap described in the plan.

The existing boundary surfaces were not weakened. Forbidden import scans, forbidden token/text scans, approved dependency checks, metadata checks, moifold consumer checks, and adapter no-reexport coverage remain present. The explicit approved exposed-module lists are still enforced, now with exact mismatch diagnostics.

No package descriptors were changed, and no package upload or publication behavior was added. All requested baseline and round-specific checks passed locally.
