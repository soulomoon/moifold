### Goal
Harden the `agent-workflow-core` package boundary before the indexed rewrite so the core sublibrary cannot accidentally import or depend on moifold lifecycle types, Aeson codecs, runtime interpreters, GitHub adapters, Codex app-server modules, or concrete daemon policy. The round should make the existing package-boundary tests stricter while preserving current event schemas, golden logs, daemon result record shapes, dry-run output, action ordering, and the existing compatibility facade representation.

### Approach
Treat this as boundary-contract test work, not a workflow rewrite. The existing ownership remains:

- `agent-workflow-core` owns only generic workflow contracts and helpers: `WorkflowSpec`, generic codec contracts, event-log replay helpers, permission core, transaction/audit/execution metadata, and generic daemon result projections.
- `agent-workflow-codex` owns Codex app-server protocol, transport, turn lifecycle, and any Aeson codecs needed for app-server JSON.
- `agent-workflow-github` owns GitHub/git command and remote adapters plus their Aeson parsing.
- The main `moifold` library owns concrete watcher lifecycle state/events/effects, runtime interpreters, daemon policy, golden replay fixtures, compatibility snapshots, and the `CodexWatcher.Workflow.Types` compatibility facade for `MoifoldSpec`.

Do not move public workflow APIs or change runtime behavior in this round unless a strengthened guard exposes an existing boundary violation. If that happens, move the concrete reference back to its owning package and keep the existing facade path intact.

### Steps
1. Extend the existing boundary-test area in `test/Main.hs` around `workflowSpecModuleKeepsCoreBoundary` and `workflowCoreCabalSublibraryKeepsPackageBoundary`; do not create a separate ad hoc script unless the test helper code becomes too noisy.
2. Add source-level forbidden import checks for every file under `agent-workflow-core/src`, not only `CodexWatcher.Workflow.Spec`. The forbidden import groups must cover:
   - Moifold lifecycle and policy modules: `CodexWatcher.Core.State`, `CodexWatcher.Domain.`, `CodexWatcher.Effects`, `CodexWatcher.EventLog`, `CodexWatcher.Observation`, `CodexWatcher.StateMachine`, `CodexWatcher.Workflow.Moifold`, `CodexWatcher.Workflow.Observation`.
   - Aeson and concrete JSON codec modules: `Data.Aeson`, `Data.Aeson.Key`, `Data.Aeson.KeyMap`, `Data.Aeson.Types`.
   - Runtime/interpreter modules: `CodexWatcher.ActionExecutor`, `CodexWatcher.Runtime`, `CodexWatcher.EffectInterpreter`, `CodexWatcher.Runtime.Command`, `CodexWatcher.Runtime.Interpreter`.
   - GitHub adapters: `CodexWatcher.GhGit`, `CodexWatcher.Workflow.GitHub`.
   - Codex app-server modules: `CodexWatcher.AppServerClient`, `CodexWatcher.AppServerProtocol`, `CodexWatcher.Workflow.Agent`, `CodexWatcher.Workflow.Agent.Codex`, `CodexWatcher.Workflow.Observation.Agent`.
   - Daemon policy/runtime modules: `CodexWatcher.Daemon`, `CodexWatcher.DaemonLoop`, `CodexWatcher.ChildDaemon`, `CodexWatcher.RunnerGuard`, `CodexWatcher.WatcherRuntimeStatus`, `CodexWatcher.Supervisor`.
3. Add token-level source checks for concrete type or function names that could sneak in without a direct forbidden import. At minimum reject `SomeWatcherState`, `WatcherState`, `WatcherEvent`, `DaemonObservation`, `ObservedPolicyTick`, `EffectPlan`, `SomeEffect`, `ActionExecutionMode`, `RuntimeInterpreter`, `AppServerTurn`, `AppServerRequest`, `GitHubCommandSpec`, `RepoName`, `PrConfig`, `DaemonOptions`, `DaemonTickResult`, `runDaemonTickWithEvents`, and `runObservedDaemonTickWithEvents` inside `agent-workflow-core/src`.
4. Tighten the Cabal component guard for `library agent-workflow-core` so it fails if the core component gains `aeson`, `directory`, `filepath`, `optparse-applicative`, `singletons`, `typed-process`, `unix`, `websockets`, the main `moifold` library, `moifold:agent-workflow-codex`, or `moifold:agent-workflow-github`. Keep the allowed core dependency surface to `base`, `bytestring`, and `text` unless the implementation proves an already-existing allowed core module requires another generic dependency.
5. Keep the existing positive exposure assertions for the generic core modules, including `CodexWatcher.Workflow.Codec` and `CodexWatcher.Workflow.Daemon.Core`, so the guard distinguishes generic core codec/result abstractions from forbidden Aeson codecs and concrete daemon policy.
6. Keep the existing adapter-boundary tests for `agent-workflow-codex`, `agent-workflow-github`, and the main library, adjusting only if the new helper names need to share parsing logic. Do not change event constructors, JSON instances, golden fixture files, daemon result field names, dry-run render/output paths, effect partitioning, action ordering assertions, or `CodexWatcher.Workflow.Types` facade exports.
7. If a new guard fails on existing code, fix the ownership violation narrowly:
   - Move app-server protocol/transport/codecs back to `agent-workflow-codex`.
   - Move GitHub/git remote command parsing back to `agent-workflow-github`.
   - Move concrete watcher lifecycle/event/effect/daemon policy references back to the main `moifold` library.
   - Leave `agent-workflow-core` with generic type parameters, associated types, labels, metadata, and abstract report/action values only.
8. Re-run the focused guard commands below before the full verification suite, and record any intentional no-output checks in `implementation-notes.md` during implementation.

### Verification
Run the exact baseline commands from `orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-001/verification.md`:

```sh
cabal build all
cabal test watcher-core-test
git diff --check
git diff --cached --check
```

Focused boundary checks for this round:

```sh
rg -n '^(import|import qualified) (Data\.Aeson|CodexWatcher\.(ActionExecutor|AppServerClient|AppServerProtocol|ChildDaemon|Core\.State|Daemon|DaemonLoop|Domain\.|EffectInterpreter|Effects|EventLog|GhGit|Observation|RunnerGuard|Runtime|StateMachine|Supervisor|WatcherRuntimeStatus|Workflow\.Agent|Workflow\.GitHub|Workflow\.Moifold|Workflow\.Observation))' agent-workflow-core/src
```

Expected result: no matches.

```sh
rg -n '\b(SomeWatcherState|WatcherState|WatcherEvent|DaemonObservation|ObservedPolicyTick|EffectPlan|SomeEffect|ActionExecutionMode|RuntimeInterpreter|AppServerTurn|AppServerRequest|GitHubCommandSpec|RepoName|PrConfig|DaemonOptions|DaemonTickResult|runDaemonTickWithEvents|runObservedDaemonTickWithEvents)\b' agent-workflow-core/src
```

Expected result: no matches.

```sh
awk 'BEGIN { in_core = 0 } /^library agent-workflow-core$/ { in_core = 1; next } /^library agent-workflow-codex$/ { in_core = 0 } in_core { print }' moifold.cabal | rg -n 'aeson|directory|filepath|optparse-applicative|singletons|typed-process|unix|websockets|moifold,|moifold:agent-workflow-codex|moifold:agent-workflow-github'
```

Expected result: no matches.
