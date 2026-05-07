### Goal

Add focused workflow facade law and parity coverage for the current facade representation before any indexed or representation-changing work begins. The round proves observation-to-event consistency, replay parity, effect-history stability, and permission soundness for `DocsMigration` plus one narrow PR-review mergeability slice.

### Approach

Keep the implementation test-first and sequential. The expected write scope is `test/Main.hs`, adding named assertions under `workflowFacadeExtractionTests`; no production modules, event codecs, golden fixtures, daemon result types, dry-run rendering, or runtime command rendering should change for this item.

Use two concrete slices:

- `DocsMigration`: replay `[DocsMigrationInitialized, DocsMigrationTurnStarted]`, observe `DocsMigrationAgentReturned (AgentComplete (DocsMigrationOutput "draft markdown" "draft ready"))`, and lock the planned event to `DocsMigrationDraftProduced "draft markdown" "draft ready"` with post-commit effects `[WriteDocsMigrationDraft "docs/target.md" "draft markdown", RunDocsMigrationValidation "docs/target.md"]`.
- PR-review: replay to `PrWaitingForMergeability` through `[PrReviewInitialized, PrReviewNoUnresolvedFound, PrReviewCleanFound]`, observe `ObservedMergeabilityClean commit`, and lock the planned event to `PrReviewMergeabilityClean commit` with pre-commit effects `[SomeEffect (MergePullRequest prConfig cleanEvidence)]`.

Preservation constraints for this round:

- Do not edit `WatcherEvent` JSON encoding/decoding, `docsMigrationEventCodecContract`, `golden/event-log/**`, or event-log schema docs.
- Do not change daemon result record fields, audit projection shapes, dry-run action reports, runtime command rendering, or pre/post-commit action ordering.
- Do not change facade representation or introduce the indexed `WorkflowSpec` API in this round; this item only adds the laws that make those later changes reviewable.

### Steps

1. Add small local comparison helpers in `test/Main.hs` near the existing workflow facade helpers, reusing `sameReplay`, `workflowApplyEvent`, `workflowPlanObservation`, `workflowValidateEffects`, `WorkflowPermission.validateWorkflowEffectPlanCore`, and existing effect/action helpers instead of introducing new test infrastructure.
2. Add a `workflowDocsMigrationFacadeLawPreservesObservationReplayEffectsAndPermissions` assertion and register it in `workflowFacadeExtractionTests`. It must check all of the following in one deterministic fixture:
   - `workflowObserve @DocsMigrationSpec` and `workflowPlanObservation @DocsMigrationSpec` agree on the observed event, final state, and full effect plan.
   - Applying the planned event with `workflowApplyEvent @DocsMigrationSpec` reaches the observed state and returns the same effects.
   - `DocsMigration.replayDocsMigrationEvents` and `WorkflowEventLog.replayWorkflowEventLogDetailed @DocsMigrationSpec` preserve the same final state and per-event effect history, including the exact draft write before validation order.
   - `workflowValidateEffects @DocsMigrationSpec` and `WorkflowPermission.validateWorkflowEffectPlanCore @DocsMigrationSpec` accept the complete draft effect plan and reject a partial or wrong-target draft write.
   - `runDocsMigrationObservedDryRun` still commits no event, reports dry-run-only action reports, keeps both reports post-commit, and preserves the compiled action order.
3. Add a `workflowPrReviewMergeabilityFacadeLawPreservesObservationReplayEffectsAndPermissions` assertion and register it in `workflowFacadeExtractionTests`. It must check all of the following for the single PR-review mergeability-clean slice:
   - `workflowObserve @MoifoldSpec` and `workflowPlanObservation @MoifoldSpec` agree on `PrReviewMergeabilityClean commit`, `PrMerging`, and `[SomeEffect (MergePullRequest prConfig cleanEvidence)]`.
   - Applying the planned event with `workflowApplyEvent @MoifoldSpec` reaches the observed state and returns the same effect plan.
   - Direct `replayEventLog` and generic `workflowReplayEvents @MoifoldSpec` match for the event prefix plus `PrReviewMergeabilityClean`, including the last effect-history entry.
   - `WorkflowPrReviewMergeability.observePrReviewMergeability` remains parity-equivalent with the public `DaemonPrReviewObservation (ObservedMergeabilityClean commit)` path.
   - `validatePhaseActionPlan`, `WorkflowPermission.validateMoifoldEffectPlan`, and `WorkflowPermission.validateWorkflowEffectPlanCore @MoifoldSpec` accept the merge effect in `PrWaitingForMergeability` and reject the same effect from a non-mergeability PR-review state.
   - Compiling and dry-running the merge effect preserves the existing dry-run report shape and action order; no merge command should move to post-commit.
4. Keep existing schema and fixture guards in `workflowFacadeExtractionTests` intact: `workflowEventCodecContractCoversWatcherEvents`, `workflowEventCodecToleratesMetadataAndPreservesGoldenTypes`, `workflowDocsMigrationEventCodecFixtureContract`, and golden replay cases must continue to pass without fixture churn.
5. If any of the new assertions fail because the current facade behavior is inconsistent, fix only the smallest test-support or facade-law bug needed to make current behavior coherent. Stop and replan before changing event JSON schemas, golden logs, daemon result shapes, dry-run output, action ordering, or facade representation.

### Verification

Run the exact baseline commands from `orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-001/verification.md`:

- `cabal build all`
- `cabal test watcher-core-test`
- `git diff --check`
- `git diff --cached --check`

Focused task checks are the new named assertions registered under `workflowFacadeExtractionTests`, executed by `cabal test watcher-core-test` because the current test harness does not provide a matcher. Review evidence should call out the DocsMigration law assertion, the PR-review mergeability law assertion, and the existing schema/golden guards that prove no event JSON schema or golden log changed.
