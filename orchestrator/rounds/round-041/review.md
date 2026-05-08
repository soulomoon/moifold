### Checks Run
- Command: `cabal build agent-workflow-github:lib:agent-workflow-github`
  Result: pass; Cabal reported the standalone GitHub library target was up to date.
- Command: `(cd agent-workflow-github && cabal check)`
  Result: pass; `cabal check` reported no errors or warnings.
- Command: `rg -n "^(import|import qualified) CodexWatcher\\.(AppServer|AppServerClient|AppServerProtocol|ChildDaemon|Cli|Core\\.|Daemon|DaemonLoop|Domain|EffectInterpreter|Effects|EventLog|EventLogRepair|GhGit|Healthcheck|Json|Logging|Observation|Runtime|StateMachine|Supervisor|Turn|TurnOutput|WatcherLiveness|WatcherRuntimeStatus|Workflow\\.(Agent|Daemon|EventLog|Execution|Moifold|Observation|Permission|Transaction|Types))" agent-workflow-github/src`
  Result: pass; no matches, exit 1 as expected for the no-match source-boundary scan.
- Command: `rg -n "\\b(WatcherEvent|SomeWatcherState|RuntimeCommand|RuntimeInterpreter|CommandReport|IssueConfig|PrConfig|ReviewEvidence|CleanReviewEvidence|Healthcheck|EventLogRepair|runtime-owner|daemon-state\\.json|issue-state\\.json|planning-state\\.json|watcher-state\\.json|block-state\\.json|app-server)\\b" agent-workflow-github/src`
  Result: pass; no matches, exit 1 as expected for the no-match source-boundary scan.
- Command: `rg -n "bytestring|containers|directory|filepath|optparse-applicative|singletons|typed-process|unix|websockets|moifold|agent-workflow-core|agent-workflow-codex" agent-workflow-github/agent-workflow-github.cabal`
  Result: pass after manual review; the only match was the approved source repository URL `https://github.com/soulomoon/moifold.git`, and `build-depends` contains none of the forbidden packages.
- Command: `rg -n "aeson >=2\\.2 && <3|base >=4\\.18 && <5|text >=2\\.0 && <3" agent-workflow-github/agent-workflow-github.cabal`
  Result: pass; found all three approved dependency bounds on lines 49-51.
- Command: `cabal build all`
  Result: pass; Cabal reported the project was up to date.
- Command: `cabal test watcher-core-test`
  Result: pass; `watcher-core-test` completed successfully, 1 of 1 test suites passed. Output included the GitHub package-boundary assertion and the broader workflow/package regression suite.
- Command: `git diff --check`
  Result: pass; no whitespace errors.
- Command: `git diff --cached --name-only`
  Result: pass; no staged files, so `git diff --cached --check` was not applicable.

### Plan Compliance
- Step 1, inspect current build surface and dependency source: met. Reviewed `moifold.cabal`, `cabal.project`, `agent-workflow-core/agent-workflow-core.cabal`, `agent-workflow-codex/agent-workflow-codex.cabal`, `agent-workflow-github/src`, and the GitHub package-boundary assertions in `test/Main.hs`.
- Step 2, add standalone descriptor: met. `agent-workflow-github/agent-workflow-github.cabal` defines package `agent-workflow-github` version `0.1.0.0`, records release metadata, imports the shared warning policy, uses `hs-source-dirs: src`, exposes the three current GitHub adapter modules, and depends only on `aeson`, `base`, and `text` with approved bounds.
- Step 3, update `cabal.project`: met. The project now explicitly lists `.`, `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`.
- Step 4, keep `moifold.cabal` minimal: met. `moifold.cabal` was not changed; the existing internal `moifold:agent-workflow-github` sublibrary remains available for current moifold consumers.
- Step 5, update package-boundary assertions only as needed: met. `test/Main.hs` now checks both the existing internal sublibrary and the standalone descriptor for exposed modules, approved dependencies, metadata/source layout, and source-boundary ownership.
- Step 6, package-specific validation: met. The standalone GitHub package build, `cabal check`, source-boundary scans, forbidden descriptor scan with manual allowance for the repository URL, and approved dependency-bound scan all passed.
- Step 7, repository validation: met. `cabal build all`, `cabal test watcher-core-test`, and `git diff --check` passed; no staged files made the cached whitespace check not applicable.
- Step 8, final diff scope: met for the implementation payload. Package/code changes are limited to `agent-workflow-github/agent-workflow-github.cabal`, `cabal.project`, and focused `test/Main.hs` assertions. `orchestrator/state.json` is present as active controller state in this review worktree and was not edited during review.
- Step 9, implementation notes: met. `orchestrator/rounds/round-041/implementation-notes.md` records the package-specific and repository validation evidence, including cached diff applicability.

### Decision
**APPROVED**

### Evidence
The new standalone descriptor matches the approved package identity and metadata shape, uses `hs-source-dirs: src`, exposes `CodexWatcher.Workflow.GitHub.Command`, `CodexWatcher.Workflow.GitHub.Ids`, and `CodexWatcher.Workflow.GitHub.Remote`, and keeps `build-depends` limited to `aeson >=2.2 && <3`, `base >=4.18 && <5`, and `text >=2.0 && <3`.

The boundary scans found no moifold lifecycle, daemon, event-log, runtime, compatibility-file, concrete watcher-state, healthcheck, command-execution, AppServer/Codex adapter, workflow-core policy, or publication-policy ownership leaks under `agent-workflow-github/src` or the standalone descriptor. The forbidden descriptor scan matched only the allowed source repository URL containing `moifold`.

The round stays inside selected `item-041-github-package-layout` scope: it creates the standalone GitHub package layout, wires it into `cabal.project`, and strengthens focused boundary assertions. It does not rewire moifold consumers, remove compatibility facades, change event schemas or golden fixtures, alter command execution, healthcheck, PR/issue lifecycle, merge/review publication policy, runtime behavior, CI, source distribution, docs/examples, changelog/release notes, package upload, or module layout.
