# Import Facade Inventory

Round: `round-052`

Scope: evidence-only inventory for:

- `CodexWatcher.AppServerClient`
- `CodexWatcher.Core.Ids`
- `CodexWatcher.Workflow.Types`
- `CodexWatcher.Workflow.EventLog`
- `CodexWatcher.Workflow.Execution`
- `CodexWatcher.Workflow.Permission`

No production source, Cabal descriptor, roadmap, state, policy, runtime compatibility file, import rewrite, deprecation pragma, or module removal was changed by this round.

## Scan Evidence

Commands run from the round worktree:

```sh
rg -n "import CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.(Types|EventLog|Execution|Permission))" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github
rg -n "CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.(Types|EventLog|Execution|Permission))" README.md docs agent-workflow-core agent-workflow-codex agent-workflow-github examples *.cabal */*.cabal
rg -n "exposed-modules|other-modules|CodexWatcher\\.AppServerClient|CodexWatcher\\.Core\\.Ids|CodexWatcher\\.Workflow\\.(Types|EventLog|Execution|Permission)" *.cabal */*.cabal
```

Summary:

- The recursive import scan finds true imports of all selected facades except that the broad `Workflow.EventLog`, `Workflow.Execution`, and `Workflow.Permission` alternation also matches replacement/core submodules such as `CodexWatcher.Workflow.EventLog.Core`, `CodexWatcher.Workflow.EventLog.Commit.Core`, `CodexWatcher.Workflow.EventLog.File.Core`, `CodexWatcher.Workflow.Execution.Core`, and `CodexWatcher.Workflow.Permission.Core`. Exact selected-facade imports were rechecked with anchored import scans before grouping users below.
- The docs/descriptors scan finds the selected facades in `moifold.cabal` and framework docs. It also finds replacement/core modules in package candidate Cabal files, READMEs, and public framework docs.
- The Cabal scan shows the six selected facades are exposed only by the main `moifold` library. Replacement modules are exposed by `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`.

Representative scan hits:

```text
moifold.cabal:33:    CodexWatcher.AppServerClient
moifold.cabal:46:    CodexWatcher.Core.Ids
moifold.cabal:116:    CodexWatcher.Workflow.EventLog
moifold.cabal:117:    CodexWatcher.Workflow.Execution
moifold.cabal:128:    CodexWatcher.Workflow.Permission
moifold.cabal:129:    CodexWatcher.Workflow.Types
agent-workflow-core/agent-workflow-core.cabal:51:    CodexWatcher.Workflow.EventLog.Commit.Core
agent-workflow-core/agent-workflow-core.cabal:52:    CodexWatcher.Workflow.EventLog.Core
agent-workflow-core/agent-workflow-core.cabal:53:    CodexWatcher.Workflow.EventLog.File.Core
agent-workflow-core/agent-workflow-core.cabal:54:    CodexWatcher.Workflow.Execution.Core
agent-workflow-core/agent-workflow-core.cabal:57:    CodexWatcher.Workflow.Permission.Core
agent-workflow-codex/agent-workflow-codex.cabal:50:    CodexWatcher.Workflow.Agent.Codex.Client
agent-workflow-codex/agent-workflow-codex.cabal:53:    CodexWatcher.Workflow.Agent.Codex.Transport
agent-workflow-codex/agent-workflow-codex.cabal:54:    CodexWatcher.Workflow.Agent.Ids
agent-workflow-github/agent-workflow-github.cabal:48:    CodexWatcher.Workflow.GitHub.Ids
```

The broad docs scan also found existing policy/readiness prose in `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`, `release-candidate-bundle.md`, `release-notes.md`, `package-extraction-readiness.md`, and `package-identity-versioning-contract.md`. Those docs already describe the selected modules as compatibility surfaces, but this round does not update or rely on policy approval for removal.

## Cabal Exposure

- Main `moifold` library exposes all selected facades: `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.EventLog`, `CodexWatcher.Workflow.Execution`, `CodexWatcher.Workflow.Permission`, and `CodexWatcher.Workflow.Types`.
- `agent-workflow-core` exposes the generic replacement/core modules for event-log, execution, permission, audit, transaction, DSL, spec, daemon, codec, and failure.
- `agent-workflow-codex` exposes the Codex adapter modules, including `CodexWatcher.Workflow.Agent.Codex.Client`, `CodexWatcher.Workflow.Agent.Codex.Transport`, and `CodexWatcher.Workflow.Agent.Ids`.
- `agent-workflow-github` exposes GitHub adapter modules, including `CodexWatcher.Workflow.GitHub.Ids`.
- The main `moifold` library does not expose `CodexWatcher.Workflow.Agent.*` or `CodexWatcher.Workflow.GitHub.*` adapter modules directly in its library exposed-module list.

## Facade Inventory

### `CodexWatcher.AppServerClient`

- Current module shape: pure reexport facade. It reexports `CodexWatcher.Workflow.Agent.Codex.Client` and `CodexWatcher.Workflow.Agent.Codex.Transport`.
- Exposed-module status: exposed by `moifold.cabal`; replacement modules are exposed by `agent-workflow-codex`.
- Preferred replacement imports: `CodexWatcher.Workflow.Agent.Codex.Client` for app-server turn/client data and parse helpers; `CodexWatcher.Workflow.Agent.Codex.Transport` for endpoint/transport helpers.
- Production users: `src/CodexWatcher/RunnerGuard.hs`, `DaemonLoop/Types.hs`, `Failure.hs`, `Domain/PrReview/TurnClassifier.hs`, `Healthcheck/Types.hs`, `Domain/PrReview/LaunchCli.hs`, `AutomaticLoop/PrReviewHandoff.hs`, `AutomaticLoop/IssuePlanningFanout.hs`, `Cli/Command/AppServerProbe.hs`, `Healthcheck.hs`, `AutomaticLoop/Runner.hs`, `Turn/Classifier/Common.hs`, `Workflow/DocsMigration.hs`, `Cli/Command/IssueFanout.hs`, `DaemonLoop.hs`, `AutomaticLoop/StartupThreads.hs`, `Cli/Command/Service.hs`, `Cli/Command/RunnerGuard.hs`, `Cli/Command/Observe.hs`, `Domain/IssuePlanning/Loop.hs`, `Domain/IssueImplement/TurnClassifier.hs`, `Cli/Types.hs`, `Cli/Parser/Common.hs`, `Domain/IssuePlanning/TurnClassifier.hs`, and `Workflow/Moifold/PrReview/Agent.hs`.
- App/CLI entrypoint users: no `app/` import; several `src/CodexWatcher/Cli/*` modules import it.
- Test users: `test/CliSpec.hs`, `test/AppServerSpec.hs`, and `test/Main.hs`.
- Docs/descriptors: exposed in `moifold.cabal`; named in framework compatibility, readiness, release, and identity docs.
- Protecting tests: `test/Main.hs` asserts "main moifold library does not reexport workflow adapter modules or own app-server transport" by checking the facade imports `CodexWatcher.Workflow.Agent.Codex.Client` and `CodexWatcher.Workflow.Agent.Codex.Transport`, contains no transport ownership definitions, and the main library does not reexport adapter modules or depend on `websockets`. `test/AppServerSpec.hs` and `test/CliSpec.hs` exercise the facade types through app-server and CLI paths.
- Unknowns: many moifold production imports still rely on the facade. The current tests protect facade availability and adapter ownership, but they do not prove a full import migration is ready.

### `CodexWatcher.Core.Ids`

- Current module shape: pure combined reexport facade. It reexports `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`.
- Exposed-module status: exposed by `moifold.cabal`; replacement modules are exposed by `agent-workflow-codex` and `agent-workflow-github`.
- Preferred replacement imports: `CodexWatcher.Workflow.Agent.Ids` for request/thread/turn ids; `CodexWatcher.Workflow.GitHub.Ids` for repo, issue, PR, branch, commit, and review-thread ids.
- Production users: broad main-library usage across runtime, event log, effect interpreter, daemon loop, domain lifecycle modules, healthcheck, CLI parsing/commands, automatic loop, and workflow modules. Exact anchored import scan found more than sixty production-source import sites.
- App/CLI entrypoint users: `app/Main.hs`; multiple `src/CodexWatcher/Cli/*` modules.
- Test users: `test/GhGitSpec.hs`, `test/RuntimeSpec.hs`, `test/AppServerSpec.hs`, `test/Main.hs`, and `test/CliSpec.hs`.
- Docs/descriptors: exposed in `moifold.cabal`; named in framework compatibility, release, and policy docs.
- Protecting tests: `test/Main.hs` includes package-boundary assertions that `agent-workflow-codex` exposes `CodexWatcher.Workflow.Agent.Ids`, `agent-workflow-github` exposes `CodexWatcher.Workflow.GitHub.Ids`, and standalone adapter packages exclude moifold lifecycle imports. `test/GhGitSpec.hs`, `test/AppServerSpec.hs`, `test/CliSpec.hs`, and `test/RuntimeSpec.hs` compile through the compatibility facade.
- Unknowns: the combined facade mixes agent and GitHub identifiers, so migration would require per-import ownership splitting. Current coverage proves exposed-module/package-boundary shape, not that every moifold import can be mechanically split without churn.

### `CodexWatcher.Workflow.Types`

- Current module shape: product-facing bridge, not a pure replacement alias. It defines `MoifoldSpec`, labels for moifold states/events/observations/effects, and `legacyObservedPlannedTransition`/`moifoldPlannedTransitionFromEffects` while reexporting `CodexWatcher.Workflow.Spec`.
- Exposed-module status: exposed by `moifold.cabal`; generic spec modules are exposed by `agent-workflow-core`.
- Preferred replacement imports: generic reusable workflow code should import `CodexWatcher.Workflow.Spec` and adjacent core modules directly. Moifold lifecycle code currently still needs `MoifoldSpec` and concrete label/transition helpers from this module.
- Production users: `src/CodexWatcher/Workflow/EventLog.hs`, `Workflow/Permission.hs`, `Daemon.hs`, and indexed moifold workflow modules under `src/CodexWatcher/Workflow/Moifold/*/Indexed.hs`.
- App/CLI entrypoint users: none.
- Test users: `test/Main.hs`.
- Docs/descriptors: exposed in `moifold.cabal`; named in framework compatibility, extraction, release, readiness, and policy docs.
- Protecting tests: `test/Main.hs` asserts package boundaries for standalone workflow packages and includes facade behavior tests such as "workflow planned-transition facade preserves observed event and effects", plus extensive indexed workflow compatibility assertions that compare planned events/effects, replay, labels, and compatibility writes against `MoifoldSpec`.
- Unknowns: this module owns concrete moifold workflow semantics and is not simply a deprecated import facade. No current evidence supports removal without a new product-facing replacement for `MoifoldSpec`.

### `CodexWatcher.Workflow.EventLog`

- Current module shape: mixed generic reexport/bridge. It reexports and wraps `CodexWatcher.Workflow.EventLog.Core` and `CodexWatcher.Workflow.Audit`, while adding moifold-specific helpers `initializeMoifoldWorkflow`, `applyMoifoldWorkflowEvent`, and `replayMoifoldWorkflowEvents`.
- Exposed-module status: exposed by `moifold.cabal`; core event-log, file, commit, transaction, and audit modules are exposed by `agent-workflow-core`.
- Preferred replacement imports: `CodexWatcher.Workflow.EventLog.Core` for generic replay/transition helpers; `CodexWatcher.Workflow.EventLog.File.Core` for generic file line handling; `CodexWatcher.Workflow.EventLog.Commit.Core` for commit abstraction; `CodexWatcher.Workflow.Audit` for generic audit helpers where appropriate.
- Production users: exact selected-facade imports in `src/CodexWatcher/Daemon.hs` and `src/CodexWatcher/Workflow/DocsMigration.hs`; the module itself imports core modules. Other broad scan hits are replacement/core imports, not selected-facade users.
- App/CLI entrypoint users: none.
- Test users: `test/Main.hs`.
- Docs/descriptors: exposed in `moifold.cabal`; replacement modules appear in `agent-workflow-core.cabal`, `agent-workflow-core/README.md`, and framework public docs.
- Protecting tests: `test/Main.hs` asserts "workflow event-log core initialize matches moifold facade", "workflow event-log core apply matches moifold facade", "workflow replay facade preserves direct replay result", "workflow spec replay facade preserves direct replay result", "workflow event-log facade initializes and applies to replay state", and "workflow event-log facade exposes transition effects".
- Unknowns: generic core parity is tested for selected scenarios, but the moifold helpers still bind concrete `WatcherEvent`, `SomeWatcherState`, replay policy, and failure formatting. Old-log/golden compatibility evidence would be needed for any future removal affecting event-log behavior.

### `CodexWatcher.Workflow.Execution`

- Current module shape: concrete execution bridge. It imports `CodexWatcher.Workflow.Execution.Core` but also owns moifold concrete action/effect compilation, runtime config/request-id threading, dry-run/execute helpers, and command report failure classification.
- Exposed-module status: exposed by `moifold.cabal`; `CodexWatcher.Workflow.Execution.Core` is exposed by `agent-workflow-core`.
- Preferred replacement import: `CodexWatcher.Workflow.Execution.Core` for reusable generic effect metadata, generic compiled plans, and generic execution traversal. Concrete moifold runtime code still uses this facade for `EffectPlan`, `SomeEffect`, `CompiledEffectPlan`, `ActionExecutionReport`, `RequestId`, and runtime command behavior.
- Production users: exact selected-facade imports in `src/CodexWatcher/Daemon.hs`, `src/CodexWatcher/Workflow/Types.hs`, and `src/CodexWatcher/Workflow/DocsMigration.hs`; the module itself imports `Execution.Core`.
- App/CLI entrypoint users: none.
- Test users: `test/Main.hs`.
- Docs/descriptors: exposed in `moifold.cabal`; core replacement module appears in `agent-workflow-core.cabal`, package README, and public framework docs.
- Protecting tests: `test/Main.hs` asserts "workflow execution facade preserves dry-run reports" and also checks core execution behavior through package-boundary tests and indexed workflow compatibility tests that compare planned pre/post-commit effects.
- Unknowns: replacement readiness is partial because concrete effect compilation and runtime action/report behavior remain in moifold-owned modules.

### `CodexWatcher.Workflow.Permission`

- Current module shape: concrete permission bridge. It imports `CodexWatcher.Workflow.Permission.Core`, reexports generic permission types/helpers, and adds `validateMoifoldEffectPlan` plus `moifoldPermissionPolicy` over `MoifoldSpec`.
- Exposed-module status: exposed by `moifold.cabal`; `CodexWatcher.Workflow.Permission.Core` is exposed by `agent-workflow-core`.
- Preferred replacement import: `CodexWatcher.Workflow.Permission.Core` for reusable permission policy/check machinery. Moifold lifecycle code still uses this facade for concrete phase-action validation over `SomeWatcherState`, `EffectPlan`, and `MoifoldSpec`.
- Production users: exact selected-facade import in `test/Main.hs`; the production module itself imports core and `Workflow.Types`. No other production module imports the selected facade directly in the anchored scan.
- App/CLI entrypoint users: none.
- Test users: `test/Main.hs`.
- Docs/descriptors: exposed in `moifold.cabal`; core replacement module appears in `agent-workflow-core.cabal`, package README, and public framework docs.
- Protecting tests: `test/Main.hs` asserts "workflow permission facade matches state-machine validation", "workflow permission core checks match moifold validation", "workflow permission policy accepts allowed moifold effects", and "workflow permission policy rejects denied moifold effects like state machine".
- Unknowns: no direct production import currently depends on this facade, but it remains public and concrete. Removal readiness would still need explicit public-API and downstream compatibility review.

## Cross-Cutting Unknowns

- Existing docs already contain compatibility/deprecation policy language, but this inventory does not approve deprecation or removal.
- The scan proves current repo-local imports and descriptor exposure. It does not inventory external downstream users.
- Current tests strongly protect package-boundary shape and selected behavioral parity paths, but not complete import-migration readiness for all moifold users.
- `CodexWatcher.Workflow.Types`, `CodexWatcher.Workflow.EventLog`, `CodexWatcher.Workflow.Execution`, and `CodexWatcher.Workflow.Permission` include concrete moifold lifecycle behavior; treating them as pure import aliases would be incorrect.
