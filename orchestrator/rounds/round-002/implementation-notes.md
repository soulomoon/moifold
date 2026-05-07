### Changes Made
- `test/Main.hs`: registered and added `workflowDocsMigrationFacadeLawPreservesObservationReplayEffectsAndPermissions`, covering DocsMigration observe/plan agreement, apply parity, direct and generic replay effect history, complete/partial/wrong-target permission behavior, and dry-run post-commit action ordering.
- `test/Main.hs`: registered and added `workflowPrReviewMergeabilityFacadeLawPreservesObservationReplayEffectsAndPermissions`, covering the mergeability-clean PR-review slice across observe/plan agreement, apply parity, direct/generic replay parity, mergeability facade parity, permission checks, and merge dry-run pre-commit ordering.
- `test/Main.hs`: added small comparison helpers for watcher state shape, last effect-history entry checks, and success-only `Either error ()` assertions used by the new workflow facade laws.
- `agent-workflow-core/src/CodexWatcher/Workflow/Permission/Core.hs`: made `validateWorkflowEffectPlanCore` honor the workflow spec's full effect-plan validator before reporting per-effect permission diagnostics. This was the smallest core fix needed for the DocsMigration law to reject partial draft plans consistently with `workflowValidateEffects`.

### Tests
- `test/Main.hs`: `workflowDocsMigrationFacadeLawPreservesObservationReplayEffectsAndPermissions` verifies DocsMigration observation, planning, replay, permission, and dry-run parity without changing event schemas, golden logs, daemon result shapes, dry-run report shape, action ordering, or facade representation.
- `test/Main.hs`: `workflowPrReviewMergeabilityFacadeLawPreservesObservationReplayEffectsAndPermissions` verifies one PR-review mergeability-clean slice, including merge effect pre-commit ordering and rejection from non-mergeability PR-review states.
- `cabal build all`: passed.
- `cabal test watcher-core-test`: passed.
- `git diff --check`: passed.
- `git diff --cached --check`: passed.

### Notes
No blockers. `cabal test watcher-core-test --test-options='--hide-successes'` was also run during development; it initially exposed the DocsMigration partial-plan mismatch in `validateWorkflowEffectPlanCore`, then passed after the core validator fix.
