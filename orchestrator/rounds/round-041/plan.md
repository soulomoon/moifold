### Goal

Create the standalone `agent-workflow-github` package descriptor and local build surface, or prove the current internal sublibrary already satisfies the selected item through an equivalent package-specific build surface. Preserve the existing `agent-workflow-github/src` module layout, keep GitHub identifiers, remote metadata parsing, and pure command rendering helpers independently buildable, and avoid moifold consumer rewiring or behavior changes.

### Approach

Follow the descriptor-first shape used by rounds 039 and 040: add the minimum standalone package metadata and Cabal project wiring needed for Cabal to address `agent-workflow-github` as a local package candidate while leaving all source files under `agent-workflow-github/src`.

Use `orchestrator/project-contract.md`, the active roadmap verification contract, the package identity/versioning contract, release metadata policy, compatibility/deprecation policy, the current `moifold.cabal` internal `library agent-workflow-github` section, `cabal.project`, existing standalone package descriptors, the full `agent-workflow-github/src` tree, and package-boundary assertions in `test/Main.hs` as source of truth. The standalone GitHub descriptor should use package name `agent-workflow-github`, independent pre-1.0 version `0.1.0.0` unless inspection proves a stricter policy value, explicit release metadata, `hs-source-dirs: src`, the current GitHub exposed module list, `GHC2021`, and only the approved GitHub adapter dependencies: `aeson`, `base`, and `text`. Do not add an `agent-workflow-core` dependency unless source inspection proves a real import need; the current GitHub source is standalone within the project and should only be validated in the same local package set as standalone core.

Do not move or rename modules. Do not rewire the main moifold library to consume standalone package candidates; `direction-007-moifold-local-consumer-wiring` owns that later. Do not remove or deprecate compatibility facades, edit compatibility files, change event schemas or golden fixtures, alter command execution, healthcheck, PR/issue lifecycle policy, merge/review publication policy, prompt/runtime/lifecycle behavior, generate source distributions, add CI, prepare changelogs or release notes, upload packages, edit roadmap files, edit `orchestrator/state.json`, or write implementation, review, or merge artifacts during this planner stage.

If adding the standalone descriptor exposes Cabal ambiguity with the existing `moifold:agent-workflow-github` internal sublibrary, resolve only the minimum descriptor/project/test-surface issue needed for this item. The expected result may keep the internal sublibrary temporarily so moifold and existing tests continue to build until the later consumer-wiring round.

### Steps

1. Inspect the current build surface and dependency source:
   - `moifold.cabal` for `library agent-workflow-github` exposed modules and dependencies.
   - `cabal.project` for local package discovery.
   - `agent-workflow-core/agent-workflow-core.cabal` and `agent-workflow-codex/agent-workflow-codex.cabal` for descriptor metadata style, warning flag, and dependency-bound conventions.
   - `agent-workflow-github/src` for the source tree that must remain in place.
   - `test/Main.hs` for `workflowGithubCabalSublibraryKeepsPackageBoundary`, `githubForbiddenImportModules`, `githubForbiddenOwnershipTokens`, and related package-boundary helpers.
2. Add or validate a standalone descriptor at `agent-workflow-github/agent-workflow-github.cabal`.
   - Package name: `agent-workflow-github`.
   - Version: `0.1.0.0` unless current policy evidence forces a stricter source-backed value.
   - Metadata: explicit `synopsis`, `description`, `license`, `author`, `maintainer`, `category`, `build-type`, and `source-repository head` fields consistent with the approved metadata policy. The description should name the implemented GitHub identifier, remote metadata parsing, and pure command rendering surface and should not claim command execution, healthcheck, PR/issue lifecycle policy, merge/review publication policy, moifold compatibility-facade removal, package upload, or source-distribution readiness.
   - Source: `hs-source-dirs: src`.
   - Exposed modules: exactly `CodexWatcher.Workflow.GitHub.Command`, `CodexWatcher.Workflow.GitHub.Ids`, and `CodexWatcher.Workflow.GitHub.Remote` unless inspection proves a module is missing from source or intentionally private.
   - Dependencies: `aeson >=2.2 && <3`, `base >=4.18 && <5`, and `text >=2.0 && <3`. Do not include `moifold`, `moifold:*`, `agent-workflow-codex`, or broad runtime/filesystem/process packages. Do not include `agent-workflow-core` unless source imports require it.
   - Warning policy: mirror the existing standalone descriptors' warning common stanza and `development-werror` flag if it remains package-local and clean.
3. Update `cabal.project` only as needed to include the standalone GitHub local package candidate while keeping `.`, `agent-workflow-core`, and `agent-workflow-codex` in the project. Prefer explicit package entries over broad globs so the package set remains reviewable.
4. Keep `moifold.cabal` changes minimal. The default path is to leave the current internal `library agent-workflow-github` in place with its existing dependency set so moifold and `watcher-core-test` continue to use the current sublibrary until the consumer-wiring round. Only change `moifold.cabal` if Cabal target resolution or descriptor validation requires a focused package-layout adjustment, and do not rewire the main library to depend on the standalone GitHub package in this round.
5. Update package-boundary assertions in `test/Main.hs` only if the new standalone layout requires them to inspect both the standalone descriptor and the existing internal sublibrary section. The assertions should continue to prove:
   - `agent-workflow-github/src` has no moifold state-machine, daemon, lifecycle, runtime, compatibility, event-log, AppServer/Codex adapter, workflow-core policy, command execution, healthcheck, or publication-policy imports/tokens.
   - The GitHub package surface exposes `CodexWatcher.Workflow.GitHub.Command`, `CodexWatcher.Workflow.GitHub.Ids`, and `CodexWatcher.Workflow.GitHub.Remote`.
   - The standalone descriptor records approved metadata and `hs-source-dirs: src`.
   - The standalone descriptor uses only the approved external dependency set and does not depend on `moifold`, `moifold:*`, `agent-workflow-core`, `agent-workflow-codex`, filesystem/process/runtime packages, or command-execution libraries unless source-backed evidence requires a narrower exception.
   - Any remaining internal sublibrary keeps the approved internal dependency set and does not pull in broad moifold dependencies.
   - The main moifold library still depends on the current GitHub adapter surface without reexporting adapter modules.
6. Run package-specific validation before broad validation:
   - `cabal build agent-workflow-github:lib:agent-workflow-github`
   - `(cd agent-workflow-github && cabal check)`
   - `rg -n "^(import|import qualified) CodexWatcher\\.(AppServer|AppServerClient|AppServerProtocol|ChildDaemon|Cli|Core\\.|Daemon|DaemonLoop|Domain|EffectInterpreter|Effects|EventLog|EventLogRepair|GhGit|Healthcheck|Json|Logging|Observation|Runtime|StateMachine|Supervisor|Turn|TurnOutput|WatcherLiveness|WatcherRuntimeStatus|Workflow\\.(Agent|Daemon|EventLog|Execution|Moifold|Observation|Permission|Transaction|Types))" agent-workflow-github/src`
   - `rg -n "\\b(WatcherEvent|SomeWatcherState|RuntimeCommand|RuntimeInterpreter|CommandReport|IssueConfig|PrConfig|ReviewEvidence|CleanReviewEvidence|Healthcheck|EventLogRepair|runtime-owner|daemon-state\\.json|issue-state\\.json|planning-state\\.json|watcher-state\\.json|block-state\\.json|app-server)\\b" agent-workflow-github/src`
   - `rg -n "bytestring|containers|directory|filepath|optparse-applicative|singletons|typed-process|unix|websockets|moifold|agent-workflow-core|agent-workflow-codex" agent-workflow-github/agent-workflow-github.cabal`
   - `rg -n "aeson >=2\\.2 && <3|base >=4\\.18 && <5|text >=2\\.0 && <3" agent-workflow-github/agent-workflow-github.cabal`
   The two source-boundary scans should return no matches. The forbidden descriptor scan should be reviewed manually: only approved source repository metadata may mention `moifold`; forbidden dependencies must not appear in `build-depends`. The dependency-presence scan should show every approved dependency bound.
7. Run required repository validation:
   - `cabal build all`
   - `cabal test watcher-core-test`
   - `git diff --check`
   - `git diff --cached --check` if any files are staged.
8. During implementation, inspect the final diff before verification. It should be limited to `agent-workflow-github/agent-workflow-github.cabal`, `cabal.project`, and focused package-boundary assertion updates in `test/Main.hs` unless a Cabal target ambiguity requires a narrowly justified `moifold.cabal` adjustment. Do not edit `orchestrator/state.json`, roadmap files, review artifacts, merge artifacts, event schemas, golden fixtures, compatibility facades, runtime code, prompt policy, source distributions, release notes, or changelogs.
9. Record implementation notes after implementation with the exact package-specific and repository validation commands, including whether `git diff --cached --check` was run or not applicable. Do not write review or merge artifacts.

### Verification

The implementation is correct when `agent-workflow-github` is independently buildable and checkable as a local package candidate, its descriptor metadata matches the approved package identity and release metadata policies, it uses `agent-workflow-github/src` as the source layout, and recursive boundary evidence still proves the GitHub adapter owns identifiers, remote metadata parsing, and pure command rendering helpers without moifold lifecycle, command execution, healthcheck, PR/issue lifecycle, merge/review publication policy, runtime, daemon, event-log, compatibility-file, AppServer/Codex adapter, or concrete watcher state ownership.

Required commands:

```sh
cabal build agent-workflow-github:lib:agent-workflow-github
(cd agent-workflow-github && cabal check)
rg -n "^(import|import qualified) CodexWatcher\\.(AppServer|AppServerClient|AppServerProtocol|ChildDaemon|Cli|Core\\.|Daemon|DaemonLoop|Domain|EffectInterpreter|Effects|EventLog|EventLogRepair|GhGit|Healthcheck|Json|Logging|Observation|Runtime|StateMachine|Supervisor|Turn|TurnOutput|WatcherLiveness|WatcherRuntimeStatus|Workflow\\.(Agent|Daemon|EventLog|Execution|Moifold|Observation|Permission|Transaction|Types))" agent-workflow-github/src
rg -n "\\b(WatcherEvent|SomeWatcherState|RuntimeCommand|RuntimeInterpreter|CommandReport|IssueConfig|PrConfig|ReviewEvidence|CleanReviewEvidence|Healthcheck|EventLogRepair|runtime-owner|daemon-state\\.json|issue-state\\.json|planning-state\\.json|watcher-state\\.json|block-state\\.json|app-server)\\b" agent-workflow-github/src
rg -n "bytestring|containers|directory|filepath|optparse-applicative|singletons|typed-process|unix|websockets|moifold|agent-workflow-core|agent-workflow-codex" agent-workflow-github/agent-workflow-github.cabal
rg -n "aeson >=2\\.2 && <3|base >=4\\.18 && <5|text >=2\\.0 && <3" agent-workflow-github/agent-workflow-github.cabal
cabal build all
cabal test watcher-core-test
git diff --check
git diff --cached --check
```

`git diff --cached --check` is required only when staging happens; if nothing is staged, record that it was not applicable or run it and record the empty result. If staging happens, stage only the intended files and stage any whitespace cleanup explicitly before running the cached whitespace check.

### Worker Fan-Out

No worker fan-out. This item should stay serial because the standalone GitHub descriptor, `cabal.project` package discovery, existing internal sublibrary compatibility, and package-boundary assertions all describe one small adapter package surface and need one owner to keep the layout coherent. Do not create `worker-plan.json`.
