### Goal
Add focused transaction law coverage for the current generic transaction core, proving failure-stage classification, commit boundaries, audit recommendations, retryability, action partitioning, and dry-run versus execute parity for the existing moifold and DocsMigration transaction paths without moving ownership boundaries.

### Approach
Keep this round sequential and single-owner. The implementation should be test-first and primarily limited to `test/Main.hs`; production code should change only if the new law tests expose a real contract mismatch in the existing transaction core. Do not write `worker-plan.json`.

Use the existing fake interpreters and the current `DocsMigrationSpec`/`MoifoldSpec` surfaces as the oracles. `agent-workflow-core/src/CodexWatcher/Workflow/Transaction/Core.hs` already exposes the detailed execution path and failure stages, `src/CodexWatcher/Daemon.hs` wires moifold through prepared dry-run/execute transactions, and `src/CodexWatcher/Workflow/DocsMigration.hs` provides the second-workflow dry-run/execute helpers. The new tests should tighten those contracts rather than introduce a new fake workflow package, event schema, daemon boundary, compatibility facade, or adapter API.

### Steps
1. Inspect the existing transaction and daemon test block in `test/Main.hs` around `observedDaemonTickDryRunDoesNotMutate`, `observedDaemonTickAuditSeparatesPreAndPostReports`, `observedDaemonTickExecuteCommandFailureDoesNotAppendEvent`, `workflowDocsMigrationUsesCoreExecutionContracts`, `workflowDaemonCoreProjectsMoifoldAndDocsMigrationResults`, and `workflowTransactionDetailedFailuresRecordCommitBoundary`. Reuse nearby fake executor helpers and assertion style.
2. Extend the generic transaction failure-stage coverage near `workflowTransactionDetailedFailuresRecordCommitBoundary` using `DocsMigrationSpec` plus fake `WorkflowObservedTransactionHooks`. Cover all detailed stages:
   - prepare failure before replay is available, with no audit because there is no prior replay;
   - prepare failure after replay, such as invalid observation/effect validation, with audit present and no committed event;
   - pre-commit action failure, with no committed event and retry recommendation when the injected failure is retryable;
   - event commit failure, with pre-commit reports preserved and no committed event;
   - post-commit replay failure, using `runWorkflowPreparedExecuteTransactionDetailed` with a deliberately invalid planned event after a valid prior replay, proving the event is committed but no final state exists;
   - post-commit callback failure, with committed event and final state recorded;
   - post-commit action failure, with committed event, final state, pre-commit reports, and no successful post reports.
3. Add explicit audit-law assertions for the same generic transaction cases: prior state label, observation label when available, committed event label only after a real commit boundary, final state label only after successful post-commit replay, failure classification, and `WorkflowDaemonRetry` versus `WorkflowDaemonStop` from `workflowTransactionFailureIsRetryable`.
4. Add focused dry-run versus execute parity coverage for the generic transaction runner using fake hooks with both pre-commit and post-commit actions. Assert dry-run compiles once, partitions reports into pre/post buckets, returns no committed events, and never calls execute, commit, or after-commit hooks; assert execute runs pre actions before commit, records the commit, runs after-commit before post actions, and returns the same planned event/final state/action partition as dry-run.
5. Tighten the moifold transaction path coverage in `test/Main.hs` without changing daemon production code:
   - keep `observedDaemonTickDryRunDoesNotMutate` as the dry-run no-mutation guard and add assertions that dry-run compiled action partitioning matches audit pre/post reports;
   - extend `observedDaemonTickExecuteAppendsWritesAndRunsEffects` or add a nearby focused case proving fake calls occur in pre-commit action, event append, compatibility write, post-commit action order;
   - add a post-commit failure case, for example a fake compatibility write failure if the current interpreter can surface it, or otherwise document in implementation notes why moifold post-commit callback failure is only covered by the generic fake hook.
6. Tighten the DocsMigration transaction path coverage around `workflowDocsMigrationUsesCoreExecutionContracts`:
   - assert `runDocsMigrationObservedDryRun` and `runDocsMigrationObservedExecute` produce the same planned event, final state, compiled action order, and report action order;
   - assert dry-run has no committed events and no interpreter calls;
   - assert execute commits the event, runs the fake interpreter calls in action order, and keeps all DocsMigration draft/validation effects in the post-commit partition;
   - keep the existing all-post-commit behavior as the expected DocsMigration contract.
7. Wire any new IO tests into `main` and the final `all` guard in `test/Main.hs`. Prefer reusing or extending existing helpers such as `WorkflowTransactionFailureMode`, `docsMigrationFailureHooks`, fake executors, and `callBefore`; add only small test-local helpers when the assertions would otherwise become hard to read.
8. Review the diff for scope. It should not edit roadmap files, `selection.md`, implementation notes, merge notes, review artifacts, golden fixtures, event schemas, compatibility facade removal, `orchestrator/state.json`, or package/module boundaries. If production code changes were required by a failing new test, keep them narrowly in the transaction/audit path and call out the reason in implementation notes.

### Verification
Run the focused round target first, then the roadmap baseline:

1. `cabal test watcher-core-test`
2. `cabal build all`
3. `git diff --check`

If staging occurs later in the round, also run:

4. `git diff --cached --check`

Reviewers should additionally inspect that `agent-workflow-core` still owns only generic workflow kernel contracts, moifold keeps concrete `WatcherEvent` and daemon/runtime ownership, and DocsMigration remains the second-workflow proof without new filesystem or interpreter authority in core.
