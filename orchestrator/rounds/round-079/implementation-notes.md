### Changes Made
- `orchestrator/rounds/round-079/implementation-notes.md`: recorded the evidence-only readiness decision for `CodexWatcher.Workflow.EventLog` and `CodexWatcher.Workflow.Permission` under roadmap `2026-05-10-00-facade-removal-readiness`, revision `rev-001`, extracted item `round-079-eventlog-permission-readiness-hold`.

No production source, tests, package descriptors, docs, roadmaps, `orchestrator/state.json`, runtime compatibility files, event schemas, replay behavior, permission or phase-validation behavior, healthcheck, repair, public API, deprecation pragmas, Cabal exposure, facade removal, import migration, or `worker-plan.json` were changed.

### Tests
- No tests were added or changed because this round is artifact-only evidence.
- `cabal test watcher-core-test` was not run because the only write was this round-local artifact and no source/test behavior changed. The focused evidence commands below refresh the current import, exposure, and protecting-test inventory required by the plan.

### Notes

#### Active Input Confirmation
- Active worktree: `/Users/ares/src/codex-feishu-bot/.codex-local/workspace/artifacts/codex-watcher-hs/orchestrator/worktrees/round-079`.
- `git status --short --branch` confirmed branch `orchestrator/round-079-eventlog-permission-readiness` with only the untracked round artifact directory before this file was written.
- `orchestrator/state.json` confirms active round `round-079`, stage `implement`, branch `orchestrator/round-079-eventlog-permission-readiness`, roadmap id `2026-05-10-00-facade-removal-readiness`, revision `rev-001`, roadmap dir `orchestrator/roadmaps/2026-05-10-00-facade-removal-readiness/rev-001`, and extracted item `round-079-eventlog-permission-readiness-hold`.
- `orchestrator/project-contract.md` requires public compatibility facades to stay available until safe removal is proven with import, build, and behavior coverage; the prior `2026-05-09-01-compatibility-surface-cleanup` terminal hold is not deprecation, migration, Cabal exposure, or removal approval.
- The active verification bundle keeps this round focused on `CodexWatcher.Workflow.EventLog` and `CodexWatcher.Workflow.Permission`, and keeps `CodexWatcher.Workflow.Types`, `CodexWatcher.Workflow.Execution`, runtime compatibility files, event JSON `type` values, healthcheck, repair, and release/publication decisions out of scope.

#### Commands Run
- `git status --short --branch`
- `sed -n '1,220p' orchestrator/roles/implementer.md`
- `sed -n '1,260p' orchestrator/state.json`
- `sed -n '1,260p' orchestrator/project-contract.md`
- `sed -n '1,260p' orchestrator/roadmaps/2026-05-10-00-facade-removal-readiness/rev-001/verification.md`
- `sed -n '1,260p' orchestrator/roadmaps/2026-05-10-00-facade-removal-readiness/rev-001/retry-subloop.md`
- `sed -n '1,260p' orchestrator/rounds/round-079/selection.md`
- `sed -n '1,320p' orchestrator/rounds/round-079/plan.md`
- `rg -n "^ *import +(qualified +)?CodexWatcher\\.Workflow\\.(EventLog|Permission)(\\b| +as +| *$)" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
- `rg -n "^ *import +(qualified +)?CodexWatcher\\.Workflow\\.EventLog\\.(Core|File\\.Core|Commit\\.Core)(\\b| +as +| *$)" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
- `rg -n "^ *import +(qualified +)?CodexWatcher\\.Workflow\\.Permission\\.Core(\\b| +as +| *$)" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
- `rg -n "CodexWatcher\\.Workflow\\.(EventLog|Permission)(\\b|$)|CodexWatcher\\.Workflow\\.EventLog\\.(Core|File\\.Core|Commit\\.Core)|CodexWatcher\\.Workflow\\.Permission\\.Core" moifold.cabal agent-workflow-core/agent-workflow-core.cabal agent-workflow-codex/agent-workflow-codex.cabal agent-workflow-github/agent-workflow-github.cabal examples/workflow-package-consumer/workflow-package-consumer.cabal`
- `rg -n "workflowEventLog|workflow event-log|workflowPermission|workflow permission|phaseActionValidation|phase action|goldenEventLog|golden event|eventLogRepair|replayEventLog" test/Main.hs test/*Spec.hs`
- `sed -n '1,220p' src/CodexWatcher/Workflow/EventLog.hs`
- `sed -n '1,180p' src/CodexWatcher/Workflow/Permission.hs`
- `sed -n '1,260p' agent-workflow-core/src/CodexWatcher/Workflow/EventLog/Core.hs`
- `sed -n '1,220p' agent-workflow-core/src/CodexWatcher/Workflow/EventLog/File/Core.hs`
- `sed -n '1,220p' agent-workflow-core/src/CodexWatcher/Workflow/EventLog/Commit/Core.hs`
- `sed -n '1,220p' agent-workflow-core/src/CodexWatcher/Workflow/Permission/Core.hs`
- `sed -n '6880,6920p' test/Main.hs`
- `sed -n '8120,8345p' test/Main.hs`
- Additional narrowing reads: exact selected-facade import scan, Cabal exposure slices, `sed -n '8540,8650p' test/Main.hs`, and focused use-site scans for `WorkflowEventLog` / `WorkflowPermission` references.
- Verification commands after writing this artifact:
  - `test -f orchestrator/rounds/round-079/implementation-notes.md`
  - `test ! -e orchestrator/rounds/round-079/worker-plan.json`
  - `git diff -- orchestrator/rounds/round-079/plan.md orchestrator/rounds/round-079/implementation-notes.md`
  - `git diff --name-only`
  - `git diff --check`
  - repeated focused import/Cabal/test inventory `rg` commands listed above
  - `git status --short -uall`
  - `git diff --no-index --check -- /dev/null orchestrator/rounds/round-079/implementation-notes.md`

#### Verification Results
- `test -f orchestrator/rounds/round-079/implementation-notes.md`: passed.
- `test ! -e orchestrator/rounds/round-079/worker-plan.json`: passed.
- `git diff -- orchestrator/rounds/round-079/plan.md orchestrator/rounds/round-079/implementation-notes.md`: no output because the round artifact directory is untracked.
- `git diff --name-only`: no output because the round artifact directory is untracked.
- `git diff --check`: passed with no output for tracked diff.
- `git diff --no-index --check -- /dev/null orchestrator/rounds/round-079/implementation-notes.md`: passed with no whitespace errors for the new artifact.
- `git status --short -uall`: showed untracked `orchestrator/rounds/round-079/plan.md`, `orchestrator/rounds/round-079/selection.md`, and `orchestrator/rounds/round-079/implementation-notes.md`. Only `implementation-notes.md` was written by this implementation pass.

#### Readiness Decisions

| Surface | Decision | Current evidence | Future evidence required |
| --- | --- | --- | --- |
| `CodexWatcher.Workflow.EventLog` | hold | Mixed surface. The module reexports reusable replay/audit helpers but still owns concrete moifold bridge helpers over `WatcherEvent`, `SomeWatcherState`, `EffectPlan`, and `MoifoldSpec`. It remains exposed by `moifold.cabal`. | A reviewed split plan for moifold bridge helpers, old-log/golden replay proof, event schema/type-field stability, downstream/public API inventory, and Cabal exposure policy before any migration, deprecation, or removal. |
| `CodexWatcher.Workflow.Permission` | hold | Mixed surface. The module reexports reusable permission core but still exposes concrete phase-action validation through `validateMoifoldEffectPlan`, `moifoldPermissionPolicy`, `validateWorkflowEffectPlan`, `PhaseActionValidationError`, and `formatPhaseActionValidationError`. It remains exposed by `moifold.cabal`. | A reviewed split plan for phase-validation/public API ownership, permission parity proof, downstream/public API inventory, and Cabal exposure policy before any migration, deprecation, or removal. |

#### Import Inventory
- Selected facade imports, exact scan:
  - `CodexWatcher.Workflow.EventLog`: 3 direct importers.
    - `test/Main.hs:79`: qualified facade import used by event-log, daemon audit, DocsMigration, transaction, and workflow law tests.
    - `src/CodexWatcher/Daemon.hs:54`: qualified facade import used for daemon audit type aliases and audit field accessors.
    - `src/CodexWatcher/Workflow/DocsMigration.hs:71`: explicit import of event-log replay/audit names used by the DocsMigration workflow bridge.
  - `CodexWatcher.Workflow.Permission`: 1 direct importer.
    - `test/Main.hs:179`: qualified facade import used by permission facade/core parity tests and later Moifold/DocsMigration permission-law tests.
- Direct replacement imports:
  - `CodexWatcher.Workflow.EventLog.Commit.Core`: 3 direct importers in `test/Main.hs`, `src/CodexWatcher/Daemon.hs`, and `src/CodexWatcher/Workflow/DocsMigration.hs`.
  - `CodexWatcher.Workflow.EventLog.File.Core`: 2 direct importers in `test/Main.hs` and `src/CodexWatcher/EventLog/File.hs`.
  - `CodexWatcher.Workflow.EventLog.Core`: 2 direct importers in `agent-workflow-core/src/CodexWatcher/Workflow/Audit.hs` and `src/CodexWatcher/Workflow/EventLog.hs`.
  - `CodexWatcher.Workflow.Permission.Core`: 1 direct importer in `src/CodexWatcher/Workflow/Permission.hs`.
- The broader plan regex also reports submodule imports because `EventLog` is followed by a dot boundary; the exact selected-facade counts above separate facade imports from replacement-module imports.

#### Cabal Exposure Evidence
- `moifold.cabal` exposes both selected facades:
  - `CodexWatcher.Workflow.EventLog` at the library exposed-module list.
  - `CodexWatcher.Workflow.Permission` at the library exposed-module list.
- `agent-workflow-core/agent-workflow-core.cabal` exposes the reusable replacement modules:
  - `CodexWatcher.Workflow.EventLog.Commit.Core`
  - `CodexWatcher.Workflow.EventLog.Core`
  - `CodexWatcher.Workflow.EventLog.File.Core`
  - `CodexWatcher.Workflow.Permission.Core`
- No selected facade is exposed by `agent-workflow-core`, `agent-workflow-codex`, `agent-workflow-github`, or the example workflow package consumer.
- Any future migration that changes public imports or removes these moifold facades would need package descriptor and public API review. This round does not approve those changes.

#### Facade Definition Evidence
- `src/CodexWatcher/Workflow/EventLog.hs` exports reusable names from `CodexWatcher.Workflow.EventLog.Core` and audit helpers from `CodexWatcher.Workflow.Audit`, then locally defines:
  - `initializeMoifoldWorkflow :: WatcherEvent -> Either Text (SomeWatcherState, EffectPlan)`
  - `applyMoifoldWorkflowEvent :: SomeWatcherState -> WatcherEvent -> Either Text (SomeWatcherState, EffectPlan)`
  - `replayMoifoldWorkflowEvents :: [WatcherEvent] -> Either ReplayFailure EventReplayResult`
- Those bridge helpers specialize generic workflow APIs to `MoifoldSpec`, concrete `WatcherEvent`, concrete `SomeWatcherState`, concrete `EffectPlan`, and the existing moifold `replayEventLog` path. That is not a pure reexport.
- `agent-workflow-core/src/CodexWatcher/Workflow/EventLog/Core.hs` owns generic replay summaries, transition failures, fixture contracts, detailed replay, and transition formatting over any `WorkflowSpec`; it does not read files, execute effects, or own concrete event schemas.
- `agent-workflow-core/src/CodexWatcher/Workflow/EventLog/File/Core.hs` owns generic nonblank line numbering and decode-error formatting. Concrete file paths, fixture loading, repair, and old-log compatibility stay outside it.
- `agent-workflow-core/src/CodexWatcher/Workflow/EventLog/Commit/Core.hs` owns the generic commit boundary and encoded-event append helper. Concrete append targets, locking, backups, and event-log file naming stay outside it.
- `src/CodexWatcher/Workflow/Permission.hs` exports reusable names from `CodexWatcher.Workflow.Permission.Core`, but also imports `CodexWatcher.StateMachine` and locally defines:
  - `validateMoifoldEffectPlan :: SomeWatcherState -> EffectPlan -> Either PhaseActionValidationError ()`
  - `moifoldPermissionPolicy :: WorkflowPermissionPolicy MoifoldSpec`
  - `validateWorkflowEffectPlan :: WorkflowSpec spec => WorkflowState spec -> WorkflowEffectPlan spec -> Either (WorkflowError spec) ()`
- It also reexports `PhaseActionValidationError` and `formatPhaseActionValidationError` from the concrete moifold state-machine validation surface. That keeps the facade tied to phase validation and public compatibility, not just generic permission core.
- `agent-workflow-core/src/CodexWatcher/Workflow/Permission/Core.hs` owns reusable `WorkflowPermissionPolicy`, per-effect permission checks, generic validation errors, core validation, and formatting over any `WorkflowSpec`.

#### Protecting Test Inventory
- Event-log/golden/replay protection from the focused scan:
  - `goldenEventLogTypeFieldsMatchDecodedEvents` and `goldenEventLogCases` protect current golden event type fields and replayed fixture contracts.
  - `prop_eventLogRepairIssue26MissingPlanReentersImplementation`, `prop_eventLogRepairDropsCompletionWithoutImplementationTurn`, `prop_eventLogRepairDropsStalePlanningReadyIssuesFixed`, and `prop_eventLogRepairRejectsValidEventLog` protect repair/replay behavior around legacy logs.
  - `workflowEventLogCommitCoreEncodesAndAppendsBeforeSuccess` protects commit-order behavior for encoded event appends.
  - `workflowEventLogFileCoreNumberingIgnoresBlankLines`, `workflowEventLogFileCoreDecodeFailureReportsSourceLine`, `workflowEventLogFileWrapperDecodesExistingFixtures`, and `workflowEventLogFileWrapperFormatsMalformedErrors` protect line numbering, malformed-line formatting, and current fixture decoding.
  - `workflowEventLogCoreDetailedReplayMatchesMoifold`, `workflowEventLogCoreFixtureContractValidatesReplay`, and `workflowEventLogCoreTransitionContractsMatchFacades` protect detailed replay parity, fixture contracts, transition labels, and Moifold facade/core parity.
  - Additional focused uses in `test/Main.hs` cover daemon audit labels, DocsMigration detailed replay, fixture contracts, transaction audit labels, and failure-audit retry recommendations.
- Permission/phase-validation protection from the focused scan:
  - `phaseActionValidationRejectsInvalidCombinations` and `phaseActionValidationAcceptsStateMachineDecisions` protect concrete moifold phase-action validation.
  - `workflowPermissionFacadeMatchesStateMachine` protects `validateMoifoldEffectPlan` parity with `validatePhaseActionPlan`.
  - `workflowPermissionCoreChecksMatchMoifoldPermission` protects generic core validation/check fields against moifold validation errors.
  - `workflowPermissionPolicyMatchesMoifoldPermission` protects the specialized `moifoldPermissionPolicy`.
  - Additional focused uses in `test/Main.hs` cover indexed PR-review permission parity, DocsMigration permission parity, and PR-review mergeability permission parity.

#### Final Hold Rationale
- `CodexWatcher.Workflow.EventLog` should remain held as a concrete moifold bridge for now. There are replacement modules for generic replay/file/commit pieces, but the selected facade still carries moifold-specific helper names, concrete event/state/effect types, replay compatibility, and Cabal exposure. The future candidate is to migrate only pure generic imports where a caller does not need moifold bridge helpers or public compatibility names, but that requires a separate reviewed migration round.
- `CodexWatcher.Workflow.Permission` should remain held as a concrete moifold bridge for now. There is a replacement module for generic permission policy/check behavior, but the selected facade still carries concrete phase-validation names and state-machine error types, and its only direct import currently appears in tests that protect facade/core/moifold parity. A future candidate is to import `Permission.Core` directly for purely generic `WorkflowSpec` tests or code, but not to remove or deprecate the facade without public API and phase-validation evidence.
- Local import counts are not removal evidence. The closed `2026-05-09-01-compatibility-surface-cleanup` terminal hold is not deprecation, migration, Cabal exposure, or removal approval.
