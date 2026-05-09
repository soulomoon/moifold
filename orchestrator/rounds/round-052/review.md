### Checks Run

- Command: `cabal build all`
  Result: pass. Built `moifold-0.1.0.0` executable with GHC 9.12.2 and linked `moifold`.

- Command: `cabal test watcher-core-test`
  Result: pass. The watcher core test suite completed with `Test suite watcher-core-test: PASS` and `1 of 1 test suites (1 of 1 test cases) passed.`

- Command: `scripts/validate-workflow-packages.sh`
  Result: pass. `cabal check` reported no errors or warnings for `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`; the script also produced and validated local source distributions for all three packages and ran no upload or publication command.

- Command: `git diff --check`
  Result: pass. No whitespace errors were reported.

- Command: `git diff --cached --check`
  Result: pass. No staged whitespace errors were reported. No staging was expected or performed.

- Command: `rg -n "import CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.(Types|EventLog|Execution|Permission))" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
  Result: pass. The scan found true selected-facade imports plus expected broad-regex matches for replacement/core submodules such as `Workflow.EventLog.Core`, `Workflow.EventLog.File.Core`, `Workflow.EventLog.Commit.Core`, `Workflow.Execution.Core`, and `Workflow.Permission.Core`.

- Command: `rg -n "CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.(Types|EventLog|Execution|Permission))" README.md docs agent-workflow-core agent-workflow-codex agent-workflow-github examples *.cabal */*.cabal`
  Result: pass. The scan found the selected facades in `moifold.cabal` and public docs, and found replacement/core modules in standalone package Cabal files, READMEs, and framework docs.

- Command: `rg -n "exposed-modules|other-modules|CodexWatcher\\.AppServerClient|CodexWatcher\\.Core\\.Ids|CodexWatcher\\.Workflow\\.(Types|EventLog|Execution|Permission)" *.cabal */*.cabal`
  Result: pass. The scan showed all six selected facades exposed by the main `moifold` library and the replacement/core modules exposed by the standalone package candidates.

- Command: `rg -n "^import CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.(Types|EventLog|Execution|Permission))(\\s|$|\\()" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
  Result: pass. The anchored scan separated exact selected-facade imports from broad replacement/core module hits.

### Plan Compliance

- Re-read selection, project contract, and verification contract: met. The review used the selected `round-052-import-facade-inventory` scope and the `rev-001` verification contract.
- Inspect each selected facade module shape: met. `CodexWatcher.AppServerClient` and `CodexWatcher.Core.Ids` are pure reexport facades; `Workflow.Types`, `Workflow.EventLog`, `Workflow.Execution`, and `Workflow.Permission` still include concrete moifold lifecycle behavior or bridges.
- Inspect Cabal exposed-module and replacement-module status: met. `moifold.cabal` exposes the six selected facades; replacement modules are exposed from `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github` as reported.
- Run recursive import/reference scans across code, tests, examples, docs, and descriptors: met. The three required scan shapes and an anchored exact-import scan were run during review.
- Group current users by location: met. The inventory groups production, app/CLI, tests, docs/descriptors, and notes where broad scans include replacement/core submodule hits.
- Name preferred replacement paths: met. The report identifies Codex adapter modules, agent/GitHub id modules, event-log core/file/commit modules, execution core, permission core, and `Workflow.Spec` where applicable.
- Identify protecting tests by assertion purpose: met. The inventory names package-boundary, facade parity, planned-transition, execution, permission, event-log, and indexed workflow compatibility assertions rather than only naming `test/Main.hs`.
- Record unknowns explicitly: met. The inventory records migration-readiness, ownership-splitting, downstream-user, old-log/golden, and public API unknowns.
- Keep the report descriptive and avoid deprecation/removal classification: met. The report does not classify any facade as approved for deprecation or removal.
- Preserve evidence-only boundary: met. `git diff --name-status` and `git status --short` showed no tracked production, state, roadmap, policy, Cabal, import, runtime compatibility, or deprecation/removal changes. The only visible worktree additions are round-local artifacts under `orchestrator/rounds/round-052/`.

### Decision

**APPROVED**

### Evidence

The integrated round result is an evidence-only inventory at `orchestrator/rounds/round-052/import-facade-inventory.md`. The report is source-backed by recursive scans, exact-import separation, direct facade module inspection, Cabal exposed-module analysis, and existing test-assertion evidence.

The report correctly distinguishes pure import facades from product-facing moifold workflow bridges. It also preserves the project contract requirement that public compatibility facades remain available until a later removal-specific round proves safety. No production code, `orchestrator/state.json`, roadmap file, policy doc, Cabal descriptor, import, runtime compatibility file, or deprecation/removal status was changed.
