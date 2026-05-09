### Changes Made
- `orchestrator/rounds/round-052/import-facade-inventory.md`: added the evidence-only inventory for the selected Haskell compatibility import facades. The report records source-backed module shape, Cabal exposed-module status, current repo-local users, preferred replacement imports, protecting tests, scan evidence, and unresolved unknowns for `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.Types`, `CodexWatcher.Workflow.EventLog`, `CodexWatcher.Workflow.Execution`, and `CodexWatcher.Workflow.Permission`.
- `orchestrator/rounds/round-052/implementation-notes.md`: recorded this implementer summary and verification evidence.

### Tests
- `test/Main.hs`: existing package-boundary and compatibility assertions were identified as protecting coverage for the inventory, including adapter ownership checks, standalone package exposed-module checks, workflow event-log facade/core parity, execution facade dry-run parity, permission facade/core parity, planned-transition facade behavior, and indexed workflow compatibility checks.
- `test/AppServerSpec.hs`, `test/CliSpec.hs`, `test/GhGitSpec.hs`, and `test/RuntimeSpec.hs`: existing focused specs compile through selected facades such as `CodexWatcher.AppServerClient` and `CodexWatcher.Core.Ids`; no test source was changed in this evidence-only round.

### Notes
Verification commands run from the round worktree:

- `rg -n "import CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.(Types|EventLog|Execution|Permission))" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`: passed; found selected facade imports plus expected broad-regex matches for replacement/core submodules such as `Workflow.EventLog.Core`, `Workflow.EventLog.Commit.Core`, `Workflow.EventLog.File.Core`, `Workflow.Execution.Core`, and `Workflow.Permission.Core`.
- `rg -n "CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.(Types|EventLog|Execution|Permission))" README.md docs agent-workflow-core agent-workflow-codex agent-workflow-github examples *.cabal */*.cabal`: passed; found selected facades in `moifold.cabal` and docs, and replacement/core modules in package candidate Cabal files, READMEs, and public framework docs.
- `rg -n "exposed-modules|other-modules|CodexWatcher\\.AppServerClient|CodexWatcher\\.Core\\.Ids|CodexWatcher\\.Workflow\\.(Types|EventLog|Execution|Permission)" *.cabal */*.cabal`: passed; confirmed selected facades are exposed by the main `moifold` library and replacement/core modules are exposed by standalone workflow package candidates.
- `cabal test watcher-core-test`: passed. Final output: `Test suite watcher-core-test: PASS` and `1 of 1 test suites (1 of 1 test cases) passed.`
- `scripts/validate-workflow-packages.sh`: passed. It ran `cabal check` for `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`, produced local source distributions under `dist-newstyle/sdist`, validated their package roots and Cabal files, and ran no upload/publication command.
- `git diff --check`: passed.

The round intentionally did not edit production source, `orchestrator/state.json`, roadmap files, reviews, merge notes, policy docs, Cabal descriptors, imports, runtime compatibility files, or deprecation/removal status.
