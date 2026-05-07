### Goal
Port `CodexWatcher.Workflow.DocsMigration` to the indexed workflow API as the first real DocsMigration proof, while preserving the current public DocsMigration compatibility facade, event JSON codec, fixture replay, permission checks, dry-run reports, daemon tick result shape, and effect/action ordering.

### Approach
Keep this as a sequential, single-owner change. The round touches one concrete workflow and its tests, and the behavior being preserved crosses the same source module and test assertions; worker fan-out would create integration risk without non-overlapping ownership.

`agent-workflow-core` continues to own the generic indexed contract in `CodexWatcher.Workflow.Indexed.Spec`. Do not move or reshape that API in this round. The `moifold` package continues to own `DocsMigrationSpec`, the DocsMigration state/event/observation/effect/action/result types, event codec, replay fixture, execution helpers, and daemon result projection in `src/CodexWatcher/Workflow/DocsMigration.hs`.

Add a DocsMigration indexed adapter beside the existing `WorkflowSpec DocsMigrationSpec` instance, not a replacement public workflow. The existing `WorkflowSpec` methods remain the compatibility facade used by current tests and daemon helpers. Indexed code must unwrap to the same `DocsMigrationEvent`, `DocsMigrationState`, `[DocsMigrationEffect]`, `DocsMigrationReplayResult`, and `DocsMigrationDaemonTickResult` values, so the event schema, fixture data, golden logs, dry-run output, daemon record fields, and action order remain unchanged.

### Steps
1. In `src/CodexWatcher/Workflow/DocsMigration.hs`, import `CodexWatcher.Workflow.Indexed.Spec` qualified and enable only the language extensions needed for a DocsMigration indexed instance.
2. Define DocsMigration index marker types for the existing phases: uninitialized, ready, turn-active, draft-ready, validated, complete, and blocked. Keep them internal unless tests need exported constructors; prefer exporting only small projection helpers if test access is needed.
3. Add indexed wrapper types owned by `DocsMigration`: indexed state, indexed event, indexed observation, indexed observed tick, indexed effect, indexed effect plan, and indexed replay result. These wrappers should carry the existing concrete DocsMigration values and source/target labels derived from the current `docsMigrationStateLabel`, `docsMigrationEventLabel`, `docsMigrationObservationLabel`, and `docsMigrationEffectLabel` helpers.
4. Implement `IndexedWorkflowSpec DocsMigrationSpec` by delegating to the existing DocsMigration behavior:
   - `indexedWorkflowInitialEvent` and `indexedWorkflowApplyEvent` must call the same initialization/apply logic used by `WorkflowSpec`.
   - `indexedWorkflowObserve` must call the same observation logic and preserve the observed event, next state, and effect list.
   - `indexedWorkflowObservedTransition` and `indexedWorkflowPlanTransition` must preserve the current post-commit partitioning from `docsMigrationPlannedTransitionFromEffects`.
   - `indexedWorkflowReplayEvents` must replay the unwrapped events through the current DocsMigration replay path and return a replay result with the same final state and effect history.
   - `indexedWorkflowValidateEffects`, `indexedWorkflowEffectAllowed`, `indexedWorkflowEffectPlanEffects`, `indexedWorkflowIsTerminal`, and label methods must delegate to the current DocsMigration permission and label functions.
5. Keep `docsMigrationEventCodecContract`, `encodeDocsMigrationEvent`, `parseDocsMigrationEvent`, `docsMigrationEventLogFixture`, and `docsMigrationEventLogFixtureContract` byte-for-byte compatible in behavior. Do not change event type strings, schema version, metadata labels, field names, fixture event order, or fixture expected state/count.
6. Keep `compileDocsMigrationEffectPlan`, `dryRunDocsMigrationCompiledEffectPlan`, `executeDocsMigrationCompiledEffectPlan`, `runDocsMigrationObservedDryRun`, `runDocsMigrationObservedExecute`, `docsMigrationDaemonTickResult`, and `docsMigrationDaemonCoreTickResult` result shapes and ordering intact. In particular, `WriteDocsMigrationDraft` must remain before `RunDocsMigrationValidation`, all DocsMigration effects remain post-commit under current metadata, dry-run must not commit events or execute actions, and execute mode must still commit the observed event before post-commit action reports.
7. In `test/Main.hs`, add focused DocsMigration indexed parity assertions to the existing workflow facade extraction group:
   - `workflowDocsMigrationIndexedSpecMatchesCompatibilityForDraft`: from `DocsMigrationTurnActive`, compare compatibility `workflowObserve`/`workflowPlanObservation` with indexed observe/plan for an agent-complete draft. Assert the same event `DocsMigrationDraftProduced`, next state label `draft-ready`, no pre-commit effects, post-commit effects `[WriteDocsMigrationDraft, RunDocsMigrationValidation]`, effect labels, and replay result/effect history.
   - `workflowDocsMigrationIndexedSpecMatchesCompatibilityForValidationAndBlocked`: cover validation success and one blocked nonterminal path so `StopDocsMigrationDaemon` remains the same post-commit effect and terminal labels remain `validated`/`blocked`.
   - `workflowDocsMigrationIndexedSpecPreservesPermissionsAndFixtureCodec`: compare indexed validation/effect-allowed results with the current `WorkflowSpec` and `WorkflowPermission.validateWorkflowEffectPlanCore` for allowed, partial, wrong-target, and disallowed-state plans; also assert the existing fixture still round-trips through `docsMigrationEventCodecContract` and validates through `docsMigrationEventLogFixtureContract`.
   - `workflowDocsMigrationIndexedDryRunAndDaemonParity`: assert the existing dry-run and execute helpers still produce the same event, state, compiled actions, action reports, committed events, audit committed-event label, and action order while the indexed plan for the same observation exposes the same post-commit effects.
8. Keep the existing DocsMigration tests in place, especially `workflowDocsMigrationFacadeLawPreservesObservationReplayEffectsAndPermissions`, `workflowDocsMigrationSpecProvesSecondWorkflow`, `workflowDocsMigrationPermissionAndPartitionContracts`, `workflowDocsMigrationEventCodecFixtureContract`, `workflowDocsMigrationUsesCoreExecutionContracts`, and `workflowDaemonCoreProjectsMoifoldAndDocsMigrationResults`.
9. Before review, inspect the diff and confirm there are no changes to `CodexWatcher.EventLog.Types`, golden fixture files, event type labels, JSON field names, daemon result record fields, dry-run rendering/report fields, runtime command rendering, action ordering logic, roadmap files, `orchestrator/state.json`, implementation notes, review files, or merge files.

### Verification
Run the exact baseline commands from `orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-001/verification.md`:

- `cabal build all`
- `cabal test watcher-core-test`
- `git diff --check`
- `git diff --cached --check`

Focused DocsMigration indexed parity checks are the new `watcher-core-test` assertions named in Step 7. The test evidence should show that old and indexed DocsMigration paths emit the same event, next state label, effect plan, replay result, fixture codec behavior, permission decisions, dry-run output, daemon result shape, and action ordering for the ported DocsMigration slice.
