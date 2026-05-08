# Package Extraction Readiness

Status: source-backed readiness report, not a publication decision.

This report records the current extraction readiness of the internal
`agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`
sublibraries. It is evidence for a future external package split decision; it
does not publish packages, remove compatibility facades, or move moifold
lifecycle policy into framework packages.

## Verdict

| Package | Readiness | Evidence summary | Not included in readiness |
| --- | --- | --- | --- |
| `agent-workflow-core` | Structurally ready as the generic workflow-kernel package. | The Cabal section exposes only core workflow modules and depends only on `base`, `bytestring`, and `text`. Recursive boundary tests reject Aeson, Codex, GitHub, runtime, daemon, filesystem, and concrete moifold lifecycle ownership. | External release metadata, package-public compatibility promises, concrete `WatcherEvent` schemas, golden replay policy, daemon loops, filesystem IO, and lifecycle decisions. |
| `agent-workflow-codex` | Structurally ready as the Codex adapter package. | The Cabal section exposes app-server protocol, agent plan/types, Codex client/protocol/interpreter/transport, and observation helpers. It owns `aeson`, `websockets`, `bytestring`, `text`, and the dependency on `agent-workflow-core`. Boundary tests reject moifold lifecycle imports and compatibility-file ownership. | App-server process startup policy, role prompt policy, structured-output schema policy, watcher lifecycle routing, and compatibility facade removal. |
| `agent-workflow-github` | Structurally ready as the pure GitHub parsing and command-spec package. | The Cabal section exposes GitHub ids, remote parsers/classifiers, and pure command specs. It depends on `aeson`, `base`, and `text`, and it does not depend on `moifold` or the Codex adapter package. Boundary tests reject moifold state machine, daemon, runtime, compatibility, and agent imports. | Command execution, runtime rendering policy outside pure specs, PR/issue lifecycle decisions, healthcheck ownership, and merge/review publication policy. |

The current tree is therefore ready for review of extraction feasibility, but
not ready for external package publication. The remaining blockers below are
intentional moifold-owned surfaces, not accidental gaps to push into reusable
packages.

## Evidence Sources

Primary source files:

- `moifold.cabal`: internal sublibrary exposed modules and dependency
  ownership.
- `test/Main.hs`: recursive source-scan and Cabal-boundary assertions.
- `docs/agentic-workflow-framework/implemented-api-freeze.md`: implemented
  internal API freeze and moifold-owned policy boundary.
- `orchestrator/project-contract.md`: repo-wide package and compatibility
  invariants.
- `orchestrator/roadmaps/2026-05-08-00-framework-kernel-migration/rev-001/verification.md`:
  verification contract for this roadmap family.

Inspection commands used for the import and Cabal evidence:

```sh
find agent-workflow-core/src agent-workflow-codex/src agent-workflow-github/src -name '*.hs' -print0 | xargs -0 rg -n '^import '
rg -n "import CodexWatcher\\.Workflow\\.(Agent|GitHub)|import CodexWatcher\\.AppServerProtocol|import CodexWatcher\\.Workflow\\.Agent\\.Codex|import CodexWatcher\\.Workflow\\.GitHub" src test agent-workflow-core agent-workflow-codex agent-workflow-github
rg -n "library agent-workflow-core|library agent-workflow-codex|library agent-workflow-github|exposed-modules:|build-depends:" moifold.cabal
```

Additional negative checks used to verify absent forbidden edges:

```sh
rg -n "^import CodexWatcher\\.(AppServerClient|ActionExecutor|ChildDaemon|Daemon|DaemonLoop|Domain|Effects|EventLog|EventLogRepair|GhGit|Healthcheck|Runtime|StateMachine|Workflow\\.GitHub|Workflow\\.Moifold|Workflow\\.Types)" agent-workflow-codex/src
rg -n "^import CodexWatcher\\.(AppServer|AppServerClient|AppServerProtocol|ChildDaemon|Cli|Core|Daemon|DaemonLoop|Domain|EffectInterpreter|Effects|EventLog|EventLogRepair|GhGit|Healthcheck|Json|Logging|Observation|Runtime|StateMachine|Supervisor|Turn|TurnOutput|Watcher|Workflow\\.Agent|Workflow\\.Daemon|Workflow\\.EventLog|Workflow\\.Execution|Workflow\\.Moifold|Workflow\\.Observation|Workflow\\.Permission|Workflow\\.Transaction|Workflow\\.Types)" agent-workflow-github/src
```

Both negative checks returned no matches in the current tree.

## Import-Graph Evidence

### `agent-workflow-core`

Allowed internal edges are limited to generic workflow modules:

- `Workflow.Audit`, `Workflow.Daemon.Core`, `Workflow.DSL`,
  `Workflow.EventLog.Core`, `Workflow.Indexed.Spec`,
  `Workflow.Permission.Core`, and `Workflow.Transaction.Core` import
  `CodexWatcher.Workflow.Spec` and sibling generic workflow-core modules.
- `Workflow.EventLog.File.Core` imports `ByteString`, `Char`, and `Text`
  helpers only.
- `Workflow.Codec` and `Workflow.Failure` import `Text` helpers and standard
  deriving support only.

Forbidden edges are absent:

- No import of `Data.Aeson`, `CodexWatcher.AppServerProtocol`,
  `CodexWatcher.Workflow.Agent`, `CodexWatcher.Workflow.Agent.Codex`,
  `CodexWatcher.Workflow.GitHub`, `CodexWatcher.Workflow.Moifold`,
  `CodexWatcher.EventLog`, `CodexWatcher.Runtime`, `CodexWatcher.Daemon`,
  `CodexWatcher.Healthcheck`, or lifecycle domain modules.
- The package-boundary assertion rejects those imports and also rejects
  concrete watcher/event/runtime tokens such as `WatcherEvent`,
  `SomeWatcherState`, `RuntimeInterpreter`, `RuntimeOwner`, `PidFile`,
  `CompatibilityWrite`, `FilePath`, and `IO`.

### `agent-workflow-codex`

Allowed internal edges stay inside the Codex adapter plus generic core:

- `CodexWatcher.AppServerProtocol` imports `Workflow.Agent.Ids` and owns
  JSON-RPC request construction.
- `Workflow.Agent.Codex.Protocol`, `Client`, `Transport`, and the aggregate
  `Workflow.Agent.Codex` module import app-server protocol, agent ids/types,
  and Codex client/interpreter modules.
- `Workflow.Observation.Agent` imports `Workflow.Agent`,
  `Workflow.Agent.Codex.Client`, and `Workflow.Spec` to bridge classified
  turns into generic workflow observations.
- `Transport` imports `Network.WebSockets` and `System.Timeout`, matching the
  package's explicit transport ownership.

Forbidden edges are absent:

- No import of `CodexWatcher.AppServerClient`, `CodexWatcher.Domain.*`,
  `CodexWatcher.Daemon*`, `CodexWatcher.EventLog*`, `CodexWatcher.GhGit`,
  `CodexWatcher.Healthcheck`, `CodexWatcher.Runtime.*`,
  `CodexWatcher.StateMachine`, `CodexWatcher.Workflow.GitHub`,
  `CodexWatcher.Workflow.Moifold.*`, or `CodexWatcher.Workflow.Types`.
- The recursive test also rejects compatibility-file names and ownership
  tokens such as `issue-state.json`, `daemon-state.json`,
  `planning-state.json`, `block-state`, `repair-state`, and `runtime-owner`.

### `agent-workflow-github`

Allowed internal edges stay inside the GitHub adapter and JSON parsing:

- `Workflow.GitHub.Remote` imports `Workflow.GitHub.Ids` plus Aeson/Text
  parsing helpers.
- `Workflow.GitHub.Command` imports `Workflow.GitHub.Ids` and Text rendering
  helpers.
- `Workflow.GitHub.Ids` imports `Text` only.

Forbidden edges are absent:

- No import of app-server, Codex agent, moifold core/domain/state-machine,
  daemon, runtime, event-log, healthcheck, repair, prompt, turn-output, or
  workflow lifecycle modules.
- The recursive test also rejects lifecycle ownership tokens such as
  `WatcherEvent`, `SomeWatcherState`, `RuntimeCommand`,
  `RuntimeInterpreter`, `CommandReport`, `IssueConfig`, `PrConfig`,
  `ReviewEvidence`, `CleanReviewEvidence`, `Healthcheck`,
  `EventLogRepair`, `runtime-owner`, and compatibility file names.

### Main moifold library imports

The main library is allowed to import the reusable sublibraries as a concrete
product:

- `src/CodexWatcher/EffectInterpreter.hs`, daemon loop modules, domain loops,
  healthcheck, runtime command rendering, and tests import Codex or GitHub
  adapter APIs where moifold interprets effects or classifies external state.
- `src/CodexWatcher/Core/Ids.hs` imports shared agent and GitHub ids.
- `src/CodexWatcher/AppServerClient.hs` imports only
  `CodexWatcher.Workflow.Agent.Codex.Client` and
  `CodexWatcher.Workflow.Agent.Codex.Transport`, preserving the old module
  name as a compatibility facade.

This direction is acceptable because moifold depends on the framework
sublibraries. The reverse direction would be an extraction blocker; the source
scans above show that reverse lifecycle ownership is not present.

## Dependency Ownership

`moifold.cabal` currently records the intended ownership split:

- `agent-workflow-core` exposes the generic workflow kernel modules and depends
  only on `base`, `bytestring`, and `text`. This keeps the kernel independent
  from Aeson event schemas, websocket transport, command execution,
  filesystem layout, PID/lease ownership, app-server protocol, GitHub parsing,
  and moifold lifecycle state.
- `agent-workflow-codex` exposes the app-server protocol, typed agent adapter,
  Codex client/protocol/interpreter/transport, agent ids/types, and generic
  agent observation bridge. It owns `aeson` because request/response payloads
  are JSON values, `websockets` because transport now lives in this adapter,
  `bytestring` and `text` because the client/transport parse and render
  protocol data, and `moifold:agent-workflow-core` because observation helpers
  target the generic workflow spec.
- `agent-workflow-github` exposes GitHub ids, remote parsers/classifiers, and
  pure command specs. It owns `aeson` for JSON payload parsing and `text` for
  typed ids/rendering. It intentionally has no dependency on `moifold`,
  `agent-workflow-core`, or `agent-workflow-codex`.
- The main `moifold` library owns the concrete product dependencies:
  filesystem, process, CLI, singletons, time, Unix, runtime execution,
  compatibility files, daemon ownership, lifecycle modules, and the three
  workflow sublibraries.

The current dependency graph is one-way:

```text
agent-workflow-core

agent-workflow-codex -> agent-workflow-core

agent-workflow-github

moifold -> agent-workflow-core
moifold -> agent-workflow-codex
moifold -> agent-workflow-github
```

There is no Cabal dependency from `agent-workflow-core` to either adapter, no
dependency from `agent-workflow-codex` to GitHub or moifold, and no dependency
from `agent-workflow-github` to moifold, Codex, or core.

## Compatibility Facade And Deprecation Readiness

| Surface | Current state | Extraction meaning | Deprecation readiness |
| --- | --- | --- | --- |
| `src/CodexWatcher/AppServerClient.hs` | Reexport-only compatibility wrapper for `Workflow.Agent.Codex.Client` and `Workflow.Agent.Codex.Transport`. | The implementation and `websockets` dependency are already owned by `agent-workflow-codex`; existing moifold imports can continue through the old module name. | Ready to document as compatibility-only, but not ready to remove until import coverage and downstream compatibility policy are approved. |
| Main `library` Cabal section | Exposes `CodexWatcher.AppServerClient` but does not use `reexported-modules:` and does not expose adapter modules directly. | Moifold keeps a narrow facade without turning adapter modules into part of the main public library surface. | Ready for gradual import migration inside moifold; removal remains blocked on explicit deprecation policy. |
| `agent-workflow-codex` public modules | Exposes protocol, typed agent data, Codex client/protocol/interpreter/transport, and observation bridge directly. | New code can target the extracted adapter APIs instead of the compatibility wrapper. | Ready for preferred-import guidance, not external stability guarantees. |
| `agent-workflow-github` public modules | Exposes ids, remote parsing/classification, and pure command specs directly. | New code can use pure GitHub specs without pulling moifold runtime policy. | Ready for preferred-import guidance, not command execution policy migration. |
| `agent-workflow-core` public modules | Exposes workflow spec, indexed spec, DSL, codec contracts, event-log cores, execution, permission, transaction, audit, daemon projections, and failure classification. | Reusable kernel APIs are available internally without importing concrete moifold lifecycle state. | Ready for API-freeze review; external versioning and semantic compatibility remain unstarted. |

The facade map is intentionally conservative. Compatibility availability is a
repo-wide contract, so this report does not recommend removing wrapper modules
or compatibility files as part of package extraction readiness.

## Boundary Tests

`test/Main.hs` contains the reviewer-facing assertions that protect this
report:

- `workflowCoreCabalSublibraryKeepsPackageBoundary` verifies core exposed
  modules, the approved `base`/`bytestring`/`text` dependency set, the main
  library's dependency on core, and the absence of concrete lifecycle imports,
  Aeson, runtime ownership, filesystem, IO, Codex, and GitHub tokens.
- `workflowCodexCabalSublibraryKeepsPackageBoundary` verifies Codex exposed
  modules, the approved `aeson`/`base`/`bytestring`/`text`/`websockets`/core
  dependency set, the main library's dependency on Codex, and the absence of
  moifold lifecycle imports and compatibility-file ownership tokens.
- `workflowGithubCabalSublibraryKeepsPackageBoundary` verifies GitHub exposed
  modules, the approved `aeson`/`base`/`text` dependency set, the main
  library's dependency on GitHub, and the absence of moifold lifecycle, daemon,
  runtime, compatibility, Codex, and workflow-policy imports.
- `workflowMoifoldCabalLibraryDoesNotReexportAdapters` verifies the main
  library has no Cabal adapter reexports, keeps dependencies on the Codex and
  GitHub sublibraries, and keeps `CodexWatcher.AppServerClient` as a thin
  wrapper that no longer owns websocket transport.

These assertions are recursive source scans and Cabal-section checks, so they
are more robust than a hand-maintained list of a few representative files.

## Remaining Blockers

The following blockers should remain moifold-owned unless a later roadmap
explicitly changes the contract:

- Concrete `WatcherEvent`, `SomeWatcherState`, event `type` fields, Aeson event
  schemas, schema migrations, replay policy, and golden logs.
- Issue planning, issue implementation, PR review, merge readiness, child
  workflow fanout, close/merge/review-publication policy, and terminal-state
  lifecycle decisions.
- Role prompts, output schemas, evidence requirements, retry escalation,
  classifier compatibility, and structured-output policy.
- Compatibility files and their current names and meanings, including
  `issue-state.json`, `daemon-state.json`, `planning-state.json`, PR URL
  files, block state, repair state, runtime owner files, and compatibility
  snapshots.
- Filesystem writes, process execution, PID files, locks, leases, runtime
  owner stores, watcher supervision, app-server startup, and concrete daemon
  loops.
- Healthcheck, repair, operator runbooks, destructive recovery choices, and
  runtime diagnostics.
- External package metadata, package publication, external semantic versioning,
  changelog policy, Haddock/public-doc polish, and compatibility facade
  deprecation/removal policy.

These blockers are not contradictions in the current package shape. They are
the product policy and runtime authority that the project contract says should
stay outside reusable workflow packages.

## Validation Commands

Reviewers should run:

```sh
git diff --check
cabal build all
cabal test watcher-core-test
```

If staging is involved, also run:

```sh
git diff --cached --check
```

For this report-only round, no Cabal sections, public module lists, source
boundary assertions, event schemas, golden fixtures, or compatibility facades
needed to change. The implementation is artifact-only apart from the README
link to this report.
