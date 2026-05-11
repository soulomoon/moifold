## Scope

Round: `round-104`

Roadmap lineage: `2026-05-11-00-highest-value-cleanup`, `rev-001`

Milestone: `milestone-003-import-convergence-package-boundaries`

Direction: `direction-012-eventlog-permission-bridge-split-readiness`

Selected extraction:
`round-104-eventlog-permission-bridge-split-readiness`

This is an artifact-only readiness inventory for the mixed
`CodexWatcher.Workflow.EventLog` and `CodexWatcher.Workflow.Permission`
compatibility facades. It records current live imports, public/package
exposure, export-list shape, per-importer classification, and later
verification gates before any import convergence, public exposure change, Cabal
exposure change, deprecation, or facade removal.

Non-goals: no source, test, app, package descriptor, fixture, docs, roadmap,
controller-state, public API, event schema, golden-log, permission, replay,
audit, runtime compatibility, healthcheck, repair, command-output, prompt,
behavior, public exposure, release, milestone-completion, or terminal-completion
change. Both compatibility facades remain available and exposed.

## Inputs Reviewed

- `orchestrator/state.json`
- `orchestrator/rounds/round-104/selection.md`
- `orchestrator/rounds/round-104/plan.md`
- `orchestrator/project-contract.md`
- `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`
- `orchestrator/rounds/round-097/facade-import-scan-refresh.md`
- `orchestrator/rounds/round-103/core-ids-remaining-blocker-readiness.md`
- `orchestrator/rounds/round-103/implementation-notes.md`
- `orchestrator/rounds/round-103/review.md`
- `src/CodexWatcher/Workflow/EventLog.hs`
- `src/CodexWatcher/Workflow/Permission.hs`

Round-103 context confirms direction 011's current `Core.Ids` single-domain
queue is closed and recommends moving later work to split-import or
bridge-readiness slices. That supports this round's direction-012 evidence
scope without implying any facade removal approval.

## Commands Run

Starting scope:

```sh
git status --short
git diff --name-status
git ls-files --others --exclude-standard orchestrator/rounds/round-104
```

Result: before this implementation the worktree already showed
controller-owned `M orchestrator/state.json` and untracked round-104
plan/selection artifacts:

```text
 M orchestrator/state.json
?? orchestrator/rounds/round-104/
M	orchestrator/state.json
orchestrator/rounds/round-104/plan.md
orchestrator/rounds/round-104/selection.md
```

Current exact facade import scan:

```sh
rg -n '^import[[:space:]]+(qualified[[:space:]]+)?CodexWatcher\.Workflow\.(EventLog|Permission)([[:space:]]|$|\()' \
  src app test agent-workflow-core agent-workflow-codex agent-workflow-github
```

Result: matched expected selected shape. The live scan found 17 import lines:
2 under `src`, 15 under `test`, and none under `app`,
`agent-workflow-core`, `agent-workflow-codex`, or
`agent-workflow-github`.

Current exact count command:

```sh
rg -n '^import[[:space:]]+(qualified[[:space:]]+)?CodexWatcher\.Workflow\.(EventLog|Permission)([[:space:]]|$|\()' \
  src app test agent-workflow-core agent-workflow-codex agent-workflow-github \
  | awk -F: '{area=$1; sub("/.*", "", area); mod=$0 ~ /Workflow\.EventLog/ ? "EventLog" : "Permission"; count[area,mod]++; files[$1]=files[$1] " " mod} END {for (k in count) print k, count[k]; print "files"; for (f in files) print f":"files[f]}'
```

Result:

```text
src/EventLog 2
test/EventLog 8
test/Permission 7
```

Broader reference scan:

```sh
rg -n 'CodexWatcher\.Workflow\.(EventLog|Permission)([[:space:]]|$|\.|\(|")' \
  src app test agent-workflow-core agent-workflow-codex agent-workflow-github \
  docs examples scripts moifold.cabal agent-workflow-core/agent-workflow-core.cabal \
  agent-workflow-codex/agent-workflow-codex.cabal \
  agent-workflow-github/agent-workflow-github.cabal cabal.project
```

Result: matched expected shape. Matches classify as:

- Live imports in `src` and `test`, listed below.
- Main-package public exposure in `moifold.cabal:116` and
  `moifold.cabal:128`.
- Package-candidate direct-owner exposure in
  `agent-workflow-core/agent-workflow-core.cabal:51-53` and
  `agent-workflow-core/agent-workflow-core.cabal:57`.
- Direct-owner package source modules under `agent-workflow-core/src`.
- Test import-policy assertions in `test/BoundaryPolicySpec.hs`.
- Documentation/policy references under `docs/agentic-workflow-framework` and
  `agent-workflow-core/README.md`.
- No matches under `examples`, `scripts`, `app`,
  `agent-workflow-codex`, or `agent-workflow-github`.

Direct-owner and bridge-module exposure scan:

```sh
rg -n 'CodexWatcher\.Workflow\.(Audit|EventLog\.(Core|File\.Core|Commit\.Core)|Permission\.Core)|CodexWatcher\.Workflow\.(EventLog|Permission)|exposed-modules:' \
  src app test agent-workflow-core agent-workflow-codex agent-workflow-github \
  moifold.cabal agent-workflow-core/agent-workflow-core.cabal \
  agent-workflow-codex/agent-workflow-codex.cabal \
  agent-workflow-github/agent-workflow-github.cabal cabal.project
```

Result: `moifold.cabal` still exposes `CodexWatcher.Workflow.EventLog` and
`CodexWatcher.Workflow.Permission`; `agent-workflow-core` exposes the reusable
owner modules `CodexWatcher.Workflow.Audit`,
`CodexWatcher.Workflow.EventLog.Commit.Core`,
`CodexWatcher.Workflow.EventLog.Core`,
`CodexWatcher.Workflow.EventLog.File.Core`, and
`CodexWatcher.Workflow.Permission.Core`. The standalone packages did not import
the selected compatibility facades.

## Exact Import Counts

| Area | EventLog imports | Permission imports | Files |
| --- | ---: | ---: | ---: |
| `src` | 2 | 0 | 2 |
| `app` | 0 | 0 | 0 |
| `test` | 8 | 7 | 8 |
| `agent-workflow-core` | 0 | 0 | 0 |
| `agent-workflow-codex` | 0 | 0 | 0 |
| `agent-workflow-github` | 0 | 0 | 0 |
| Total | 10 | 7 | 10 |

Current importing files:

| File | Facade imports |
| --- | --- |
| `src/CodexWatcher/Daemon.hs` | `EventLog` |
| `src/CodexWatcher/Workflow/DocsMigration.hs` | `EventLog` |
| `test/WorkflowDocsMigrationSpec.hs` | `EventLog`, `Permission` |
| `test/FacadeImportPolicySpec.hs` | `EventLog`, `Permission` |
| `test/WorkflowEventLogSpec.hs` | `EventLog`, `Permission` |
| `test/Main.hs` | `EventLog` |
| `test/WorkflowIndexedSpec.hs` | `EventLog`, `Permission` |
| `test/WorkflowAgentSpec.hs` | `EventLog`, `Permission` |
| `test/WorkflowExecutionSpec.hs` | `EventLog`, `Permission` |
| `test/TestSupport/Workflow.hs` | `EventLog`, `Permission` |

## Broader Reference Classification

- Live imports: the ten files above.
- Package exposure: `moifold.cabal` exposes
  `CodexWatcher.Workflow.EventLog` and `CodexWatcher.Workflow.Permission`.
- Package-candidate direct-owner exposure: `agent-workflow-core` exposes
  `CodexWatcher.Workflow.Audit`,
  `CodexWatcher.Workflow.EventLog.Commit.Core`,
  `CodexWatcher.Workflow.EventLog.Core`,
  `CodexWatcher.Workflow.EventLog.File.Core`, and
  `CodexWatcher.Workflow.Permission.Core`.
- Package-candidate import evidence: no selected-facade imports were found in
  `agent-workflow-core`, `agent-workflow-codex`, or
  `agent-workflow-github`; direct-owner imports are present inside
  `agent-workflow-core`.
- Test import-policy assertions: `test/BoundaryPolicySpec.hs` names the
  direct-owner modules and the selected compatibility facades as policy
  evidence.
- Documentation/policy references:
  `docs/agentic-workflow-framework/moifold-consumer-validation.md`,
  `docs/agentic-workflow-framework/extraction-plan.md`,
  `docs/agentic-workflow-framework/event-log-and-transactions.md`,
  `docs/agentic-workflow-framework/package-consumer-guide.md`,
  `docs/agentic-workflow-framework/implemented-api-freeze.md`,
  `docs/agentic-workflow-framework/workflow-spec.md`,
  `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`, and
  `docs/agentic-workflow-framework/monad-dsl.md`.

## Export-List Classification

### `CodexWatcher.Workflow.EventLog`

Reusable direct-owner core/audit exports:

- `EventLogFixtureContract (..)`
- `WorkflowReplayFailure (..)`
- `WorkflowReplaySummary (..)`
- `WorkflowNextDaemonRecommendation (..)`
- `WorkflowTickAudit`
- `WorkflowTransitionFailure (..)`
- `applyWorkflowEvent`
- `initializeWorkflowEvent`
- `replayWorkflowEventLog`
- `replayWorkflowEventLogDetailed`
- `formatWorkflowReplayFailure`
- `formatWorkflowTransitionFailure`
- `validateEventLogFixtureContract`
- `workflowAuditCommittedEventLabel`
- `workflowAuditFailureClassification`
- `workflowAuditFinalStateLabel`
- `workflowAuditNextDaemonRecommendation`
- `workflowAuditObservationLabel`
- `workflowAuditPostCommitReports`
- `workflowAuditPreCommitReports`
- `workflowAuditPriorStateLabel`
- `workflowDryRunAudit`
- `workflowFailureAudit`
- `workflowSuccessAudit`

Product-owned moifold wrapper exports:

- `applyMoifoldWorkflowEvent`
- `initializeMoifoldWorkflow`
- `replayMoifoldWorkflowEvents`

Mixed-export blocker: this facade combines reusable event-log/audit helpers
with concrete `MoifoldSpec` wrappers and main-package `WatcherEvent`,
`SomeWatcherState`, `EffectPlan`, and replay behavior. Mechanical import
convergence cannot move all users to one direct-owner module without separating
generic replay/audit uses from moifold bridge behavior.

### `CodexWatcher.Workflow.Permission`

Reusable direct-owner core exports:

- `WorkflowEffectPermissionCheck (..)`
- `WorkflowPermissionPolicy (..)`
- `WorkflowPermissionValidationError (..)`
- `formatWorkflowPermissionValidationError`
- `validateWorkflowEffectPlanCore`
- `validateWorkflowEffectPlanWithPolicy`
- `workflowEffectPermissionChecks`
- `workflowEffectPermissionChecksWithPolicy`
- `workflowSpecPermissionPolicy`

Concrete phase/state validation bridge exports:

- `PhaseActionValidationError (..)`
- `formatPhaseActionValidationError`
- `validateMoifoldEffectPlan`

Permission-policy helper exports:

- `moifoldPermissionPolicy`
- `validateWorkflowEffectPlan`

Mixed-export blocker: this facade combines spec-parametric permission-core
helpers with concrete `SomeWatcherState`, `EffectPlan`, phase-action validation,
and `MoifoldSpec` policy. Later work must preserve the boundary between
reusable permission-core checks and moifold phase/state policy.

## Per-Importer Classification

| File | Classification | Evidence |
| --- | --- | --- |
| `src/CodexWatcher/Daemon.hs` | direct-owner reusable audit candidate plus daemon/runtime bridge behavior | Uses `WorkflowTickAudit`, `workflowSuccessAudit`, and audit accessors for daemon observed audit reports. It already imports `Workflow.Audit` and `EventLog.Commit.Core`, but the facade import still carries audit aliases and labels across daemon runtime behavior. Later convergence needs focused daemon audit/transaction evidence. |
| `src/CodexWatcher/Workflow/DocsMigration.hs` | direct-owner reusable core/audit candidate plus DocsMigration replay behavior | Uses `WorkflowTickAudit`, replay detail, and audit report accessors for `DocsMigrationSpec`. It is not a moifold wrapper user, but it sits on workflow replay/audit behavior and needs DocsMigration replay parity before import movement. |
| `test/WorkflowDocsMigrationSpec.hs` | test-policy evidence: DocsMigration replay, fixture contract, permission soundness, audit behavior | Uses `replayWorkflowEventLogDetailed`, `validateEventLogFixtureContract`, replay failure fields, audit accessors, and `validateWorkflowEffectPlanCore @DocsMigrationSpec`. It preserves DocsMigration golden/replay and permission-core evidence. |
| `test/FacadeImportPolicySpec.hs` | public exposure/downstream evidence and wrapper behavior evidence | Explicitly checks `replayMoifoldWorkflowEvents` versus generic replay, `initializeMoifoldWorkflow`, `applyMoifoldWorkflowEvent`, `validateMoifoldEffectPlan`, core permission checks, `moifoldPermissionPolicy`, and policy-based validation. This file intentionally preserves facade and bridge coverage. |
| `test/WorkflowEventLogSpec.hs` | test-policy evidence: golden replay, fixture contract, event-log transition parity, wrapper behavior | Uses generic replay/detail helpers, fixture contract validation, generic `initializeWorkflowEvent` and `applyWorkflowEvent`, moifold wrapper initialize/apply parity, transition failure formatting, and audit helpers. |
| `test/Main.hs` | test-policy evidence: daemon audit behavior in broad watcher-core suite | Uses audit accessors and daemon recommendation constructors for dry-run, execute, and failure audit assertions. |
| `test/WorkflowIndexedSpec.hs` | test-policy evidence: indexed workflow audit, transition/replay parity, phase/effect validation | Uses audit accessors and daemon recommendation constructors across issue-planning and PR-review indexed flows, plus `validateWorkflowEffectPlanCore @MoifoldSpec` for wrong-phase/effect validation. |
| `test/WorkflowAgentSpec.hs` | test-policy evidence/import-topology hold | Imports both facades in the shared workflow spec topology alongside direct-owner event-log modules. No local qualified facade references were found in the live use-site scan, so later cleanup needs an import-policy-specific test pass rather than behavior migration. |
| `test/WorkflowExecutionSpec.hs` | test-policy evidence: permission soundness, phase-validation, daemon audit, transaction audit | Uses `validateMoifoldEffectPlan`, `validateWorkflowEffectPlanCore @MoifoldSpec`, audit accessors, failure classifications, daemon recommendations, and transaction audit labels. |
| `test/TestSupport/Workflow.hs` | test support/import-topology hold | Imports both facades in the shared test-support import set alongside direct-owner event-log modules. No local qualified facade references were found in the live use-site scan, so later work should first prove whether these imports are still needed by support exports, warning policy, or generated spec shape. |

No `app` importer is present. No standalone package candidate imports either
compatibility facade, so there is no current package-boundary blocker from live
standalone package source. The blocker remains public exposure, test policy,
and the mixed export shape of the main-library facades.

## Later Verification Gates

Before any later convergence, public exposure change, Cabal exposure change,
or removal work, run focused gates for the exact touched surface:

- Golden replay coverage for affected workflows and fixtures.
- Old-log parsing across current compatibility fixtures.
- Stable `WatcherEvent` JSON `type` fields and parse behavior.
- Transition/replay parity for initialized and applied workflow events.
- Moifold wrapper behavior for `initializeMoifoldWorkflow`,
  `applyMoifoldWorkflowEvent`, `replayMoifoldWorkflowEvents`,
  `validateMoifoldEffectPlan`, and `moifoldPermissionPolicy`.
- Permission soundness for allowed and denied effects.
- Phase-validation error behavior and formatting.
- State/effect validation behavior before interpretation.
- Public API, Cabal exposure, docs/Haddock, and downstream import evidence for
  the exact surface later moved, deprecated, hidden, or removed.

## Recommendation

Do not treat the presence of direct-owner modules as removal approval. The
current evidence supports later, narrowly scoped import-convergence slices:

- `src/CodexWatcher/Workflow/DocsMigration.hs` is the clearest source
  direct-owner candidate, but it still needs DocsMigration replay/audit
  behavior gates.
- `src/CodexWatcher/Daemon.hs` may be partially converged toward
  `Workflow.Audit` or direct-owner event-log modules, but daemon runtime audit
  behavior and transaction evidence must be verified first.
- `test/FacadeImportPolicySpec.hs`, `test/WorkflowEventLogSpec.hs`, and
  `test/WorkflowExecutionSpec.hs` are not mechanical cleanup candidates; they
  intentionally preserve wrapper, replay, permission, and phase-validation
  behavior evidence.
- `test/WorkflowAgentSpec.hs` and `test/TestSupport/Workflow.hs` look like
  import-topology holds from the live reference scan, but this round records
  evidence only and does not remove imports.

Both `CodexWatcher.Workflow.EventLog` and
`CodexWatcher.Workflow.Permission` should remain exposed and supported until a
later reviewed round satisfies the exact verification gates for a named
surface.

## Changed-Path Evidence

This implementation changed only round-local artifacts, aside from the
controller-owned `orchestrator/state.json` movement already present before
implementation.

Descriptor and changed-path checks were run:

```sh
git diff -- src app test moifold.cabal cabal.project \
  agent-workflow-core agent-workflow-codex agent-workflow-github
git diff -- moifold.cabal agent-workflow-core/agent-workflow-core.cabal \
  agent-workflow-codex/agent-workflow-codex.cabal \
  agent-workflow-github/agent-workflow-github.cabal cabal.project
```

Both commands produced no output. No production code, test code, app code,
package descriptor, standalone package source, fixture, docs, public API,
event schema, replay behavior, permission behavior, runtime behavior, or Cabal
exposure change was made by this round.

Final scope check:

```sh
git status --short
git diff --name-status
git ls-files --others --exclude-standard orchestrator/rounds/round-104
```

Result:

```text
 M orchestrator/state.json
?? orchestrator/rounds/round-104/
M	orchestrator/state.json
orchestrator/rounds/round-104/eventlog-permission-bridge-split-readiness.md
orchestrator/rounds/round-104/implementation-notes.md
orchestrator/rounds/round-104/plan.md
orchestrator/rounds/round-104/selection.md
```

Only the two owned implementation artifacts were added by this implementer.
The plan/selection artifacts and controller-owned state movement were present
before implementation and were left untouched.

`worker-plan.json` was not created.
