### Checks Run
- Command: `cabal test watcher-core-test`
  Result: pass. The suite built the extracted workflow modules and reported `Test suite watcher-core-test: PASS`; the output included PASS labels from the moved indexed, DocsMigration, event-log, agent, and execution workflow checks.
- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`.
- Command: `git diff --check`
  Result: pass. No whitespace or conflict-marker errors reported.
- Command: `git diff --cached --check`
  Result: pass. No staged diff errors reported.
- Command: `git status --short --untracked-files=all`
  Result: pass with expected dirty round state. Status shows modified `moifold.cabal`, `test/Main.hs`, `orchestrator/state.json`, untracked round artifacts, and the six new test modules/support file.

### Plan Compliance
- Reconfirm starting context: met. Implementation notes recorded the required pre-edit status, `test/Main.hs` line count, selected symbol search, and watcher-core-test Cabal stanza inspection.
- Add focused workflow behavior modules: met. `WorkflowEventLogSpec`, `WorkflowAgentSpec`, `WorkflowIndexedSpec`, `WorkflowDocsMigrationSpec`, and `WorkflowExecutionSpec` exist and each exports the planned aggregate runner.
- Add only small shared test support if needed: met. `TestSupport.Workflow` is test-only and holds shared assertion, replay, sample-value, fake executor, runtime-config, and state/effect helpers used by multiple extracted specs.
- Preserve runner aggregation: met. `test/Main.hs` keeps `workflowFacadeExtractionTests`, which calls `workflowFacadeImportPolicyTests`, `workflowBoundaryPolicyTests`, `workflowEventLogTests`, `workflowAgentTests`, `workflowIndexedTests`, `workflowDocsMigrationTests`, and `workflowExecutionTests`; `main` still reaches `workflowFacadeExtractionTests`.
- Limit Cabal metadata to watcher-core-test other-modules: met. `moifold.cabal` only adds `TestSupport.Workflow` and the five planned `Workflow*Spec` modules to `test-suite watcher-core-test` `other-modules`.
- Preserve behavior and policy boundaries: met. No production code, docs, fixtures, runtime compatibility files, roadmap bundle files, public deprecation/removal status, exposed library modules, source/app import convergence, or runtime compatibility-file names changed. The modified `orchestrator/state.json` is controller round-selection state, not an implementation behavior change.
- Record implementation evidence: met. `implementation-notes.md` records changed paths, before/after line counts, runner mapping, verification, and no-out-of-scope-change confirmation.

### Decision
**APPROVED**

### Evidence
Changed implementation paths are limited to `moifold.cabal`, `test/Main.hs`, `test/TestSupport/Workflow.hs`, `test/WorkflowAgentSpec.hs`, `test/WorkflowDocsMigrationSpec.hs`, `test/WorkflowEventLogSpec.hs`, `test/WorkflowExecutionSpec.hs`, and `test/WorkflowIndexedSpec.hs`, plus round-local artifacts and controller state.

`moifold.cabal` changed only inside `watcher-core-test` `other-modules` by adding:

- `TestSupport.Workflow`
- `WorkflowAgentSpec`
- `WorkflowDocsMigrationSpec`
- `WorkflowEventLogSpec`
- `WorkflowExecutionSpec`
- `WorkflowIndexedSpec`

`workflowFacadeExtractionTests` remains in `test/Main.hs` and aggregates all moved runners. `main` still binds `workflowFacadeOk <- workflowFacadeExtractionTests`, so `watcher-core-test` still reaches the extracted behavior checks.

The moved aggregate runners preserve the planned coverage:

- `workflowEventLogTests` includes codec contract, metadata/golden type preservation, commit/file wrapper/core replay, transition contract, and failure-audit checks.
- `workflowAgentTests` includes execution facade, PR-review facade, agent role, Codex adapter, lifecycle parsing, classifier, observation-kernel, and observation-plan law checks.
- `workflowIndexedTests` includes indexed workflow existential, issue-planning, issue-implement, PR-review checking/worker/reviewer/mergeability, daemon, permission, replay, request-id, and compatibility-write checks.
- `workflowDocsMigrationTests` includes DocsMigration facade/indexed law, fixture codec, permission, dry-run/daemon parity, failure replay, agent classification, and core execution contract checks.
- `workflowExecutionTests` includes planned-transition, PR-review mergeability law, DSL, daemon core, transaction, metadata, and checked-execution checks.

Independent label preservation check compared `assert "..."` and `putStrLn "PASS ..."` strings from `HEAD:test/Main.hs` against current `test/Main.hs` plus the new workflow modules/support. Result: old labels `480`, new labels `480`, missing labels `0`, supporting that the moved behavior assertions and PASS labels were retained.

Line-count evidence matches implementation notes: `test/Main.hs` was reduced from `15473` to `7120` lines, and new module sizes are `WorkflowEventLogSpec` `590`, `WorkflowAgentSpec` `716`, `WorkflowIndexedSpec` `5658`, `WorkflowDocsMigrationSpec` `1051`, `WorkflowExecutionSpec` `1496`, and `TestSupport.Workflow` `729`.
