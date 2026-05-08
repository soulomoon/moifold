### Changes Made
- `agent-workflow-core/agent-workflow-core.cabal`: added a standalone `agent-workflow-core` package descriptor at version `0.1.0.0` with policy-backed metadata, `hs-source-dirs: src`, the current generic core exposed modules, and only `base`, `bytestring`, and `text` dependencies. The normal warning set is shared; `-Werror` is available behind a manual `development-werror` flag so `cabal check` remains clean.
- `cabal.project`: listed `agent-workflow-core` explicitly alongside the root `moifold` package so Cabal can address the standalone core package candidate without broad package globs.
- `test/Main.hs`: extended `workflowCoreCabalSublibraryKeepsPackageBoundary` to validate both the retained `moifold:agent-workflow-core` internal sublibrary and the standalone descriptor for exposed modules, approved dependency set, forbidden package edges, and descriptor metadata/source layout.
- `moifold.cabal`: unchanged; the existing internal `library agent-workflow-core` remains in place and moifold consumer rewiring is deferred to its later selected direction.

### Tests
- `test/Main.hs`: `workflowCoreCabalSublibraryKeepsPackageBoundary` now verifies the standalone descriptor in addition to the existing internal sublibrary boundary.
- `cabal build agent-workflow-core:lib:agent-workflow-core`: passed.
- `(cd agent-workflow-core && cabal check)`: passed with no errors or warnings.
- `rg -n "^(import|import qualified) (Data\\.Aeson|CodexWatcher\\.(ActionExecutor|AppServerClient|AppServerProtocol|ChildDaemon|Core\\.State|Daemon|DaemonLoop|Domain\\.|EffectInterpreter|Effects|EventLog|GhGit|Observation|Runtime|StateMachine|Supervisor|WatcherRuntimeStatus|Workflow\\.Agent|Workflow\\.GitHub|Workflow\\.Moifold|Workflow\\.Observation))" agent-workflow-core/src`: returned no matches, as expected.
- `rg -n "\\b(SomeWatcherState|WatcherState|WatcherEvent|DaemonObservation|ObservedPolicyTick|EffectPlan|SomeEffect|ActionExecutionMode|RuntimeInterpreter|AppServerTurn|AppServerRequest|GitHubCommandSpec|RepoName|PrConfig|DaemonOptions|DaemonTickResult|runDaemonTickWithEvents|runObservedDaemonTickWithEvents|CompatibilityWrite|PidFile|RuntimeOwner|RuntimeLease|FilePath|IO)\\b" agent-workflow-core/src`: returned no matches, as expected.
- `rg -n "aeson|directory|filepath|optparse-applicative|singletons|typed-process|unix|websockets|moifold|agent-workflow-codex|agent-workflow-github" agent-workflow-core/agent-workflow-core.cabal`: returned only approved `moifold` mentions in the package description and source repository URL; no forbidden dependencies were present.
- `cabal build all`: passed.
- `cabal test watcher-core-test`: passed.
- `git diff --check`: passed.
- `git diff --cached --check`: passed; no files were staged.

### Notes
No modules under `agent-workflow-core/src` were moved or renamed. No adapter descriptors, moifold consumer wiring, compatibility facades, event schemas/golden fixtures, roadmap files, release notes, source distributions, CI, review artifacts, merge artifacts, or package publication surfaces were changed.
