### Checks Run
- Command: `cabal build agent-workflow-core:lib:agent-workflow-core`
  Result: pass; Cabal reported the standalone core library target was up to date.
- Command: `(cd agent-workflow-core && cabal check)`
  Result: pass; `cabal check` reported no errors or warnings.
- Command: `rg -n "^(import|import qualified) (Data\\.Aeson|CodexWatcher\\.(ActionExecutor|AppServerClient|AppServerProtocol|ChildDaemon|Core\\.State|Daemon|DaemonLoop|Domain\\.|EffectInterpreter|Effects|EventLog|GhGit|Observation|Runtime|StateMachine|Supervisor|WatcherRuntimeStatus|Workflow\\.Agent|Workflow\\.GitHub|Workflow\\.Moifold|Workflow\\.Observation))" agent-workflow-core/src`
  Result: pass; no matches.
- Command: `rg -n "\\b(SomeWatcherState|WatcherState|WatcherEvent|DaemonObservation|ObservedPolicyTick|EffectPlan|SomeEffect|ActionExecutionMode|RuntimeInterpreter|AppServerTurn|AppServerRequest|GitHubCommandSpec|RepoName|PrConfig|DaemonOptions|DaemonTickResult|runDaemonTickWithEvents|runObservedDaemonTickWithEvents|CompatibilityWrite|PidFile|RuntimeOwner|RuntimeLease|FilePath|IO)\\b" agent-workflow-core/src`
  Result: pass; no matches.
- Command: `rg -n "aeson|directory|filepath|optparse-applicative|singletons|typed-process|unix|websockets|moifold|agent-workflow-codex|agent-workflow-github" agent-workflow-core/agent-workflow-core.cabal`
  Result: pass after manual review; matches were limited to approved `moifold` text in the package description and source repository URL, with no forbidden dependency in `build-depends`.
- Command: `cabal build all`
  Result: pass; Cabal reported the project was up to date.
- Command: `cabal test watcher-core-test`
  Result: pass; test suite `watcher-core-test` passed.
- Command: `git diff --check`
  Result: pass; no whitespace errors.
- Command: `git diff --cached --check`
  Result: pass; no staged whitespace errors.

### Plan Compliance
- Inspect current build surface: met. Reviewed `moifold.cabal`, `cabal.project`, `agent-workflow-core/src`, and `test/Main.hs`.
- Add standalone core descriptor: met. `agent-workflow-core/agent-workflow-core.cabal` defines package `agent-workflow-core` at `0.1.0.0`, uses `hs-source-dirs: src`, exposes the same generic core modules as the existing internal sublibrary, and depends only on `base`, `bytestring`, and `text`.
- Update project wiring only as needed: met. `cabal.project` now explicitly lists `.` and `agent-workflow-core`.
- Keep `moifold.cabal` minimal: met. `moifold.cabal` was not changed; the internal `library agent-workflow-core` remains in place.
- Update package-boundary assertions only as required: met. `test/Main.hs` extends `workflowCoreCabalSublibraryKeepsPackageBoundary` to validate both the internal sublibrary and standalone descriptor.
- Run package-specific validation: met. The standalone target build, `cabal check`, and all three required `rg` scans passed with the descriptor scan manually reviewed.
- Run repository validation: met. `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, and `git diff --cached --check` passed.
- Record implementation notes: met. `orchestrator/rounds/round-039/implementation-notes.md` records the implementation and validation commands.

### Decision
**APPROVED**

### Evidence
Tracked and untracked changes were inspected. Implementation changes are limited to `cabal.project`, `test/Main.hs`, and the new `agent-workflow-core/agent-workflow-core.cabal` descriptor, plus round artifacts. `orchestrator/state.json` changes are controller bookkeeping for activating `round-039` and do not alter implementation scope.

No source files under `agent-workflow-core/src` were moved, renamed, or modified. No adapter descriptors were added, no adapter modules were touched, and `moifold.cabal` was unchanged, so no moifold consumer rewiring happened.

The standalone descriptor metadata and dependencies align with the approved policy for this round: name `agent-workflow-core`, version `0.1.0.0`, MIT license metadata, source repository pointing at `soulomoon/moifold`, `GHC2021`, `hs-source-dirs: src`, exposed generic core modules, and only `base >=4.18 && <5`, `bytestring >=0.12 && <0.13`, and `text >=2.0 && <3` in `build-depends`.
