### Goal

Create the first standalone `agent-workflow-core` package descriptor and local build surface, or prove the current internal sublibrary already satisfies the selected item through an equivalent package-specific build surface. Preserve the existing `agent-workflow-core/src` module layout, keep the core dependency boundary limited to generic workflow-kernel dependencies, and avoid adapter descriptors, moifold consumer rewiring, compatibility facade changes, release artifacts, or behavior changes.

### Approach

Prefer the smallest descriptor-level extraction that makes `agent-workflow-core` independently addressable by Cabal while keeping source files in `agent-workflow-core/src`. The implementation should use the approved package identity, versioning, release metadata, compatibility/deprecation policy, package extraction readiness report, and `orchestrator/project-contract.md` as the source of truth.

Start by confirming the current internal sublibrary shape in `moifold.cabal`, `cabal.project`, `agent-workflow-core/src`, and `test/Main.hs`. If no standalone descriptor exists, add `agent-workflow-core/agent-workflow-core.cabal` with package name `agent-workflow-core`, independent pre-1.0 version `0.1.0.0`, explicit metadata matching the release metadata policy, `hs-source-dirs: src`, the current exposed module list, `GHC2021`, the same warning policy if it can be shared cleanly, and only `base`, `bytestring`, and `text` dependencies. Wire `cabal.project` so Cabal sees both the existing moifold package and the new local core package candidate.

Do not move or rename any module under `agent-workflow-core/src`. Do not create descriptors for `agent-workflow-codex` or `agent-workflow-github`. Do not change moifold imports, event schemas, golden fixtures, compatibility facades, compatibility files, runtime behavior, source distributions, changelogs, release notes, CI, roadmap files, review artifacts, merge artifacts, or `orchestrator/state.json`.

If adding the standalone descriptor creates a Cabal conflict with the existing `moifold:agent-workflow-core` sublibrary, resolve only the minimum package-layout conflict needed for this selected item. Acceptable fixes are limited to project/package target disambiguation, package descriptor fields, or focused package-boundary test updates. Do not rewire moifold to consume the standalone package; `direction-007-moifold-local-consumer-wiring` owns that later.

### Steps

1. Inspect the current build surface:
   - `moifold.cabal` for the existing `library agent-workflow-core` exposed modules and dependencies.
   - `cabal.project` for local package discovery.
   - `agent-workflow-core/src` for the source tree that must remain in place.
   - `test/Main.hs` for `workflowCoreCabalSublibraryKeepsPackageBoundary` and related package-boundary helpers.
2. Add or validate a standalone core descriptor at `agent-workflow-core/agent-workflow-core.cabal`.
   - Package name: `agent-workflow-core`.
   - Version: `0.1.0.0` unless current policy evidence forces a stricter source-backed value.
   - Metadata: explicit `synopsis`, `description`, `license`, `author`, `maintainer`, `category`, `build-type`, and `source-repository head` fields consistent with the approved release metadata policy.
   - Source: `hs-source-dirs: src`.
   - Exposed modules: exactly the current generic core modules exposed by the internal `moifold.cabal` sublibrary unless inspection proves a module is missing from source or intentionally private.
   - Dependencies: only `base >=4.18 && <5`, `bytestring >=0.12 && <0.13`, and `text >=2.0 && <3`.
3. Update `cabal.project` only as needed to include the standalone local package candidate while keeping the main `moifold` package in the project. Prefer explicit package entries over broad globs if that keeps the package set reviewable.
4. Keep `moifold.cabal` changes minimal. The default path is to leave the current internal `library agent-workflow-core` in place so moifold and existing tests continue to build. Only change it if Cabal requires target disambiguation or descriptor validation cannot otherwise work, and do not rewire main-library consumption to the standalone package.
5. Update package-boundary assertions in `test/Main.hs` only if the new layout requires the tests to inspect both the standalone descriptor and the existing internal sublibrary section. The assertion should continue to prove:
   - core source under `agent-workflow-core/src` has no forbidden Aeson, Codex, GitHub, moifold lifecycle, runtime, daemon, filesystem, IO, concrete event/state, compatibility-write, or command-execution imports/tokens;
   - the core package surface exposes the generic core modules;
   - the standalone descriptor and any remaining internal sublibrary keep the approved `base`/`bytestring`/`text` dependency set;
   - no adapter or main moifold package dependency leaks into core.
6. Run package-specific validation before broad validation:
   - `cabal build agent-workflow-core:lib:agent-workflow-core`
   - `(cd agent-workflow-core && cabal check)`
   - `rg -n "^(import|import qualified) (Data\\.Aeson|CodexWatcher\\.(ActionExecutor|AppServerClient|AppServerProtocol|ChildDaemon|Core\\.State|Daemon|DaemonLoop|Domain\\.|EffectInterpreter|Effects|EventLog|GhGit|Observation|Runtime|StateMachine|Supervisor|WatcherRuntimeStatus|Workflow\\.Agent|Workflow\\.GitHub|Workflow\\.Moifold|Workflow\\.Observation))" agent-workflow-core/src`
   - `rg -n "\\b(SomeWatcherState|WatcherState|WatcherEvent|DaemonObservation|ObservedPolicyTick|EffectPlan|SomeEffect|ActionExecutionMode|RuntimeInterpreter|AppServerTurn|AppServerRequest|GitHubCommandSpec|RepoName|PrConfig|DaemonOptions|DaemonTickResult|runDaemonTickWithEvents|runObservedDaemonTickWithEvents|CompatibilityWrite|PidFile|RuntimeOwner|RuntimeLease|FilePath|IO)\\b" agent-workflow-core/src`
   - `rg -n "aeson|directory|filepath|optparse-applicative|singletons|typed-process|unix|websockets|moifold|agent-workflow-codex|agent-workflow-github" agent-workflow-core/agent-workflow-core.cabal`
     The first two `rg` commands should return no matches. The descriptor scan should be reviewed manually: only package identity text may mention `moifold` through the approved source repository URL; forbidden dependencies must not appear in `build-depends`.
7. Run required repository validation:
   - `cabal build all`
   - `cabal test watcher-core-test`
   - `git diff --check`
   - `git diff --cached --check` if any files are staged.
8. Record implementation notes with the exact package-specific and repository validation commands and whether the standalone descriptor was added or the current build surface was validated as equivalent. Do not write review or merge artifacts.

### Verification

The implementation is correct when `agent-workflow-core` is independently buildable and checkable as a local package candidate, its descriptor metadata matches the approved package identity and release metadata policy, `agent-workflow-core/src` remains the source layout, and recursive boundary evidence still proves the core package has only generic workflow-kernel dependencies and no Aeson, Codex, GitHub, moifold lifecycle, filesystem, runtime, daemon, IO, concrete event/state, compatibility-file, or command-execution ownership.

Required commands:

```sh
cabal build agent-workflow-core:lib:agent-workflow-core
(cd agent-workflow-core && cabal check)
rg -n "^(import|import qualified) (Data\\.Aeson|CodexWatcher\\.(ActionExecutor|AppServerClient|AppServerProtocol|ChildDaemon|Core\\.State|Daemon|DaemonLoop|Domain\\.|EffectInterpreter|Effects|EventLog|GhGit|Observation|Runtime|StateMachine|Supervisor|WatcherRuntimeStatus|Workflow\\.Agent|Workflow\\.GitHub|Workflow\\.Moifold|Workflow\\.Observation))" agent-workflow-core/src
rg -n "\\b(SomeWatcherState|WatcherState|WatcherEvent|DaemonObservation|ObservedPolicyTick|EffectPlan|SomeEffect|ActionExecutionMode|RuntimeInterpreter|AppServerTurn|AppServerRequest|GitHubCommandSpec|RepoName|PrConfig|DaemonOptions|DaemonTickResult|runDaemonTickWithEvents|runObservedDaemonTickWithEvents|CompatibilityWrite|PidFile|RuntimeOwner|RuntimeLease|FilePath|IO)\\b" agent-workflow-core/src
rg -n "aeson|directory|filepath|optparse-applicative|singletons|typed-process|unix|websockets|moifold|agent-workflow-codex|agent-workflow-github" agent-workflow-core/agent-workflow-core.cabal
cabal build all
cabal test watcher-core-test
git diff --check
git diff --cached --check
```

The two source-boundary `rg` commands should return no matches. `git diff --cached --check` is required only when staging happens; if nothing is staged, record that it was not applicable or run it and record the empty result.

### Worker Fan-Out

No worker fan-out. This item should stay serial because the standalone descriptor, `cabal.project` package discovery, remaining internal sublibrary compatibility, and boundary assertions all describe the same core package surface and need one owner to keep the layout coherent. Do not create `worker-plan.json`.
