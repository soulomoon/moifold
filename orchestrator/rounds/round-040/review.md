### Checks Run
- Command: `cabal build agent-workflow-codex:lib:agent-workflow-codex`
  Result: pass; Cabal reported the target was up to date.
- Command: `(cd agent-workflow-codex && cabal check)`
  Result: pass; no errors or warnings.
- Command: `rg -n "^(import|import qualified) CodexWatcher\\.(AppServerClient|ActionExecutor|ChildDaemon|Daemon|DaemonLoop|Domain\\.|Effects|EventLog|EventLogRepair|GhGit|Healthcheck|Runtime\\.|StateMachine|Workflow\\.GitHub|Workflow\\.Moifold\\.|Workflow\\.Types)" agent-workflow-codex/src`
  Result: pass; no matches, exit 1 as expected for the no-match source-boundary scan.
- Command: `rg -n "\\b(WatcherEvent|SomeWatcherState|issue-state\\.json|daemon-state\\.json|planning-state\\.json|pr-url|block-state|repair-state|runtime-owner)\\b" agent-workflow-codex/src`
  Result: pass; no matches, exit 1 as expected for the no-match source-boundary scan.
- Command: `rg -n "containers|directory|filepath|optparse-applicative|singletons|typed-process|unix|moifold:" agent-workflow-codex/agent-workflow-codex.cabal`
  Result: pass; no matches, exit 1 as expected for the forbidden descriptor scan.
- Command: `rg -n "agent-workflow-core >=0\\.1 && <0\\.2|aeson >=2\\.2 && <3|base >=4\\.18 && <5|bytestring >=0\\.12 && <0\\.13|text >=2\\.0 && <3|websockets >=0\\.13 && <0\\.14" agent-workflow-codex/agent-workflow-codex.cabal`
  Result: pass; found all six approved dependency bounds on lines 56-61.
- Command: `cabal build all`
  Result: pass; Cabal reported the project was up to date.
- Command: `cabal test watcher-core-test`
  Result: pass; `watcher-core-test` completed successfully, 1 of 1 test suites passed.
- Command: `git diff --check`
  Result: pass; no whitespace errors.
- Command: `git diff --cached --name-only`
  Result: pass; no staged files, so `git diff --cached --check` was not applicable.

### Plan Compliance
- Step 1, inspect current build surface and dependency source: met. Reviewed `moifold.cabal`, `cabal.project`, `agent-workflow-core/agent-workflow-core.cabal`, `agent-workflow-codex/src`, and the Codex package-boundary assertions in `test/Main.hs`.
- Step 2, add standalone descriptor: met. `agent-workflow-codex/agent-workflow-codex.cabal` defines package `agent-workflow-codex` version `0.1.0.0`, release metadata, warning policy, `hs-source-dirs: src`, the current Codex adapter exposed modules, and approved bounded dependencies.
- Step 3, update `cabal.project`: met. The project now explicitly lists `.`, `agent-workflow-core`, and `agent-workflow-codex`.
- Step 4, keep `moifold.cabal` minimal: met. No `moifold.cabal` implementation change was made; the existing internal `moifold:agent-workflow-codex` sublibrary remains available for current moifold consumers.
- Step 5, update package-boundary assertions only as needed: met. `test/Main.hs` now checks both the existing internal sublibrary and the standalone descriptor for exposed modules, approved dependencies, standalone core dependency, metadata/source layout, and source-boundary ownership.
- Step 6, package-specific validation: met. The standalone Codex package build, `cabal check`, source-boundary scans, forbidden descriptor scan, and approved dependency-bound scan all passed.
- Step 7, repository validation: met. `cabal build all`, `cabal test watcher-core-test`, and `git diff --check` passed; no staged files made the cached whitespace check not applicable.
- Step 8, final diff scope: met for the implementation payload. The package/code changes are limited to `agent-workflow-codex/agent-workflow-codex.cabal`, `cabal.project`, and focused `test/Main.hs` assertions. `orchestrator/state.json` is present as active controller state in this review worktree and was not edited during review.
- Step 9, implementation notes: met. `orchestrator/rounds/round-040/implementation-notes.md` records the package-specific and repository validation evidence, including cached diff applicability.

### Decision
**APPROVED**

### Evidence
The new standalone descriptor matches the approved package identity and metadata shape, uses `hs-source-dirs: src`, exposes the Codex app-server protocol/client/interpreter/transport, typed agent, ids, types, and observation modules, and depends on standalone `agent-workflow-core >=0.1 && <0.2` rather than `moifold:agent-workflow-core`.

The boundary scans found no moifold lifecycle, daemon, event-log, runtime, GitHub, compatibility-file, concrete watcher-state, or forbidden package ownership leaks under `agent-workflow-codex/src` or the standalone descriptor. The dependency-bound scan found the approved bounds for `aeson`, `agent-workflow-core`, `base`, `bytestring`, `text`, and `websockets`.

The round stays inside the selected `item-040-codex-package-layout` scope: it creates the standalone Codex package layout, wires it into `cabal.project`, and strengthens focused boundary assertions. It does not rewire moifold consumers, add a GitHub package descriptor, remove compatibility facades, change event schemas/golden fixtures, alter prompt/runtime/lifecycle behavior, add CI/source distribution/release artifacts, or move modules.
