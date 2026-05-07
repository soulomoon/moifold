### Checks Run
- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`.
- Command: `cabal test watcher-core-test`
  Result: pass. The suite reported `Test suite watcher-core-test: PASS` and `1 of 1 test suites (1 of 1 test cases) passed`.
- Command: `git diff --check`
  Result: pass. No whitespace errors.
- Command: `git diff --cached --check`
  Result: pass. No staged whitespace errors; no staged changes were present.
- Command: `rg -n "instance IndexedWorkflow\\.IndexedWorkflowSpec DocsMigrationSpec|workflowInitialEvent @DocsMigrationSpec|workflowApplyEvent @DocsMigrationSpec|workflowObserve @DocsMigrationSpec|docsMigrationObservedTransition|docsMigrationPlannedTransitionFromEffects|replayDocsMigrationEvents|workflowValidateEffects @DocsMigrationSpec|workflowEffectAllowed @DocsMigrationSpec|workflowIsTerminal @DocsMigrationSpec|workflowStateLabel @DocsMigrationSpec|workflowEventLabel @DocsMigrationSpec|workflowObservationLabel @DocsMigrationSpec|workflowEffectLabel @DocsMigrationSpec" src/CodexWatcher/Workflow/DocsMigration.hs`
  Result: pass. Output showed the indexed `DocsMigrationSpec` instance and direct delegation to the existing compatibility facade for initial/apply/observe/replay, planned transitions, permissions, terminal checks, and labels.
- Command: `rg -n "workflowDocsMigrationIndexedSpecMatchesCompatibilityForDraft|workflowDocsMigrationIndexedSpecMatchesCompatibilityForValidationAndBlocked|workflowDocsMigrationIndexedSpecPreservesPermissionsAndFixtureCodec|workflowDocsMigrationIndexedDryRunAndDaemonParity" test/Main.hs`
  Result: pass. Output showed all four focused indexed DocsMigration parity tests registered in `workflowFacadeExtractionTests` and defined in the test file.
- Command: `git diff --numstat -- src/CodexWatcher/Workflow/DocsMigration.hs`
  Result: pass. Output was `186 0 src/CodexWatcher/Workflow/DocsMigration.hs`, confirming the DocsMigration source change is additive.
- Command: `git diff --name-only -- ':(exclude)orchestrator/state.json' ':(exclude)src/CodexWatcher/Workflow/DocsMigration.hs' ':(exclude)test/Main.hs'`
  Result: pass. No output; the implementation diff is limited to the DocsMigration source and tests, with only controller state metadata outside those files.
- Command: `git diff --name-only -- 'golden/**' '**/golden/**' 'test/golden/**' '**/*.golden' '**/fixtures/**' '**/fixture/**'`
  Result: pass. No output; no golden or fixture files changed.

### Plan Compliance
- Add a DocsMigration indexed adapter beside the existing compatibility facade: met. `src/CodexWatcher/Workflow/DocsMigration.hs` adds `IndexedWorkflowSpec DocsMigrationSpec` and wrapper/index types without replacing the existing `WorkflowSpec DocsMigrationSpec` instance.
- Delegate indexed behavior to existing DocsMigration behavior: met. Static inspection shows indexed initial/apply/observe/replay/permissions/terminal/label methods call `workflowInitialEvent`, `workflowApplyEvent`, `workflowObserve`, `replayDocsMigrationEvents`, `workflowValidateEffects`, `workflowEffectAllowed`, `workflowIsTerminal`, and existing label functions. Planned transitions delegate through `docsMigrationObservedTransition` and `docsMigrationPlannedTransitionFromEffects`.
- Preserve event codec, fixture replay, schema labels/fields, golden logs, dry-run reports, daemon result shape, action ordering, and compatibility-facade behavior: met. The diff does not touch golden/fixture files or existing codec/daemon/dry-run functions, and `watcher-core-test` passed the existing codec, fixture, dry-run, daemon projection, and action-ordering tests.
- Add focused indexed DocsMigration parity tests: met. All four requested test functions are registered in `workflowFacadeExtractionTests`; the full suite output includes PASS lines for draft parity, validation/blocked parity, permissions/fixture codec parity, and dry-run/daemon parity.
- Keep existing DocsMigration tests in place: met. The existing DocsMigration facade, second-workflow, permission/partition, event-codec fixture, core execution, and daemon projection tests remain registered and passed.
- Worker fan-out: met. `orchestrator/state.json` records `worker_mode` as `none`, and review was against the integrated round result.
- Roadmap identity: met. `selection.md` and `state.json` agree on roadmap id `2026-05-07-00-workflow-kernel-indexing`, revision `rev-001`, roadmap dir `orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-001`, and item `item-005-indexed-docs-migration`.

### Decision
**APPROVED**

### Evidence
The baseline verification contract passed: `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, and `git diff --cached --check`.

The focused test output included:
- `PASS indexed docs-migration draft adapter matches compatibility facade`
- `PASS indexed docs-migration validation and blocked adapters preserve stop effects and labels`
- `PASS indexed docs-migration permissions accept allowed draft plan`
- `PASS indexed docs-migration permissions reject partial draft plan like compatibility`
- `PASS indexed docs-migration permissions reject wrong target plan like compatibility`
- `PASS indexed docs-migration permissions reject disallowed state like compatibility`
- `PASS indexed docs-migration keeps fixture codec contract unchanged`
- `PASS indexed docs-migration dry-run and daemon helpers preserve compatibility output`

Existing compatibility evidence also passed in the same test run, including `workflow docs-migration event codec validates fixture replay contract`, `workflow docs-migration reuses core execution contracts`, `workflow daemon core projects docs-migration execute tick result`, and the workflow metadata/action-ordering checks.

Control-plane note: `orchestrator/state.json` is dirty relative to HEAD with active round review metadata that matches the user-provided review stage. I did not edit it. No roadmap files, merge files, golden files, fixtures, event codec files, daemon implementation files, or dry-run/action-ordering implementation files changed.
