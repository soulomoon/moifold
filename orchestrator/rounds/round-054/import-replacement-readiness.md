# Import Replacement Readiness

Round: `round-054`

Scope: evidence-only import replacement readiness for:

- `CodexWatcher.AppServerClient`
- `CodexWatcher.Core.Ids`
- `CodexWatcher.Workflow.Types`
- `CodexWatcher.Workflow.EventLog`
- `CodexWatcher.Workflow.Execution`
- `CodexWatcher.Workflow.Permission`

This round does not remove wrappers, add deprecation pragmas, change public
module exposure, rewrite production imports, touch runtime compatibility-file
behavior gates, write cleanup policy, expand the roadmap, or approve final
removal.

## Scan Evidence

Commands run from the round worktree:

```sh
rg -n '^ *import +(qualified +)?CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(Types|EventLog|Execution|Permission))(\b| +as +| *$)' src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github
rg -n '^ *import +(qualified +)?CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(Types|EventLog|Execution|Permission))($| +|\()' src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github
rg -n 'CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(Types|EventLog|Execution|Permission)|Workflow\.Agent\.Codex\.(Client|Transport)|Workflow\.Agent\.Ids|Workflow\.GitHub\.Ids|Workflow\.Spec|Workflow\.EventLog\.Core|Workflow\.EventLog\.File\.Core|Workflow\.EventLog\.Commit\.Core|Workflow\.Execution\.Core|Workflow\.Permission\.Core)' README.md docs examples *.cabal */*.cabal agent-workflow-core agent-workflow-codex agent-workflow-github
rg -n 'exposed-modules|other-modules|CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(Types|EventLog|Execution|Permission)|Workflow\.Agent\.Codex\.(Client|Transport)|Workflow\.Agent\.Ids|Workflow\.GitHub\.Ids|Workflow\.Spec|Workflow\.EventLog\.Core|Workflow\.EventLog\.File\.Core|Workflow\.EventLog\.Commit\.Core|Workflow\.Execution\.Core|Workflow\.Permission\.Core)' *.cabal */*.cabal
```

Notes:

- The first command is the literal plan command. It still matches replacement
  submodules such as `CodexWatcher.Workflow.EventLog.Core` because `\b` matches
  before `.`. The second command is the stricter selected-facade scan used for
  the current import-user counts below.
- The stricter selected-facade scan found no selected-facade imports under
  `agent-workflow-core`, `agent-workflow-codex`, `agent-workflow-github`, or
  `examples`.
- Exact selected-facade import counts: `CodexWatcher.AppServerClient` 28,
  `CodexWatcher.Core.Ids` 65, `CodexWatcher.Workflow.Types` 10,
  `CodexWatcher.Workflow.EventLog` 3, `CodexWatcher.Workflow.Execution` 4,
  and `CodexWatcher.Workflow.Permission` 1.
- Docs and Cabal scans find all selected facades exposed by the main
  `moifold` library. Replacement modules are exposed by the standalone package
  candidates and documented in the package/framework docs.

## Cabal Exposure

- `moifold.cabal` exposes all selected facades:
  `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`,
  `CodexWatcher.Workflow.EventLog`, `CodexWatcher.Workflow.Execution`,
  `CodexWatcher.Workflow.Permission`, and `CodexWatcher.Workflow.Types`.
- `agent-workflow-core/agent-workflow-core.cabal` exposes
  `CodexWatcher.Workflow.Spec`,
  `CodexWatcher.Workflow.EventLog.Core`,
  `CodexWatcher.Workflow.EventLog.File.Core`,
  `CodexWatcher.Workflow.EventLog.Commit.Core`,
  `CodexWatcher.Workflow.Execution.Core`, and
  `CodexWatcher.Workflow.Permission.Core`.
- `agent-workflow-codex/agent-workflow-codex.cabal` exposes
  `CodexWatcher.Workflow.Agent.Codex.Client`,
  `CodexWatcher.Workflow.Agent.Codex.Transport`, and
  `CodexWatcher.Workflow.Agent.Ids`.
- `agent-workflow-github/agent-workflow-github.cabal` exposes
  `CodexWatcher.Workflow.GitHub.Ids`.
- The main `moifold` library keeps these selected facades available while not
  exposing standalone adapter modules directly.

## Package-Boundary Expectations

The package split remains the project-contract split:

- `agent-workflow-core` owns generic workflow kernel modules only.
- `agent-workflow-codex` owns Codex app-server protocol and typed agent
  adapters.
- `agent-workflow-github` owns GitHub identifiers and command/remote helpers.
- The main `moifold` library owns concrete issue/PR lifecycle policy, daemon
  ownership, process execution, filesystem writes, compatibility snapshots,
  healthcheck, repair, and the selected public compatibility facades.

Existing `test/Main.hs` package-boundary assertions protect these expectations:

- standalone workflow packages expose their approved source modules;
- standalone packages exclude moifold lifecycle imports and runtime
  compatibility-file ownership text;
- the main moifold library keeps the selected facades while avoiding direct
  adapter-module reexports;
- `CodexWatcher.AppServerClient` remains a facade over
  `CodexWatcher.Workflow.Agent.Codex.Client` and
  `CodexWatcher.Workflow.Agent.Codex.Transport`.

No new source assertions were added in this round because those existing tests
already protect the package-boundary and facade-parity facts used here.

## Facade Readiness

### `CodexWatcher.AppServerClient`

- Current shape: pure reexport facade over
  `CodexWatcher.Workflow.Agent.Codex.Client` and
  `CodexWatcher.Workflow.Agent.Codex.Transport`.
- Current exact import users: 28 selected-facade imports, all in the main
  moifold source tree or tests. Users include runner guard, daemon loop,
  healthcheck, CLI app-server/service/observe/runner-guard/issue-fanout
  commands, automatic loop handoff/fanout/startup/runner modules, issue and PR
  turn classifiers, docs migration, and app-server/CLI tests.
- Preferred replacement imports:
  `CodexWatcher.Workflow.Agent.Codex.Client` for app-server turn/client data
  and parse helpers, and `CodexWatcher.Workflow.Agent.Codex.Transport` for
  endpoint and transport helpers.
- Current Cabal exposure: facade exposed by `moifold.cabal`; replacements
  exposed by `agent-workflow-codex`.
- Package-boundary expectation: reusable Codex-adapter users should import the
  adapter modules directly; moifold may keep the public facade while internal
  production imports remain broad.
- Protecting tests: `test/Main.hs` asserts the facade imports the adapter
  modules, the main library does not own websocket transport or expose adapter
  modules directly, and app-server/CLI tests compile through the current
  facade.
- Missing evidence: no complete production import migration has been attempted
  or proven; external downstream users were not inventoried.
- Classification: `defer`. It is replacement-path ready for reusable consumers,
  but not a removal-later candidate while 28 repo-local imports still rely on
  the facade.

### `CodexWatcher.Core.Ids`

- Current shape: pure combined reexport facade over
  `CodexWatcher.Workflow.Agent.Ids` and
  `CodexWatcher.Workflow.GitHub.Ids`.
- Current exact import users: 65 selected-facade imports across `app/Main.hs`,
  broad main moifold runtime/domain/CLI/workflow modules, and tests.
- Preferred replacement imports:
  `CodexWatcher.Workflow.Agent.Ids` for request/thread/turn identifiers and
  `CodexWatcher.Workflow.GitHub.Ids` for repository, issue, PR, branch, commit,
  and review-thread identifiers.
- Current Cabal exposure: facade exposed by `moifold.cabal`; replacements
  exposed by `agent-workflow-codex` and `agent-workflow-github`.
- Package-boundary expectation: reusable adapter packages should use the split
  id modules directly; moifold can keep the combined convenience facade until
  each import site is split by domain.
- Protecting tests: `test/Main.hs` asserts standalone adapter package exposure
  and dependency boundaries; runtime, GitHub, app-server, CLI, and main tests
  compile through the current facade.
- Missing evidence: no per-import split plan exists for the 65 current users,
  and no external downstream inventory was performed.
- Classification: `defer`. Replacement modules are exposed and protected, but
  the combined facade is still heavily used and cannot be treated as a simple
  removal candidate.

### `CodexWatcher.Workflow.Types`

- Current shape: product-facing bridge, not a pure compatibility alias. It
  defines `MoifoldSpec`, moifold state/event/observation/effect labels, and
  moifold planned-transition helpers while reexporting
  `CodexWatcher.Workflow.Spec`.
- Current exact import users: 10 selected-facade imports in the main moifold
  source tree and tests, including `Daemon`, `Workflow.EventLog`,
  `Workflow.Permission`, indexed moifold issue-planning/issue-implementation
  and PR-review modules, and `test/Main.hs`.
- Preferred replacement imports: generic reusable workflow code should import
  `CodexWatcher.Workflow.Spec` and adjacent core modules directly. Concrete
  moifold lifecycle code still needs this module for `MoifoldSpec` and moifold
  labels/planning helpers.
- Current Cabal exposure: facade exposed by `moifold.cabal`; generic spec
  module exposed by `agent-workflow-core`.
- Package-boundary expectation: reusable workflow packages must not import this
  product-facing module; main moifold code may keep it as the bridge from
  generic contracts to concrete lifecycle semantics.
- Protecting tests: package-boundary tests reject `Workflow.Types` in
  standalone packages; indexed workflow compatibility tests exercise
  `MoifoldSpec`, planned transitions, replay, labels, and compatibility writes.
- Missing evidence: no approved replacement exists for the concrete
  `MoifoldSpec` owner role.
- Classification: `keep`. It owns concrete moifold semantics and should not be
  treated as a removable import facade in this evidence round.

### `CodexWatcher.Workflow.EventLog`

- Current shape: mixed facade/bridge. It reexports generic event-log/audit
  behavior and adds moifold-specific helpers:
  `initializeMoifoldWorkflow`, `applyMoifoldWorkflowEvent`, and
  `replayMoifoldWorkflowEvents`.
- Current exact import users: 3 selected-facade imports in `src/CodexWatcher/Daemon.hs`,
  `src/CodexWatcher/Workflow/DocsMigration.hs`, and `test/Main.hs`.
- Preferred replacement imports:
  `CodexWatcher.Workflow.EventLog.Core` for generic replay/transition helpers,
  `CodexWatcher.Workflow.EventLog.File.Core` for generic line handling,
  `CodexWatcher.Workflow.EventLog.Commit.Core` for commit abstraction, and
  `CodexWatcher.Workflow.Audit` for generic audit helpers.
- Current Cabal exposure: facade exposed by `moifold.cabal`; replacement/core
  modules exposed by `agent-workflow-core`.
- Package-boundary expectation: reusable workflow code should use core modules
  directly; moifold may keep this facade for concrete `WatcherEvent`,
  `SomeWatcherState`, replay formatting, and audit/failure behavior.
- Protecting tests: `test/Main.hs` checks core replay, fixture contracts,
  initialize/apply parity with moifold facade, direct replay parity, transition
  effects, and event-log file/commit core behavior.
- Missing evidence: old-log/golden compatibility evidence would be needed for
  any future removal affecting concrete event-log behavior; no downstream
  import inventory was performed.
- Classification: `defer`. Generic replacements are proven, but concrete
  moifold helpers remain product-owned.

### `CodexWatcher.Workflow.Execution`

- Current shape: concrete execution bridge over
  `CodexWatcher.Workflow.Execution.Core`. It owns concrete effect compilation,
  runtime config/request-id threading, dry-run/execute helpers, action reports,
  and failure classification.
- Current exact import users: 4 selected-facade imports in `src/CodexWatcher/Daemon.hs`,
  `src/CodexWatcher/Workflow/DocsMigration.hs`,
  `src/CodexWatcher/Workflow/Types.hs`, and `test/Main.hs`.
- Preferred replacement import: `CodexWatcher.Workflow.Execution.Core` for
  reusable generic effect metadata, compiled plans, and generic execution
  traversal.
- Current Cabal exposure: facade exposed by `moifold.cabal`; core replacement
  exposed by `agent-workflow-core`.
- Package-boundary expectation: reusable workflow packages should use the core
  execution module; main moifold runtime code keeps concrete action execution
  and command-report behavior here.
- Protecting tests: `test/Main.hs` checks execution-core metadata and generic
  execution behavior, plus "workflow execution facade preserves dry-run
  reports" against the concrete executor path.
- Missing evidence: concrete runtime action/report behavior has not been
  migrated to a replacement module and remains moifold-owned.
- Classification: `keep`. This is not a pure import facade; it still owns
  concrete moifold runtime execution behavior.

### `CodexWatcher.Workflow.Permission`

- Current shape: concrete permission bridge over
  `CodexWatcher.Workflow.Permission.Core`. It reexports generic permission
  helpers and adds `validateMoifoldEffectPlan` plus
  `moifoldPermissionPolicy`.
- Current exact import users: 1 selected-facade import in `test/Main.hs`; the
  module itself is public and used indirectly through `Workflow.Types` and
  moifold validation paths.
- Preferred replacement import: `CodexWatcher.Workflow.Permission.Core` for
  reusable permission policies/check machinery.
- Current Cabal exposure: facade exposed by `moifold.cabal`; core replacement
  exposed by `agent-workflow-core`.
- Package-boundary expectation: reusable workflow code should use the core
  permission module. Moifold concrete phase/action validation remains owned by
  the main library.
- Protecting tests: `test/Main.hs` checks the facade against state-machine
  validation, checks core permission errors against moifold validation, and
  verifies policy accept/reject behavior.
- Missing evidence: even with no production selected-facade imports, this
  remains a public concrete API; external downstream users were not inventoried.
- Classification: `defer`. It is the closest future removal candidate in the
  repo-local scan, but public API review and downstream/user evidence are still
  missing, and this round cannot approve removal.

## Cross-Cutting Missing Evidence

- No external downstream import inventory was performed.
- No production import rewrite was attempted or proven in this round.
- No public deprecation/removal policy was changed or approved.
- Runtime compatibility-file behavior gates from round 053 remain separate and
  untouched.
- `CodexWatcher.Workflow.Types`, `CodexWatcher.Workflow.EventLog`,
  `CodexWatcher.Workflow.Execution`, and
  `CodexWatcher.Workflow.Permission` contain concrete moifold behavior; future
  policy must distinguish generic replacement paths from product-owned helpers.

## Summary Classification

| Facade | Classification | Reason |
| --- | --- | --- |
| `CodexWatcher.AppServerClient` | `defer` | Replacement modules are exposed, but 28 repo-local imports and external-user unknowns block removal readiness. |
| `CodexWatcher.Core.Ids` | `defer` | Split replacement modules are exposed, but 65 combined-facade imports need domain-by-domain migration evidence. |
| `CodexWatcher.Workflow.Types` | `keep` | Owns `MoifoldSpec` and concrete moifold transition/label helpers. |
| `CodexWatcher.Workflow.EventLog` | `defer` | Generic replacements are proven, but concrete moifold replay helpers and old-log behavior need future evidence. |
| `CodexWatcher.Workflow.Execution` | `keep` | Owns concrete moifold runtime execution and command/report behavior. |
| `CodexWatcher.Workflow.Permission` | `defer` | No production selected-facade imports, but it is public and still bridges concrete moifold permission policy. |
