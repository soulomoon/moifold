# Import Facade Cleanup Policy

Round: `round-056`

Scope: policy-from-evidence for these selected public moifold compatibility
modules:

- `CodexWatcher.AppServerClient`
- `CodexWatcher.Core.Ids`
- `CodexWatcher.Workflow.Types`
- `CodexWatcher.Workflow.EventLog`
- `CodexWatcher.Workflow.Execution`
- `CodexWatcher.Workflow.Permission`

This round writes cleanup policy only. It does not add deprecation pragmas,
rewrite imports, change Cabal exposed modules, remove or narrow facades, touch
runtime compatibility-file policy, migrate runtime files, expand the roadmap,
or approve removal.

## Scope And Non-Goals

In scope:

- refresh selected-facade import evidence against the current round worktree;
- refresh Cabal exposure evidence for selected facades and preferred
  replacements;
- classify each selected facade as `keep` or `defer` from rounds 052 and 054;
- name preferred replacement imports for reusable package consumers;
- cite existing protecting tests and missing evidence for future deprecation
  or removal.

Out of scope:

- any `DEPRECATED` pragma or warning policy;
- production import rewrites;
- Cabal descriptor edits or exposed-module changes;
- facade removal, narrowing, or module movement;
- runtime compatibility-file policy, schema, filename, write timing, migration,
  or removal;
- roadmap expansion or terminal cleanup;
- any claim that this policy authorizes removal.

## Refreshed Scan Evidence

Commands run from the round worktree:

```sh
rg -n '^ *import +(qualified +)?CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(Types|EventLog|Execution|Permission))($| +|\()' src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github
rg -n 'exposed-modules|CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(Types|EventLog|Execution|Permission)|Workflow\.Agent\.Codex\.(Client|Transport)|Workflow\.Agent\.Ids|Workflow\.GitHub\.Ids|Workflow\.Spec|Workflow\.EventLog\.Core|Workflow\.EventLog\.File\.Core|Workflow\.EventLog\.Commit\.Core|Workflow\.Execution\.Core|Workflow\.Permission\.Core)' *.cabal */*.cabal
```

Selected-facade import counts in the current tree:

| Facade | Exact selected-facade imports | Policy-relevant regressions |
| --- | ---: | --- |
| `CodexWatcher.AppServerClient` | 28 | None under `agent-workflow-core`, `agent-workflow-codex`, `agent-workflow-github`, or `examples`. |
| `CodexWatcher.Core.Ids` | 65 | None under `agent-workflow-core`, `agent-workflow-codex`, `agent-workflow-github`, or `examples`. |
| `CodexWatcher.Workflow.Types` | 10 | None under `agent-workflow-core`, `agent-workflow-codex`, `agent-workflow-github`, or `examples`. |
| `CodexWatcher.Workflow.EventLog` | 3 | None under `agent-workflow-core`, `agent-workflow-codex`, `agent-workflow-github`, or `examples`. |
| `CodexWatcher.Workflow.Execution` | 4 | None under `agent-workflow-core`, `agent-workflow-codex`, `agent-workflow-github`, or `examples`. |
| `CodexWatcher.Workflow.Permission` | 1 | None under `agent-workflow-core`, `agent-workflow-codex`, `agent-workflow-github`, or `examples`. |

The refreshed counts match round 054. The selected-facade imports remain in
the main moifold source tree, `app/Main.hs`, and tests. The standalone package
candidate directories and examples still avoid the selected compatibility
facades.

## Cabal Exposure

The Cabal exposure scan returned these selected hits:

```text
agent-workflow-github/agent-workflow-github.cabal:46:  exposed-modules:
agent-workflow-github/agent-workflow-github.cabal:48:    CodexWatcher.Workflow.GitHub.Ids
agent-workflow-core/agent-workflow-core.cabal:46:  exposed-modules:
agent-workflow-core/agent-workflow-core.cabal:51:    CodexWatcher.Workflow.EventLog.Commit.Core
agent-workflow-core/agent-workflow-core.cabal:52:    CodexWatcher.Workflow.EventLog.Core
agent-workflow-core/agent-workflow-core.cabal:53:    CodexWatcher.Workflow.EventLog.File.Core
agent-workflow-core/agent-workflow-core.cabal:54:    CodexWatcher.Workflow.Execution.Core
agent-workflow-core/agent-workflow-core.cabal:57:    CodexWatcher.Workflow.Permission.Core
agent-workflow-core/agent-workflow-core.cabal:58:    CodexWatcher.Workflow.Spec
agent-workflow-codex/agent-workflow-codex.cabal:46:  exposed-modules:
agent-workflow-codex/agent-workflow-codex.cabal:50:    CodexWatcher.Workflow.Agent.Codex.Client
agent-workflow-codex/agent-workflow-codex.cabal:53:    CodexWatcher.Workflow.Agent.Codex.Transport
agent-workflow-codex/agent-workflow-codex.cabal:54:    CodexWatcher.Workflow.Agent.Ids
moifold.cabal:31:  exposed-modules:
moifold.cabal:33:    CodexWatcher.AppServerClient
moifold.cabal:46:    CodexWatcher.Core.Ids
moifold.cabal:116:    CodexWatcher.Workflow.EventLog
moifold.cabal:117:    CodexWatcher.Workflow.Execution
moifold.cabal:128:    CodexWatcher.Workflow.Permission
moifold.cabal:129:    CodexWatcher.Workflow.Types
```

Policy consequence:

- the six selected facades remain exposed by the main `moifold` library;
- replacement modules remain exposed by `agent-workflow-core`,
  `agent-workflow-codex`, and `agent-workflow-github`;
- this round does not edit Cabal descriptors or change public exposure.

## Surface Policy

| Surface | Source shape | Current usage | Preferred replacement imports | Protecting tests | Missing evidence | Classification |
| --- | --- | --- | --- | --- | --- | --- |
| `CodexWatcher.AppServerClient` | Pure reexport facade over `CodexWatcher.Workflow.Agent.Codex.Client` and `CodexWatcher.Workflow.Agent.Codex.Transport`. | 28 selected-facade imports in main moifold source/tests. | `CodexWatcher.Workflow.Agent.Codex.Client`; `CodexWatcher.Workflow.Agent.Codex.Transport`. | `test/Main.hs` checks facade ownership and adapter boundaries; `test/AppServerSpec.hs` and `test/CliSpec.hs` compile through app-server/CLI paths. | Complete production import migration, downstream import inventory, and behavior checks for any migration. | `defer` |
| `CodexWatcher.Core.Ids` | Pure combined reexport facade over `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`. | 65 selected-facade imports across `app`, main moifold source, and tests. | `CodexWatcher.Workflow.Agent.Ids` for agent request/thread/turn ids; `CodexWatcher.Workflow.GitHub.Ids` for repo/issue/PR/branch/commit/review-thread ids. | `test/Main.hs` package-boundary checks plus compile-through coverage in `test/GhGitSpec.hs`, `test/AppServerSpec.hs`, `test/CliSpec.hs`, and `test/RuntimeSpec.hs`. | Per-import split plan for combined id users, external downstream inventory, and focused migration validation. | `defer` |
| `CodexWatcher.Workflow.Types` | Product-facing bridge defining `MoifoldSpec`, moifold labels, and planned-transition helpers while reexporting `CodexWatcher.Workflow.Spec`. | 10 selected-facade imports in main moifold source/tests. | `CodexWatcher.Workflow.Spec` and adjacent generic core modules for reusable code; keep this module for concrete moifold lifecycle semantics. | `test/Main.hs` package-boundary assertions and indexed workflow compatibility tests for planned events/effects, replay, labels, and compatibility writes. | Approved replacement for the `MoifoldSpec` owner role and parity evidence for concrete moifold semantics. | `keep` |
| `CodexWatcher.Workflow.EventLog` | Mixed facade/bridge reexporting generic event-log/audit behavior and adding moifold helpers `initializeMoifoldWorkflow`, `applyMoifoldWorkflowEvent`, and `replayMoifoldWorkflowEvents`. | 3 selected-facade imports in `src/CodexWatcher/Daemon.hs`, `src/CodexWatcher/Workflow/DocsMigration.hs`, and `test/Main.hs`. | `CodexWatcher.Workflow.EventLog.Core`; `CodexWatcher.Workflow.EventLog.File.Core`; `CodexWatcher.Workflow.EventLog.Commit.Core`; `CodexWatcher.Workflow.Audit`. | `test/Main.hs` event-log core parity, replay facade, transition effects, file/commit core, and fixture-contract checks. | Old-log/golden compatibility evidence for any behavior change, downstream inventory, and proof that concrete moifold helpers have a replacement. | `defer` |
| `CodexWatcher.Workflow.Execution` | Concrete execution bridge over `CodexWatcher.Workflow.Execution.Core`; owns moifold effect compilation, runtime request-id threading, dry-run/execute helpers, action reports, and failure classification. | 4 selected-facade imports in `src/CodexWatcher/Daemon.hs`, `src/CodexWatcher/Workflow/DocsMigration.hs`, `src/CodexWatcher/Workflow/Types.hs`, and `test/Main.hs`. | `CodexWatcher.Workflow.Execution.Core` for reusable generic execution contracts. | `test/Main.hs` execution-core metadata/generic execution checks and `workflow execution facade preserves dry-run reports`. | Replacement for concrete runtime action/report behavior and behavior parity for execution/dry-run paths. | `keep` |
| `CodexWatcher.Workflow.Permission` | Concrete permission bridge over `CodexWatcher.Workflow.Permission.Core`; adds `validateMoifoldEffectPlan` and `moifoldPermissionPolicy`. | 1 selected-facade import in `test/Main.hs`; public concrete API remains exposed. | `CodexWatcher.Workflow.Permission.Core` for reusable permission checks. | `test/Main.hs` facade/state-machine parity, core permission parity, and allowed/denied moifold policy checks. | External downstream inventory and explicit public-API review even though repo-local production imports are absent. | `defer` |

## Protecting Tests

Existing tests protect the facts this policy relies on:

- `test/Main.hs` package-boundary assertions for `agent-workflow-core`,
  `agent-workflow-codex`, `agent-workflow-github`, and the main moifold
  library;
- main-library facade availability and `AppServerClient` adapter ownership
  checks;
- workflow event-log core/facade parity and replay preservation checks;
- workflow execution dry-run preservation checks;
- workflow permission facade, core, and policy parity checks;
- indexed workflow compatibility checks for planned transitions, replay,
  labels, permissions, and compatibility writes;
- compile-through coverage in `test/AppServerSpec.hs`, `test/CliSpec.hs`,
  `test/GhGitSpec.hs`, and `test/RuntimeSpec.hs`.

This docs-only round does not add tests. The cited tests are existing
protections for current behavior and package boundaries.

## Missing Evidence Before Deprecation

Before adding any deprecation pragma, warning, migration warning, or public
deprecation note for a selected facade, a future selected round must provide:

- current recursive import coverage for the affected facade;
- documented replacement imports and behavior notes for each consumer group;
- package descriptor, README/Haddock, changelog, release-note, and policy
  agreement on the surface status;
- behavior checks for affected replay, execution, permission, dry-run,
  command-rendering, app-server, or id-splitting paths;
- proof that runtime compatibility files and event schemas are unaffected, or
  a separate selected runtime policy/migration round;
- reviewer approval that names the exact surface as ready for deprecation.

## Missing Evidence Before Removal

Before removing any selected facade, narrowing its exports, removing an old
import path, or changing exposed modules, a future selected removal round must
provide:

- import-scan evidence showing no unsupported remaining users of the old path;
- build evidence for the main moifold product and relevant package candidates;
- focused behavior evidence for each affected compatibility path;
- old-log and golden-fixture evidence when event logs, replay, schemas, or
  compatibility files are relevant;
- dry-run rendering, action ordering, request-id, command-rendering,
  healthcheck, or repair evidence when those contracts are touched;
- public docs, changelog, and release-note evidence for externally visible
  changes;
- explicit reviewer approval that names the removed surface and confirms every
  applicable gate is satisfied.

Missing evidence means the selected facade remains available.

## Explicit Non-Approval For Removal

No selected import facade is approved for removal by this round.

No selected facade is classified as `remove-later`. `CodexWatcher.Workflow.Types`
and `CodexWatcher.Workflow.Execution` are `keep` because they still own concrete
moifold behavior. `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`,
`CodexWatcher.Workflow.EventLog`, and `CodexWatcher.Workflow.Permission` are
`defer` because preferred replacements exist for reusable consumers, but
repo-local imports, public API exposure, concrete moifold behavior, downstream
unknowns, or compatibility evidence gaps still block deprecation and removal.

`orchestrator/project-contract.md` already says public compatibility facades
stay available until safe removal is proven with import, build, and behavior
coverage. That durable invariant is accurate for this round, so the project
contract was left unchanged.
