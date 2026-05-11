## Scope

Round: `round-097-facade-import-scan-refresh`
Roadmap: `2026-05-11-00-highest-value-cleanup`, `rev-001`
Milestone: `milestone-003-import-convergence-package-boundaries`
Direction: `direction-009-facade-import-scan-refresh`
Extracted item: `round-097-facade-import-scan-refresh`

This is a round-local evidence inventory only. It refreshes current references
to the selected compatibility facades after the completed test-split and
runtime-compatibility fixture rounds. It does not change production imports,
test imports, Cabal exposed modules, docs, package descriptors, public API,
runtime compatibility files, fixtures, roadmap files, controller state, or
behavior.

## Roadmap Lineage

- Controller state re-read from `orchestrator/state.json` points at active
  roadmap `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`
  and active round `round-097`.
- Selection artifact re-read:
  `orchestrator/rounds/round-097/selection.md`.
- Plan artifact re-read:
  `orchestrator/rounds/round-097/plan.md`.
- Active roadmap artifact re-read:
  `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`.
- Active verification artifact re-read:
  `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`.
- Stable project contract re-read:
  `orchestrator/project-contract.md`.

## Non-Goals

- No import migration.
- No Cabal exposure change.
- No public deprecation.
- No facade removal.
- No compatibility-file cleanup classification, rename, deletion, or runtime
  cleanup approval.
- No runtime, healthcheck, repair, replay, restart, prompt, event-schema, or
  permission behavior change.
- No roadmap edit, controller state edit, release approval, milestone
  completion claim, or terminal completion claim.

## Scan Commands

Broad selected-facade reference scan:

```sh
rg -n "CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.EventLog|Workflow\\.Permission)" \
  src app test agent-workflow-core agent-workflow-codex agent-workflow-github \
  docs examples scripts *.cabal cabal.project
```

Narrow import-only scan:

```sh
rg -n "^import[[:space:]]+(qualified[[:space:]]+)?CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.EventLog|Workflow\\.Permission)([[:space:]]|$|\\()" \
  src app test agent-workflow-core agent-workflow-codex agent-workflow-github
```

Package exposure and direct-owner scan:

```sh
rg -n "exposed-modules:|CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.EventLog|Workflow\\.Permission)|CodexWatcher\\.Workflow\\.(Agent\\.Codex|Agent\\.Ids|GitHub\\.Ids|EventLog\\.|Permission\\.Core)" \
  moifold.cabal agent-workflow-core/agent-workflow-core.cabal \
  agent-workflow-codex/agent-workflow-codex.cabal \
  agent-workflow-github/agent-workflow-github.cabal cabal.project
```

Direct-owner import scan:

```sh
rg -n "^import[[:space:]]+(qualified[[:space:]]+)?CodexWatcher\\.Workflow\\.(Agent\\.Codex\\.(Client|Transport)|Agent\\.Ids|GitHub\\.Ids|EventLog\\.(Core|File\\.Core|Commit\\.Core)|Audit|Permission\\.Core)([[:space:]]|$|\\()" \
  src app test agent-workflow-core agent-workflow-codex agent-workflow-github
```

Additional exact-reference and symbol scans were used only to separate exact
selected-facade references from owner-module prefix matches in docs and to
classify `Core.Ids` users by agent-id versus GitHub-id symbols.

## Scan Summary

- Narrow import-only selected-facade counts:
  - `CodexWatcher.AppServerClient`: 19 imports, grouped as `src`: 12,
    `test`: 7.
  - `CodexWatcher.Core.Ids`: 44 imports, grouped as `src`: 31, `app`: 1,
    `test`: 12.
  - `CodexWatcher.Workflow.EventLog`: 10 imports, grouped as `src`: 2,
    `test`: 8.
  - `CodexWatcher.Workflow.Permission`: 7 imports, grouped as `test`: 7.
- No exact selected-facade imports were found in
  `agent-workflow-core`, `agent-workflow-codex`, or
  `agent-workflow-github`.
- No exact selected-facade references were found under `examples` or `scripts`.
- `moifold.cabal` still exposes all four selected compatibility facades.
- Standalone package candidates expose and import direct owner modules:
  `CodexWatcher.Workflow.Agent.Codex.Client`,
  `CodexWatcher.Workflow.Agent.Codex.Transport`,
  `CodexWatcher.Workflow.Agent.Ids`,
  `CodexWatcher.Workflow.GitHub.Ids`,
  `CodexWatcher.Workflow.EventLog.Core`,
  `CodexWatcher.Workflow.EventLog.File.Core`,
  `CodexWatcher.Workflow.EventLog.Commit.Core`,
  `CodexWatcher.Workflow.Audit`, and
  `CodexWatcher.Workflow.Permission.Core`.

## Per-Facade Inventory

### `CodexWatcher.AppServerClient`

- Facade file: `src/CodexWatcher/AppServerClient.hs`.
- Facade shape: pure reexport of
  `CodexWatcher.Workflow.Agent.Codex.Client` and
  `CodexWatcher.Workflow.Agent.Codex.Transport`.
- Current Cabal exposure: `moifold.cabal:33`.
- Direct-owner replacement modules visible from source:
  - `CodexWatcher.Workflow.Agent.Codex.Client`
  - `CodexWatcher.Workflow.Agent.Codex.Transport`
- Standalone package candidate result: no selected-facade imports found under
  `agent-workflow-core`, `agent-workflow-codex`, or
  `agent-workflow-github`; `agent-workflow-codex.cabal` exposes the direct
  Codex client and transport modules.

Current exact import references:

- `src` imports:
  - `src/CodexWatcher/RunnerGuard.hs`: `blocked/needs later evidence`.
    Uses endpoint/session requests, thread parsing, and failure formatting.
  - `src/CodexWatcher/Domain/PrReview/TurnClassifier.hs`:
    `blocked/needs later evidence`. Uses `AppServerTurn` classification.
  - `src/CodexWatcher/Domain/PrReview/LaunchCli.hs`:
    `blocked/needs later evidence`. Uses endpoint thread launch,
    request ids, and failure formatting.
  - `src/CodexWatcher/Healthcheck.hs`: `blocked/needs later evidence`.
    Uses endpoint thread reads, turn parsing, timeout options, and failure
    formatting.
  - `src/CodexWatcher/AutomaticLoop/Runner.hs`:
    `blocked/needs later evidence`. Uses endpoint-backed interpreter and
    default options.
  - `src/CodexWatcher/Domain/IssuePlanning/TurnClassifier.hs`:
    `blocked/needs later evidence`. Uses `AppServerTurn` classification.
  - `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`:
    `blocked/needs later evidence`. Uses app-server turn observations and
    failure-bearing daemon request behavior.
  - `src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`:
    `blocked/needs later evidence`. Uses `AppServerTurn` classification.
  - `src/CodexWatcher/Turn/Classifier/Common.hs`:
    `blocked/needs later evidence`. Uses shared turn-completion
    classification.
  - `src/CodexWatcher/Cli/Command/AppServerProbe.hs`:
    `blocked/needs later evidence`. Uses endpoint requests, client options,
    thread-start parsing, and failure formatting.
  - `src/CodexWatcher/Cli/Command/IssueFanout.hs`:
    `blocked/needs later evidence`. Uses endpoint launch and failure
    formatting for child issue implementers.
  - `src/CodexWatcher/Cli/Command/Observe.hs`:
    `blocked/needs later evidence`. Uses endpoint-backed interpreter and
    default options.
- `app` imports: none found.
- `test` imports:
  - `test/Main.hs`
  - `test/TestSupport/Workflow.hs`
  - `test/WorkflowAgentSpec.hs`
  - `test/WorkflowDocsMigrationSpec.hs`
  - `test/WorkflowEventLogSpec.hs`
  - `test/WorkflowExecutionSpec.hs`
  - `test/WorkflowIndexedSpec.hs`
  These are `test-policy evidence` because they preserve facade and workflow
  behavior coverage while the test topology is still acting as the evidence
  base for later import-convergence rounds.
- Package descriptors: `moifold.cabal:33` is `public exposure`.
- Docs and policy references:
  `docs/agentic-workflow-framework/package-extraction-readiness.md`,
  `docs/agentic-workflow-framework/package-identity-versioning-contract.md`,
  `docs/agentic-workflow-framework/release-candidate-bundle.md`,
  `docs/agentic-workflow-framework/release-notes.md`, and
  `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`.
  These are `documentation/policy reference`, not import migration or public
  deprecation approval.

Next-slice blockers:

- Endpoint parsing, app-server protocol, session initialization, timeout and
  fallback handling, command rendering, and failure-formatting behavior must be
  verified for each touched source file before a later slice moves imports.
- Direct-owner imports already exist elsewhere, so later convergence work can
  be source-file scoped; this artifact does not prove any individual migration
  is behaviorally safe.

### `CodexWatcher.Core.Ids`

- Facade file: `src/CodexWatcher/Core/Ids.hs`.
- Facade shape: pure reexport of `CodexWatcher.Workflow.Agent.Ids` and
  `CodexWatcher.Workflow.GitHub.Ids`.
- Current Cabal exposure: `moifold.cabal:46`.
- Direct-owner replacement modules visible from source:
  - `CodexWatcher.Workflow.Agent.Ids` for `RequestId`, `ThreadId`, `TurnId`,
    and `nextRequestId`.
  - `CodexWatcher.Workflow.GitHub.Ids` for `RepoName`, `IssueNumber`,
    `PrNumber`, `BranchName`, `ReviewThreadId`, and `CommitSha`.
- Standalone package candidate result: no selected-facade imports found under
  `agent-workflow-core`, `agent-workflow-codex`, or
  `agent-workflow-github`; `agent-workflow-codex.cabal` exposes
  `CodexWatcher.Workflow.Agent.Ids`, and `agent-workflow-github.cabal` exposes
  `CodexWatcher.Workflow.GitHub.Ids`.

Current exact import references:

- `src`: 31 imports.
- `app`: 1 import.
- `test`: 12 imports.
- Package descriptors: `moifold.cabal:46` is `public exposure`.
- Docs and policy references:
  `docs/agentic-workflow-framework/release-candidate-bundle.md`,
  `docs/agentic-workflow-framework/release-notes.md`, and
  `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`.
  These are `documentation/policy reference`.

Symbol-domain classification from the current scan:

- Corrected exact-token totals: 3 GitHub-only candidates, 2 agent-only
  candidates, and 39 combined users that need later split-import evidence.
- `safe direct-owner candidate` because only GitHub ids were observed:
  - `app/Main.hs`: `RepoName`.
  - `src/CodexWatcher/Core/State.hs`: `CommitSha`, `PrNumber`.
  - `test/BoundaryPolicySpec.hs`: `BranchName`, `IssueNumber`, `PrNumber`,
    `RepoName`, `ReviewThreadId`.
- `safe direct-owner candidate` because only agent ids were observed:
  - `src/CodexWatcher/Workflow/Execution.hs`: `RequestId`.
  - `test/WorkflowDocsMigrationSpec.hs`: `ThreadId`, `TurnId`.
- `blocked/needs later evidence` because both agent ids and GitHub ids were
  observed in the same importing file:
  - `src/CodexWatcher/Cli/Command/IssueFanout.hs`
  - `src/CodexWatcher/Cli/Command/RunnerGuard.hs`
  - `src/CodexWatcher/Cli/Parser/Common.hs`
  - `src/CodexWatcher/Cli/Parser/Observe.hs`
  - `src/CodexWatcher/Cli/RuntimeConfig.hs`
  - `src/CodexWatcher/Cli/Types.hs`
  - `src/CodexWatcher/DaemonLoop/Types.hs`
  - `src/CodexWatcher/Domain/IssueImplement/Loop.hs`
  - `src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`
  - `src/CodexWatcher/Domain/IssueImplement/Watcher.hs`
  - `src/CodexWatcher/Domain/IssuePlanning/Fanout.hs`
  - `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`
  - `src/CodexWatcher/Domain/IssuePlanning/Watcher.hs`
  - `src/CodexWatcher/Domain/PrReview/LaunchCli.hs`
  - `src/CodexWatcher/Domain/PrReview/Loop.hs`
  - `src/CodexWatcher/Domain/PrReview/Protocol.hs`
  - `src/CodexWatcher/Domain/PrReview/Watcher.hs`
  - `src/CodexWatcher/EffectInterpreter.hs`
  - `src/CodexWatcher/Effects.hs`
  - `src/CodexWatcher/EventLog/Replay.hs`
  - `src/CodexWatcher/EventLog/Types.hs`
  - `src/CodexWatcher/EventLogRepair.hs`
  - `src/CodexWatcher/GoldenReplay.hs`
  - `src/CodexWatcher/Healthcheck.hs`
  - `src/CodexWatcher/RunnerGuard.hs`
  - `src/CodexWatcher/Runtime/Compatibility.hs`
  - `src/CodexWatcher/StateMachine.hs`
  - `src/CodexWatcher/Workflow/Moifold/IssueImplement/Indexed.hs`
  - `src/CodexWatcher/Workflow/Moifold/PrReview.hs`
  - `test/CliSpec.hs`
  - `test/FacadeImportPolicySpec.hs`
  - `test/Main.hs`
  - `test/RuntimeCompatibilityFixtureSpec.hs`
  - `test/RuntimeSpec.hs`
  - `test/TestSupport/Workflow.hs`
  - `test/WorkflowAgentSpec.hs`
  - `test/WorkflowEventLogSpec.hs`
  - `test/WorkflowExecutionSpec.hs`
  - `test/WorkflowIndexedSpec.hs`

Next-slice blockers:

- Combined users need a later split-import slice that proves parser and
  renderer stability for repo names, branch names, commit SHAs, PR numbers,
  issue numbers, thread ids, turn ids, request ids, and review thread ids as
  applicable.
- Files that currently use both id domains should not be migrated mechanically
  without checking command rendering, event JSON, prompt text, runtime config,
  and test fixture expectations.

### `CodexWatcher.Workflow.EventLog`

- Facade file: `src/CodexWatcher/Workflow/EventLog.hs`.
- Facade shape: mixed moifold bridge. It reexports generic event-log and audit
  helpers and defines concrete moifold wrappers:
  `initializeMoifoldWorkflow`, `applyMoifoldWorkflowEvent`, and
  `replayMoifoldWorkflowEvents`.
- Current Cabal exposure: `moifold.cabal:116`.
- Direct-owner replacement modules visible from source:
  - `CodexWatcher.Workflow.EventLog.Core`
  - `CodexWatcher.Workflow.EventLog.File.Core`
  - `CodexWatcher.Workflow.EventLog.Commit.Core`
  - `CodexWatcher.Workflow.Audit`
- Standalone package candidate result: no selected-facade imports found under
  `agent-workflow-core`, `agent-workflow-codex`, or
  `agent-workflow-github`; `agent-workflow-core.cabal` exposes the event-log
  core, file core, and commit core modules.

Current exact import references:

- `src/CodexWatcher/Workflow/DocsMigration.hs`: `safe direct-owner candidate`
  for generic fixture/replay/audit helpers, but behavior still requires
  docs-migration replay and fixture validation before import convergence.
- `src/CodexWatcher/Daemon.hs`: `mixed/product-owned bridge`. It uses
  moifold daemon audit types and audit accessors through the facade while also
  importing direct audit and commit-core modules. A later slice needs exact
  daemon audit parity evidence before changing imports.
- `test` imports:
  - `test/FacadeImportPolicySpec.hs`
  - `test/Main.hs`
  - `test/TestSupport/Workflow.hs`
  - `test/WorkflowAgentSpec.hs`
  - `test/WorkflowDocsMigrationSpec.hs`
  - `test/WorkflowEventLogSpec.hs`
  - `test/WorkflowExecutionSpec.hs`
  - `test/WorkflowIndexedSpec.hs`
  These are `test-policy evidence`. The tests cover facade replay parity,
  moifold wrapper behavior, audit labels, fixture contracts, and indexed
  workflow compatibility evidence.
- Package descriptors: `moifold.cabal:116` is `public exposure`.
- Docs and policy references:
  `docs/agentic-workflow-framework/extraction-plan.md`,
  `docs/agentic-workflow-framework/release-notes.md`, and
  `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`.
  These are `documentation/policy reference`.

Next-slice blockers:

- Any convergence or public-surface work needs golden replay, event JSON
  `type` stability, old-log parsing, transition/replay parity, and concrete
  moifold wrapper behavior evidence.
- References that depend on `initializeMoifoldWorkflow`,
  `applyMoifoldWorkflowEvent`, or `replayMoifoldWorkflowEvents` remain
  product-owned bridge evidence until a later round proves a safe owner split.

### `CodexWatcher.Workflow.Permission`

- Facade file: `src/CodexWatcher/Workflow/Permission.hs`.
- Facade shape: mixed moifold bridge. It reexports reusable permission-core
  helpers and defines concrete moifold helpers such as
  `validateMoifoldEffectPlan`, `moifoldPermissionPolicy`, and
  `validateWorkflowEffectPlan`.
- Current Cabal exposure: `moifold.cabal:128`.
- Direct-owner replacement module visible from source:
  `CodexWatcher.Workflow.Permission.Core`.
- Standalone package candidate result: no selected-facade imports found under
  `agent-workflow-core`, `agent-workflow-codex`, or
  `agent-workflow-github`; `agent-workflow-core.cabal` exposes
  `CodexWatcher.Workflow.Permission.Core`.

Current exact import references:

- `src` imports: none found outside the facade file.
- `app` imports: none found.
- `test` imports:
  - `test/FacadeImportPolicySpec.hs`: `test-policy evidence` for facade
    parity with phase validation, core checks, and moifold permission policy.
  - `test/WorkflowDocsMigrationSpec.hs`: `test-policy evidence`; observed
    uses are reusable core validation for `DocsMigrationSpec`.
  - `test/WorkflowEventLogSpec.hs`: `test-policy evidence`; exact import
    remains in the test surface.
  - `test/WorkflowExecutionSpec.hs`: `test-policy evidence` for moifold
    effect-plan validation and core validation parity.
  - `test/WorkflowIndexedSpec.hs`: `test-policy evidence`; observed use is
    reusable core validation inside indexed compatibility checks.
  - `test/WorkflowAgentSpec.hs`: `test-policy evidence`; exact import
    remains in the workflow test surface.
  - `test/TestSupport/Workflow.hs`: `test-policy evidence`; exact import
    remains in shared workflow test support.
- Package descriptors: `moifold.cabal:128` is `public exposure`.
- Docs and policy references:
  `docs/agentic-workflow-framework/extraction-plan.md`,
  `docs/agentic-workflow-framework/release-notes.md`, and
  `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`.
  These are `documentation/policy reference`.

Next-slice blockers:

- Any convergence or public-surface work needs permission soundness,
  phase-validation errors, state/effect validation, concrete `MoifoldSpec`
  behavior, public API evidence, and downstream-user evidence.
- Tests that use only `validateWorkflowEffectPlanCore` may be later
  direct-owner candidates, but this round does not edit test imports or approve
  facade cleanup.

## Prior Evidence Comparison

- `orchestrator/rounds/round-083/cleanup-inventory.md` is useful history, but
  this artifact uses current scans rather than copying stale counts.
- `round-083` recorded 12 `src` imports for `AppServerClient`; current scan
  still finds 12 `src` imports and now records 7 `test` imports after the test
  split.
- `round-083` recorded 29 `src` imports for `Core.Ids`; current scan finds 31
  `src` imports, 1 `app` import, and 12 `test` imports.
- `round-083` recorded 2 `src` imports and `test/Main.hs` for
  `Workflow.EventLog`; current scan still finds 2 `src` imports and now records
  8 `test` imports across the split workflow tests and support module.
- `round-083` recorded no production imports and `test/Main.hs` for
  `Workflow.Permission`; current scan still finds no production imports and now
  records 7 `test` imports across the split workflow tests and support module.
- `orchestrator/rounds/round-085/implementation-notes.md` explains why the
  split facade/import-policy tests are now distributed across focused test
  modules. This inventory treats those test imports as evidence, not as cleanup
  approval.

## Blockers And Next-Slice Notes

- `AppServerClient`: later import convergence should be sliced around
  app-server client parsing versus endpoint transport/session use, with
  endpoint parsing, protocol, session handling, command rendering, fallback,
  timeout, and failure-formatting checks for each touched source path.
- `Core.Ids`: later import convergence should start with single-domain users
  before combined users. Combined users need parser/renderer and output
  stability checks for every id type they render, parse, or serialize.
- `Workflow.EventLog`: later work should separate generic event-log/audit uses
  from moifold wrapper uses and should not touch public exposure until golden
  replay, old-log parsing, event JSON `type`, transition/replay parity, and
  wrapper behavior evidence is reviewed.
- `Workflow.Permission`: later work should separate reusable
  `Permission.Core` tests from concrete moifold policy helpers and should not
  touch public exposure until permission soundness, phase-validation,
  state/effect validation, public API, and downstream evidence is reviewed.
- Docs that describe preferred imports or deferred compatibility status remain
  policy references only. They do not authorize deprecation, import migration,
  Cabal exposure changes, facade removal, release approval, or milestone
  completion.

## Artifact-Only Verification

This round writes only:

- `orchestrator/rounds/round-097/facade-import-scan-refresh.md`
- `orchestrator/rounds/round-097/implementation-notes.md`

Package build/test baselines may be skipped because no production code, test
code, package descriptor, docs, fixture, runtime compatibility file, public
API, roadmap file, controller state, or behavior surface is changed by this
round. Verification details and command summaries are recorded in
`orchestrator/rounds/round-097/implementation-notes.md`.
