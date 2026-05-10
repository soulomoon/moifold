### Changes Made
- `test/Main.hs`: kept `workflowFacadeExtractionTests` as the watcher-core aggregate runner and reduced it to focused runner calls for facade import policy, boundary policy, event-log, agent, indexed workflow, DocsMigration, and execution behavior tests. Removed moved workflow behavior definitions and stale imports only.
- `test/WorkflowEventLogSpec.hs`: owns the moved workflow event codec, event-log commit/file/replay/transition contract, fixture type-field, and failure-audit behavior checks behind `workflowEventLogTests`.
- `test/WorkflowAgentSpec.hs`: owns the moved execution facade, PR-review facade, agent role, Codex adapter, turn lifecycle, classifier, observation-kernel, and observation planning law checks behind `workflowAgentTests`.
- `test/WorkflowIndexedSpec.hs`: owns the moved indexed workflow existential, issue-planning indexed, issue-implement indexed, and PR-review indexed behavior clusters behind `workflowIndexedTests`.
- `test/WorkflowDocsMigrationSpec.hs`: owns the moved DocsMigration facade law, indexed law/parity, fixture/codec, permissions, agent role, and second-workflow proof checks behind `workflowDocsMigrationTests`.
- `test/WorkflowExecutionSpec.hs`: owns the moved planned-transition, PR-review mergeability law, DSL, daemon core, transaction, metadata, and checked-execution behavior checks behind `workflowExecutionTests`.
- `test/TestSupport/Workflow.hs`: added small test-only support for generic assertions, replay predicates, shared sample values, fake executor plumbing, reviewer-output builders, runtime config builders, and shared state/effect helpers needed by more than one extracted workflow spec.
- `moifold.cabal`: added only the new focused test modules and `TestSupport.Workflow` to the `watcher-core-test` `other-modules` list.
- `orchestrator/rounds/round-086/implementation-notes.md`: recorded scope, line counts, runner mapping, changed paths, and verification evidence.

### Tests
- `test/WorkflowEventLogSpec.hs`: verifies event codec labels/schema/round trips, golden type-field stability, event-log commit ordering, file numbering/decode errors, fixture decoding/error formatting, detailed replay parity, transition contract parity, and retry failure classification.
- `test/WorkflowAgentSpec.hs`: verifies workflow execution/PR-review facade parity, agent role metadata/classification, Codex request/adapter behavior, turn lifecycle parsing, observation-kernel parity, and PR-review observation plan law.
- `test/WorkflowIndexedSpec.hs`: verifies indexed existential labels, issue-planning/issue-implement/PR-review indexed transitions, projections, daemon dry-run/execute behavior, request ids, effect ordering, compatibility writes, replay parity, invalid observation failures, and permission/terminal laws.
- `test/WorkflowDocsMigrationSpec.hs`: verifies DocsMigration unindexed/indexed law parity, permissions, fixture codec, dry-run/daemon parity, fixture failure reporting, agent classification, and reuse of core execution contracts.
- `test/WorkflowExecutionSpec.hs`: verifies planned-transition partitioning, PR-review mergeability facade law, DSL lowering/projection parity, daemon-core projection/failure boundaries, transaction commit boundaries, metadata ordering/dry-run parity, and checked action failure classification.
- `test/Main.hs`: verifies runner reachability by calling the new focused runners from `workflowFacadeExtractionTests`, which remains reached by the final `main` success condition.

### Notes
Line counts:
- `test/Main.hs` before editing: 15473 lines.
- `test/Main.hs` after implementation: 7120 lines.
- New module line counts after implementation: `WorkflowEventLogSpec` 590, `WorkflowAgentSpec` 716, `WorkflowIndexedSpec` 5658, `WorkflowDocsMigrationSpec` 1051, `WorkflowExecutionSpec` 1496, `TestSupport.Workflow` 729.

Moved runner mapping:
- Event-log workflow checks now run through `workflowEventLogTests`.
- Agent/facade/observation workflow checks now run through `workflowAgentTests`.
- Indexed workflow checks now run through `workflowIndexedTests`.
- DocsMigration workflow checks now run through `workflowDocsMigrationTests`.
- Planned-transition/DSL/daemon/transaction/execution metadata checks now run through `workflowExecutionTests`.
- `workflowTransactionDryRunExecuteParityUsesCommitBoundary` moved from the old standalone `main` binding into `workflowExecutionTests`, preserving reachability through `workflowFacadeExtractionTests`.

Changed paths owned by this implementation:
- `moifold.cabal`
- `test/Main.hs`
- `test/TestSupport/Workflow.hs`
- `test/WorkflowAgentSpec.hs`
- `test/WorkflowDocsMigrationSpec.hs`
- `test/WorkflowEventLogSpec.hs`
- `test/WorkflowExecutionSpec.hs`
- `test/WorkflowIndexedSpec.hs`
- `orchestrator/rounds/round-086/implementation-notes.md`

Pre-existing/unowned paths observed before editing:
- `orchestrator/state.json`
- `orchestrator/rounds/round-086/plan.md`
- `orchestrator/rounds/round-086/selection.md`

Commands run:
- `git status --short --untracked-files=all` before editing: showed pre-existing `M orchestrator/state.json` and untracked round `plan.md` / `selection.md`.
- `wc -l test/Main.hs` before editing: `15473 test/Main.hs`.
- `rg -n "workflowFacadeExtractionTests|workflowEventCodecContractCoversWatcherEvents|workflowAgentCodexStartRequestsMatchCompiledEffects|workflowIndexedSpecExistentialsPreserveLabels|workflowDocsMigrationFacadeLawPreservesObservationReplayEffectsAndPermissions|workflowTransactionDryRunExecuteParityUsesCommitBoundary|workflowExecutionCheckedActionsStopsOnHardFailure" test/Main.hs`: confirmed selected runners/checks before moving.
- `sed -n '172,190p' moifold.cabal`: confirmed starting `watcher-core-test` `other-modules`.
- `cabal test watcher-core-test`: passed. The suite compiled the extracted modules and reported `Test suite watcher-core-test: PASS`.
- `cabal build all`: passed. Cabal built the `moifold` executable.
- `git diff --check`: passed.
- `git status --short --untracked-files=all`: dirty with owned edits/new test modules and notes, plus the pre-existing `orchestrator/state.json` and round plan/selection artifacts.
- `git diff --cached --check`: not run because no staging occurred.

No production code, docs, fixtures, runtime compatibility files, roadmap files, controller state, public deprecation/removal status, facade availability, Cabal exposed modules, source/app import convergence, runtime compatibility-file names/semantics, or behavior semantics were changed by this implementation.
