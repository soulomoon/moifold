### Goal

Extract the remaining workflow behavior test ownership out of `test/Main.hs`
into focused watcher-core test modules for
`round-086-workflow-behavior-test-split`, while preserving the same behavior
checks, assertion labels, failure detail, runner reachability, and
`watcher-core-test` aggregation.

This round completes the test-topology sequence after the round-084
`BoundaryPolicySpec` / `TestSupport.SourceScan` split and the round-085
`FacadeImportPolicySpec` split. It is test-only. It must not change production
code, docs, fixtures, runtime compatibility files, roadmap/state, source/app
import convergence, public deprecation/removal status, facade availability,
Cabal exposed modules, runtime compatibility-file names or semantics, large
runtime module decomposition, or behavior semantics. Reference
`orchestrator/project-contract.md` for the stable compatibility, package
boundary, fixture, event schema, and large-module extraction invariants.

### Approach

Keep the implementation sequential because all edits share the same
`test/Main.hs` runner and `watcher-core-test` Cabal stanza. Preserve
`workflowFacadeExtractionTests` as the high-level aggregate entry point in
`test/Main.hs`, but move the workflow behavior functions it currently owns into
focused modules under `test/`.

Proposed modules:

- `test/WorkflowEventLogSpec.hs`, exporting
  `workflowEventLogTests :: IO Bool`.
  Move the event-log and transition-contract behavior checks currently reached
  from `workflowFacadeExtractionTests`, including:
  `workflowEventCodecContractCoversWatcherEvents`,
  `workflowEventCodecToleratesMetadataAndPreservesGoldenTypes`,
  `workflowEventLogCommitCoreEncodesAndAppendsBeforeSuccess`,
  `workflowEventLogFileCoreNumberingIgnoresBlankLines`,
  `workflowEventLogFileCoreDecodeFailureReportsSourceLine`,
  `workflowEventLogFileWrapperDecodesExistingFixtures`,
  `workflowEventLogFileWrapperFormatsMalformedErrors`,
  `workflowEventLogCoreDetailedReplayMatchesMoifold`,
  `workflowEventLogCoreFixtureContractValidatesReplay`,
  `workflowEventLogCoreTransitionContractsMatchFacades`, and
  `workflowEventLogFailureAuditClassifiesRetryRecommendation`.
- `test/WorkflowAgentSpec.hs`, exporting
  `workflowAgentTests :: IO Bool`.
  Move the agent role, Codex adapter, observation-kernel, and PR-review facade
  behavior checks, including:
  `workflowExecutionFacadeDryRunMatchesExecutor`,
  `workflowPrReviewCheckingFacadeMatchesWatcher`,
  `workflowPrReviewMergeabilityFacadeMatchesWatcher`,
  `workflowAgentRoleWrapsPrReviewWorkerClassifier`,
  `workflowAgentRolesExposeRetryAndSideEffectMetadata`,
  `workflowAgentCodexStartRequestsMatchCompiledEffects`,
  `workflowAgentCodexStartsThreadsThroughTypedAdapter`,
  `workflowAgentCodexParsesTurnLifecycle`,
  `workflowPrReviewAgentRolesClassifyOutputs`,
  `workflowAgentObservationKernelMatchesPrReviewClassifiers`,
  `workflowPlanObservationLawHoldsForPrReviewAgentObservation`, and directly
  related local helpers such as `agentObservationPlanMatches` if they are not
  shared elsewhere.
- `test/WorkflowIndexedSpec.hs`, exporting
  `workflowIndexedTests :: IO Bool`.
  Move the indexed workflow behavior cluster and directly coupled indexed
  fixtures/helpers, including:
  `workflowIndexedSpecExistentialsPreserveLabels`,
  `workflowIssuePlanningIndexedSpec*`,
  `workflowIssuePlanningIndexedProjection*`,
  `workflowIssuePlanningIndexedDaemon*`,
  `workflowIssueImplementIndexedSpec*`,
  `workflowIssueImplementIndexedDaemon*`,
  `workflowPrReviewCheckingIndexedSpec*`,
  `workflowPrReviewWorkerIndexedSpec*`,
  `workflowPrReviewReviewerIndexedSpec*`,
  `workflowPrReviewMergeabilityIndexedSpec*`,
  `workflowPrReviewMergeabilityIndexedDaemon*`, and the associated indexed
  replay/projection helpers and case tables they require.
- `test/WorkflowDocsMigrationSpec.hs`, exporting
  `workflowDocsMigrationTests :: IO Bool`.
  Move the DocsMigration and second-workflow proof checks, including:
  `workflowDocsMigrationFacadeLawPreservesObservationReplayEffectsAndPermissions`,
  `workflowDocsMigrationIndexedLawMatchesUnindexedDraftReplayTerminalAndPermissions`,
  `workflowDocsMigrationIndexedSpecMatchesCompatibilityForDraft`,
  `workflowDocsMigrationIndexedSpecMatchesCompatibilityForValidationAndBlocked`,
  `workflowDocsMigrationIndexedSpecPreservesPermissionsAndFixtureCodec`,
  `workflowDocsMigrationIndexedDryRunAndDaemonParity`,
  `workflowDocsMigrationSpecProvesSecondWorkflow`,
  `workflowDocsMigrationPermissionAndPartitionContracts`,
  `workflowDocsMigrationEventCodecFixtureContract`,
  `workflowDocsMigrationFixtureFailureReportsThroughCore`,
  `workflowDocsMigrationAgentRoleClassifiesCompleteOutput`,
  and `workflowDocsMigrationUsesCoreExecutionContracts`.
- `test/WorkflowExecutionSpec.hs`, exporting
  `workflowExecutionTests :: IO Bool`.
  Move the generic planned-transition, DSL, daemon-core, transaction, and
  execution metadata checks, including:
  `workflowPlannedTransitionPreservesObservedEffects`,
  `workflowPlannedTransitionPartitionsPostCommitEffects`,
  `workflowPrReviewMergeabilityPlannedTransitionKeepsMergePreCommitEffect`,
  `workflowPrReviewMergeabilityFacadeLawPreservesObservationReplayEffectsAndPermissions`,
  `workflowDsl*`,
  `workflowDaemonCoreProjectsMoifoldAndDocsMigrationResults`,
  `workflowDaemonCoreProjectsObservedFailureBoundary`,
  `workflowTransactionDetailedFailuresRecordCommitBoundary`,
  `workflowTransactionDryRunExecuteParityUsesCommitBoundary`,
  `workflowExecutionMetadataCoversCurrentEffects`,
  `workflowExecutionCapabilityMetadataCoversCurrentEffects`,
  `workflowExecutionMetadataPartitionPreservesLegacyOrdering`,
  `workflowExecutionMetadataDryRunMatchesLegacy`,
  `workflowExecutionCoreCheckedActionsStopsOnFirstFailure`, and
  `workflowExecutionCheckedActionsStopsOnHardFailure`.

If compilation proves a helper is shared by multiple extracted modules, prefer
a small support module only for generic test plumbing, such as
`test/TestSupport/Workflow.hs`. Allowed support contents are test-only helpers
that already exist in `test/Main.hs`, for example `sequenceAnd`, `assert`,
`expectRight`, `expectLeft`, `replaySatisfies`, `lookupValue`,
`sameWatcherStateShape`, `lastEffectPlanIs`, `isRightUnit`, or tiny fixture
builders. Do not move production policy into test support, and do not create a
new abstraction layer around production APIs.

Keep `test/Main.hs` as the runner. It should import the new modules and reduce
`workflowFacadeExtractionTests` to aggregate:

- `workflowFacadeImportPolicyTests`
- `workflowBoundaryPolicyTests`
- `workflowEventLogTests`
- `workflowAgentTests`
- `workflowIndexedTests`
- `workflowDocsMigrationTests`
- `workflowExecutionTests`

No moved runner may be left uncalled. Existing PASS/FAIL labels should be
preserved unless a label is made clearer without weakening the predicate or
removing detail.

Allowed Cabal metadata scope is limited to the `test-suite watcher-core-test`
stanza in `moifold.cabal`: add the new test modules and any genuinely needed
`TestSupport.*` module to `other-modules`. Do not add library exposed modules,
production dependencies, executable metadata, source dirs, build tools, warning
policy, or unrelated Cabal changes. New test-suite dependencies are not
expected; if an existing test-only import becomes explicit only because of the
split, prefer local imports and existing dependencies before considering any
metadata beyond `other-modules`.

### Steps

1. Reconfirm starting context before editing:
   - `git status --short --untracked-files=all`
   - `wc -l test/Main.hs`
   - `rg -n "workflowFacadeExtractionTests|workflowEventCodecContractCoversWatcherEvents|workflowAgentCodexStartRequestsMatchCompiledEffects|workflowIndexedSpecExistentialsPreserveLabels|workflowDocsMigrationFacadeLawPreservesObservationReplayEffectsAndPermissions|workflowTransactionDryRunExecuteParityUsesCommitBoundary|workflowExecutionCheckedActionsStopsOnHardFailure" test/Main.hs`
   - `sed -n '172,190p' moifold.cabal`
2. Add the focused workflow test modules listed in the approach. Move complete
   clusters at a time, including directly coupled local helper definitions,
   fixture values, and case tables. Avoid splitting one tightly coupled helper
   family across modules unless the split is necessary to avoid import cycles.
3. If multiple modules need the same generic test helper, create or extend only
   a small `TestSupport.*` module with generic test support. Keep
   workflow-specific predicates inside the owning focused spec module.
4. Update `test/Main.hs` to import the new runners and call them from
   `workflowFacadeExtractionTests`. Remove only imports and definitions that
   became unused because the selected workflow behavior clusters moved.
5. Update `moifold.cabal` only in `watcher-core-test` `other-modules` with the
   new modules and optional focused support module. Keep existing
   `BoundaryPolicySpec`, `FacadeImportPolicySpec`, and
   `TestSupport.SourceScan` metadata intact.
6. Preserve behavior and policy boundaries:
   - Do not change assertions, expected events, effect ordering, request-id
     expectations, JSON/event labels, fixture paths, replay expectations,
     permission checks, dry-run/execute parity, or failure-classification
     checks.
   - Do not update golden files or checked-in runtime compatibility fixtures.
   - Do not migrate production imports, remove facades, rename compatibility
     files, change healthcheck/repair behavior, change DocsMigration behavior,
     or decompose production runtime modules.
7. Record implementation evidence later in
   `orchestrator/rounds/round-086/implementation-notes.md`: before/after
   `test/Main.hs` line counts, new module ownership, exact moved runner
   mapping, changed paths, commands run, and confirmation that no production,
   docs, fixtures, runtime compatibility, roadmap/state, public
   deprecation/removal, exposed-module, import-convergence, or behavior
   semantic changes were made. The planner should not write that file now.

### Verification

Run the full behavior-preserving gates because this round touches test code and
test-suite metadata:

```sh
cabal test watcher-core-test
```

```sh
cabal build all
```

```sh
git diff --check
```

```sh
git status --short --untracked-files=all
```

If staging is performed later, also run:

```sh
git diff --cached --check
```

Reviewer-facing checks should confirm:

- `workflowFacadeExtractionTests` still reaches every moved runner, and
  `watcher-core-test` still reaches `workflowFacadeExtractionTests` through the
  final `main` success condition.
- The moved behavior checks retain their prior expected events, states,
  effects, action ordering, request-id progression, permission outcomes,
  replay results, fixture expectations, failure classifications, and PASS/FAIL
  labels where practical.
- `test/Main.hs` is measurably smaller, and the before/after line count is
  recorded.
- The diff is limited to `test/Main.hs`, the new focused workflow test modules,
  optional test support, minimal `watcher-core-test` `other-modules` metadata,
  and round-local implementation/review artifacts.
- There are no production code, docs, fixtures, runtime compatibility file,
  active roadmap, controller state, public deprecation/removal, facade removal,
  Cabal exposed-module, source/app import-convergence, or behavior semantic
  changes.

### Worker Fan-Out

Do not use worker fan-out for this round. The active controller state has
`max_parallel_rounds: 1`, and the implementation has a shared aggregation point
in `test/Main.hs` plus one shared `watcher-core-test` Cabal stanza. Splitting
this across workers would create unnecessary integration risk and no clean
non-overlapping ownership boundary. Do not write `worker-plan.json`.
