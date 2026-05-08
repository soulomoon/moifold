### Goal

Create the standalone `agent-workflow-codex` package descriptor and local build surface, or prove the current internal sublibrary already satisfies the selected item through an equivalent package-specific build surface. Preserve the existing `agent-workflow-codex/src` module layout, make the Codex adapter candidate depend on the standalone `agent-workflow-core` package, and prove the app-server protocol, client, interpreter, transport, typed agent, and observation modules build outside the main moifold library.

### Approach

Prefer the same bounded package-layout shape used by round 039 for `agent-workflow-core`: add the minimum standalone descriptor and Cabal project wiring needed for Cabal to address `agent-workflow-codex` as a local package candidate while leaving source files under `agent-workflow-codex/src`.

Use `orchestrator/project-contract.md`, the active roadmap verification contract, the package identity/versioning contract, release metadata policy, compatibility/deprecation policy, package extraction readiness report, the current `moifold.cabal` internal `library agent-workflow-codex` section, `cabal.project`, `agent-workflow-core/agent-workflow-core.cabal`, and package-boundary assertions in `test/Main.hs` as source of truth. The standalone Codex descriptor should use package name `agent-workflow-codex`, independent pre-1.0 version `0.1.0.0` unless inspection proves a stricter policy value, explicit release metadata, `hs-source-dirs: src`, the current Codex exposed module list, `GHC2021`, and only the approved adapter dependencies: `aeson`, `base`, `bytestring`, `text`, `websockets`, and the standalone `agent-workflow-core` package.

Do not move or rename modules. Do not create the standalone `agent-workflow-github` descriptor. Do not rewire the main moifold library to consume standalone package candidates; `direction-007-moifold-local-consumer-wiring` owns that later. Do not remove or deprecate `CodexWatcher.AppServerClient`, edit compatibility files, change event schemas or golden fixtures, alter prompt/runtime/lifecycle behavior, generate source distributions, add CI, prepare changelogs or release notes, upload packages, edit roadmap files, edit `orchestrator/state.json`, or write implementation, review, or merge artifacts during this planner stage.

If adding the standalone descriptor exposes Cabal ambiguity with the existing `moifold:agent-workflow-codex` internal sublibrary, resolve only the minimum descriptor/project/test-surface issue needed for this item. The expected result may keep the internal sublibrary temporarily so moifold and existing tests continue to build until the later consumer-wiring round.

### Steps

1. Inspect the current build surface and dependency source:
   - `moifold.cabal` for `library agent-workflow-codex` exposed modules and dependencies.
   - `cabal.project` for local package discovery.
   - `agent-workflow-core/agent-workflow-core.cabal` for the standalone core package name, version, metadata style, warning flag, and dependency bounds.
   - `agent-workflow-codex/src` for the source tree that must remain in place.
   - `test/Main.hs` for `workflowCodexCabalSublibraryKeepsPackageBoundary`, `codexBoundaryForbiddenImportModules`, and related package-boundary helpers.
2. Add or validate a standalone descriptor at `agent-workflow-codex/agent-workflow-codex.cabal`.
   - Package name: `agent-workflow-codex`.
   - Version: `0.1.0.0` unless current policy evidence forces a stricter source-backed value.
   - Metadata: explicit `synopsis`, `description`, `license`, `author`, `maintainer`, `category`, `build-type`, and `source-repository head` fields consistent with the approved metadata policy. The description should name the implemented Codex adapter surface and should not claim app-server startup policy, role prompt policy, structured-output policy, compatibility-facade removal, moifold lifecycle routing, package upload, or source-distribution readiness.
   - Source: `hs-source-dirs: src`.
   - Exposed modules: exactly the current Codex adapter modules exposed by the internal `moifold.cabal` sublibrary unless inspection proves a module is missing from source or intentionally private.
   - Dependencies: `aeson >=2.2 && <3`, `base >=4.18 && <5`, `bytestring >=0.12 && <0.13`, `text >=2.0 && <3`, `websockets >=0.13 && <0.14`, and `agent-workflow-core >=0.1 && <0.2`.
   - Warning policy: mirror the standalone core descriptor's warning common stanza and `development-werror` flag if it remains clean and package-local.
3. Update `cabal.project` only as needed to include the standalone Codex local package candidate while keeping `.` and `agent-workflow-core` in the project. Prefer explicit package entries over broad globs so the package set remains reviewable.
4. Keep `moifold.cabal` changes minimal. The default path is to leave the current internal `library agent-workflow-codex` in place with its `moifold:agent-workflow-core` dependency so moifold and `watcher-core-test` continue to use the current sublibrary until the consumer-wiring round. Only change `moifold.cabal` if Cabal target resolution or descriptor validation requires a focused package-layout adjustment, and do not rewire the main library to depend on the standalone Codex package in this round.
5. Update package-boundary assertions in `test/Main.hs` only if the new standalone layout requires them to inspect both the standalone descriptor and the existing internal sublibrary section. The assertions should continue to prove:
   - `agent-workflow-codex/src` has no moifold lifecycle, daemon, event-log, runtime, GitHub, `Workflow.Moifold`, `Workflow.Types`, compatibility facade, or compatibility-file ownership imports/tokens.
   - Codex exposes `CodexWatcher.AppServerProtocol`, `CodexWatcher.Workflow.Agent`, `CodexWatcher.Workflow.Agent.Codex`, `CodexWatcher.Workflow.Agent.Codex.Client`, `CodexWatcher.Workflow.Agent.Codex.Interpreter`, `CodexWatcher.Workflow.Agent.Codex.Protocol`, `CodexWatcher.Workflow.Agent.Codex.Transport`, `CodexWatcher.Workflow.Agent.Ids`, `CodexWatcher.Workflow.Agent.Types`, and `CodexWatcher.Workflow.Observation.Agent`.
   - The standalone descriptor uses only the approved external dependency set and depends on standalone `agent-workflow-core`, not `moifold:agent-workflow-core`.
   - Any remaining internal sublibrary keeps the approved internal dependency set and does not pull in broad moifold dependencies.
   - The main moifold library still depends on the current Codex adapter surface and still keeps compatibility facades available.
6. Run package-specific validation before broad validation:
   - `cabal build agent-workflow-codex:lib:agent-workflow-codex`
   - `(cd agent-workflow-codex && cabal check)`
   - `rg -n "^(import|import qualified) CodexWatcher\\.(AppServerClient|ActionExecutor|ChildDaemon|Daemon|DaemonLoop|Domain\\.|Effects|EventLog|EventLogRepair|GhGit|Healthcheck|Runtime\\.|StateMachine|Workflow\\.GitHub|Workflow\\.Moifold\\.|Workflow\\.Types)" agent-workflow-codex/src`
   - `rg -n "\\b(WatcherEvent|SomeWatcherState|issue-state\\.json|daemon-state\\.json|planning-state\\.json|pr-url|block-state|repair-state|runtime-owner)\\b" agent-workflow-codex/src`
   - `rg -n "containers|directory|filepath|optparse-applicative|singletons|typed-process|unix|moifold:" agent-workflow-codex/agent-workflow-codex.cabal`
   - `rg -n "agent-workflow-core >=0\\.1 && <0\\.2|aeson >=2\\.2 && <3|base >=4\\.18 && <5|bytestring >=0\\.12 && <0\\.13|text >=2\\.0 && <3|websockets >=0\\.13 && <0\\.14" agent-workflow-codex/agent-workflow-codex.cabal`
   The first two source-boundary scans should return no matches. The forbidden descriptor scan should return no matches. The dependency-presence scan should show every approved dependency bound.
7. Run required repository validation:
   - `cabal build all`
   - `cabal test watcher-core-test`
   - `git diff --check`
   - `git diff --cached --check` if any files are staged.
8. During implementation, inspect the final diff before verification. It should be limited to `agent-workflow-codex/agent-workflow-codex.cabal`, `cabal.project`, and focused package-boundary assertion updates in `test/Main.hs` unless a Cabal target ambiguity requires a narrowly justified `moifold.cabal` adjustment. Do not edit `orchestrator/state.json`, roadmap files, review artifacts, merge artifacts, event schemas, golden fixtures, compatibility facades, runtime code, prompt policy, source distributions, release notes, or changelogs.
9. Record implementation notes after implementation with the exact package-specific and repository validation commands, including whether `git diff --cached --check` was run or not applicable. Do not write review or merge artifacts.

### Verification

The implementation is correct when `agent-workflow-codex` is independently buildable and checkable as a local package candidate, its descriptor metadata matches the approved package identity and release metadata policies, it depends on standalone `agent-workflow-core`, `agent-workflow-codex/src` remains the source layout, and recursive boundary evidence still proves the Codex adapter owns app-server protocol/client/interpreter/transport without moifold lifecycle, prompt policy, compatibility-file, GitHub, runtime, daemon, event-log, or concrete watcher state ownership.

Required commands:

```sh
cabal build agent-workflow-codex:lib:agent-workflow-codex
(cd agent-workflow-codex && cabal check)
rg -n "^(import|import qualified) CodexWatcher\\.(AppServerClient|ActionExecutor|ChildDaemon|Daemon|DaemonLoop|Domain\\.|Effects|EventLog|EventLogRepair|GhGit|Healthcheck|Runtime\\.|StateMachine|Workflow\\.GitHub|Workflow\\.Moifold\\.|Workflow\\.Types)" agent-workflow-codex/src
rg -n "\\b(WatcherEvent|SomeWatcherState|issue-state\\.json|daemon-state\\.json|planning-state\\.json|pr-url|block-state|repair-state|runtime-owner)\\b" agent-workflow-codex/src
rg -n "containers|directory|filepath|optparse-applicative|singletons|typed-process|unix|moifold:" agent-workflow-codex/agent-workflow-codex.cabal
rg -n "agent-workflow-core >=0\\.1 && <0\\.2|aeson >=2\\.2 && <3|base >=4\\.18 && <5|bytestring >=0\\.12 && <0\\.13|text >=2\\.0 && <3|websockets >=0\\.13 && <0\\.14" agent-workflow-codex/agent-workflow-codex.cabal
cabal build all
cabal test watcher-core-test
git diff --check
git diff --cached --check
```

`git diff --cached --check` is required only when staging happens; if nothing is staged, record that it was not applicable or run it and record the empty result. If staging happens, stage only the intended files and stage any whitespace cleanup explicitly before running the cached whitespace check.

### Worker Fan-Out

No worker fan-out. This item should stay serial because the standalone Codex descriptor, `cabal.project` package discovery, dependency on standalone core, existing internal sublibrary compatibility, and package-boundary assertions all describe one adapter package surface and need one owner to keep the layout coherent. Do not create `worker-plan.json`.
