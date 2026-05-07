### Checks Run
- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`.
- Command: `cabal test watcher-core-test`
  Result: pass. The required baseline run ended with `Test suite watcher-core-test: PASS` and `1 of 1 test suites (1 of 1 test cases) passed.`
- Command: `git diff --check`
  Result: pass. No whitespace errors reported.
- Command: `git diff --cached --check`
  Result: pass. No staged diff and no whitespace errors reported.
- Command: `rg -n "workflowDocsMigrationFacadeLawPreservesObservationReplayEffectsAndPermissions|workflowPrReviewMergeabilityFacadeLawPreservesObservationReplayEffectsAndPermissions|workflowEventCodecContractCoversWatcherEvents|workflowEventCodecToleratesMetadataAndPreservesGoldenTypes|workflowDocsMigrationEventCodecFixtureContract|goldenEventLogFixtures|goldenEventLogFixturePaths" test/Main.hs`
  Result: pass. The DocsMigration and PR-review mergeability facade-law assertions are defined and registered under `workflowFacadeExtractionTests`; the event codec, metadata/golden, docs-migration fixture, and golden fixture guard entries remain present.
- Command: `git diff --name-only -- 'golden/**' 'test/golden/**' 'docs/**' '*schema*' '*Schema*'`
  Result: pass. No event schema, docs schema, or golden fixture files changed.
- Command: `git diff --name-only | rg '(^golden/|^test/golden/|event-log|schema|Schema|Daemon|daemon|DryRun|dry-run|Execution|Action|action|Runtime|runtime|Result|result|order|Order)'`
  Result: pass. No changed file path matched event JSON schema, golden fixture, daemon result, dry-run, runtime command, or action-ordering surfaces.
- Command: `rg -n "^import .*\\b(Aeson|Codex|Github|GitHub|Moifold|Daemon|Runtime|Transport)\\b|Aeson|GitHub|Moifold|Daemon|Runtime|Transport" agent-workflow-core/src/CodexWatcher/Workflow/Permission/Core.hs`
  Result: pass. No forbidden workflow-kernel imports were introduced in the reusable permission core.
- Command: `cabal test watcher-core-test 2>&1 | rg "workflow docs-migration law|workflow PR-review mergeability law|workflow docs-migration event codec validates fixture replay contract|workflow event-log golden type fields unchanged|Test suite watcher-core-test: PASS|1 of 1 test suites"`
  Result: pass. The filtered rerun showed all new DocsMigration law checks, all new PR-review mergeability law checks, golden type-field guard checks, the docs-migration fixture guard, and final suite pass output.

### Plan Compliance
- Step 1: met. `test/Main.hs` adds small local helpers for watcher-state shape, last effect-history checks, and success-only `Either error ()` assertions near the existing facade helpers.
- Step 2: met. `workflowDocsMigrationFacadeLawPreservesObservationReplayEffectsAndPermissions` is registered under `workflowFacadeExtractionTests` and covers observe/plan agreement, apply parity, direct vs generic replay history, complete/partial/wrong-target permission behavior, and dry-run post-commit report/action ordering.
- Step 3: met. `workflowPrReviewMergeabilityFacadeLawPreservesObservationReplayEffectsAndPermissions` is registered under `workflowFacadeExtractionTests` and covers observe/plan agreement, apply parity, direct vs generic replay parity, mergeability facade parity, merge permission acceptance/rejection, and pre-commit merge dry-run ordering.
- Step 4: met. The schema and fixture guards remain registered: `workflowEventCodecContractCoversWatcherEvents`, `workflowEventCodecToleratesMetadataAndPreservesGoldenTypes`, golden replay fixture coverage, and `workflowDocsMigrationEventCodecFixtureContract` are still present and the suite passes them.
- Step 5: met. The only production change is the narrow permission-core fix in `agent-workflow-core/src/CodexWatcher/Workflow/Permission/Core.hs`, making `validateWorkflowEffectPlanCore` honor `workflowValidateEffects @spec` before per-effect permission checks. It does not change event JSON schemas, golden logs, daemon result shapes, dry-run output, action ordering, facade representation, or indexed `WorkflowSpec` APIs.

### Decision
**APPROVED**

### Evidence
The integrated diff touches `test/Main.hs`, `agent-workflow-core/src/CodexWatcher/Workflow/Permission/Core.hs`, and the controller's `orchestrator/state.json` review-round activation. The new test registrations are at `test/Main.hs` lines 6215-6216, with schema/golden guards still at lines 6186-6187 and 6222. The new DocsMigration law is defined at line 7426, the PR-review mergeability law at line 7542, and helper functions at lines 8352-8364.

The permission-core change imports only `CodexWatcher.Workflow.Spec` and `Data.Text`, so it does not pull moifold lifecycle types, GitHub adapters, Codex transport, runtime interpreters, daemon modules, or Aeson into the reusable core. The full baseline passed, and the filtered rerun printed passing checks for every new facade-law assertion plus golden type-field and docs-migration fixture guards.
