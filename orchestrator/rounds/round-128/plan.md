### Goal

Move only `src/CodexWatcher/Daemon.hs` off the mixed
`CodexWatcher.Workflow.EventLog` compatibility facade for daemon audit helper
usage, using direct owner references from `CodexWatcher.Workflow.Audit` while
preserving daemon observed-tick, audit, transaction, replay, event-commit,
compatibility-write, and public-export behavior.

This round is import convergence evidence under roadmap
`2026-05-11-00-highest-value-cleanup` revision `rev-001`, milestone
`milestone-003-import-convergence-package-boundaries`, direction
`direction-012-eventlog-permission-bridge-split-readiness`. Follow
`orchestrator/project-contract.md` for stable event schema, daemon result,
dry-run, action ordering, public-facade, package-boundary, and compatibility
invariants.

### Approach

Keep the implementation as a sequential one-module production edit in
`src/CodexWatcher/Daemon.hs`.

The current daemon module already imports `CodexWatcher.Workflow.Audit`
qualified as `WorkflowAudit`, and already imports
`CodexWatcher.Workflow.EventLog.Commit.Core` directly for event commit
ownership. Keep those direct-owner imports. Remove only the exact
`CodexWatcher.Workflow.EventLog` facade import qualified as `WorkflowEventLog`
and move the remaining `WorkflowEventLog.*` audit uses to `WorkflowAudit.*`.

Expected exact use-site changes:

1. Change `daemonObservedAudit` from the facade alias
   `WorkflowEventLog.WorkflowTickAudit MoifoldSpec ActionExecutionReport` to
   direct owner spelling
   `WorkflowAudit.WorkflowTickAudit MoifoldSpec FailureClassification ActionExecutionReport`.
2. Keep `daemonObservedTransactionFailureAudit` as-is because it already uses
   `WorkflowAudit.WorkflowTickAudit MoifoldSpec DaemonFailure ActionExecutionReport`.
3. Change `WorkflowEventLog.workflowSuccessAudit @MoifoldSpec` in
   `observedDetailedTransactionResultToDaemon` to
   `WorkflowAudit.workflowSuccessAudit @MoifoldSpec`.
4. Change the `observedTransactionResultToDaemonWithAudit` audit argument type
   from `WorkflowEventLog.WorkflowTickAudit MoifoldSpec ActionExecutionReport`
   to
   `WorkflowAudit.WorkflowTickAudit MoifoldSpec FailureClassification ActionExecutionReport`.
5. Change `WorkflowEventLog.workflowAuditPreCommitReports` and
   `WorkflowEventLog.workflowAuditPostCommitReports` in
   `daemonObservedCoreTickResult` to the existing `WorkflowAudit` direct owner
   qualifier.

The direct owner audit type has shape
`WorkflowTickAudit spec failure report`. The removed facade alias had shape
`WorkflowTickAudit spec report` and fixed the failure type to
`FailureClassification`, so the only expected type-spelling adjustment is the
explicit `FailureClassification` parameter for daemon observed success/dry-run
audit values.

Do not change event labels, event JSON `type` fields, replay behavior, append
order, compatibility writes, transaction hooks, daemon recommendations,
observed transaction failure formatting, public exports, package descriptors,
docs, tests, facade modules, or runtime compatibility files.

### Steps

1. Confirm the worktree and local orchestration edits before changing files:
   `git status --short`. Treat existing `orchestrator/state.json` changes and
   other round artifacts as controller-owned/user-owned unless this role
   explicitly owns them.
2. Edit only `src/CodexWatcher/Daemon.hs`.
3. Remove the exact `import CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog`
   line.
4. Keep `import CodexWatcher.Workflow.Audit qualified as WorkflowAudit` and
   `import CodexWatcher.Workflow.EventLog.Commit.Core (...)` unchanged unless
   formatting requires local ordering cleanup.
5. Replace the remaining `WorkflowEventLog.*` use sites with the direct
   `WorkflowAudit.*` equivalents listed in the Approach section.
6. Add the explicit `FailureClassification` type parameter only for daemon
   observed audit types that previously used the facade alias. Do not introduce
   a local compatibility alias unless a compile error proves it is the smallest
   way to preserve the existing exported type shape.
7. Compile or inspect enough to remove any unused imports. No new import should
   be needed for `FailureClassification`; `CodexWatcher.Failure` is already
   imported and used by `Daemon.hs`.
8. Review the diff manually and confirm it is limited to the facade import
   removal, qualifier replacements, and the required direct audit type
   spelling. If any behavior body, export list, event constructor, event label,
   transaction hook, append call, compatibility write, logging text, or failure
   formatter changed, revert that part before verification.
9. Leave these explicitly out of scope: `src/CodexWatcher/Workflow/DocsMigration.hs`,
   tests and test support imports, `CodexWatcher.Workflow.EventLog`,
   `CodexWatcher.Workflow.Permission`, public facade exposure,
   `moifold.cabal`, package descriptors, docs, runtime compatibility files,
   event JSON `type` fields, golden fixture shapes, Workflow.Permission
   migration, public deprecation/removal, Cabal exposure removal, release
   approval, milestone completion, and terminal completion.

### Verification

Run focused daemon/workflow behavior checks before the full baseline:

1. Use the existing daemon behavior checks in `test/Main.hs`. A practical
   noninteractive path is:

   ```sh
   printf '%s\n' \
     'observedDaemonTickDryRunDoesNotMutate' \
     'observedDaemonTickExecuteAppendsWritesAndRunsEffects' \
     'observedDaemonTickAuditSeparatesPreAndPostReports' \
     'observedDaemonTickExecuteCommandFailureDoesNotAppendEvent' \
     ':quit' \
     | cabal repl watcher-core-test
   ```

   These cover observed dry-run audit labels/recommendations, execute append
   and compatibility write ordering, pre/post audit report separation, and
   pre-commit transaction failure formatting/no-append behavior.
2. Run the workflow execution aggregate to cover daemon-core projection and
   transaction audit projection:

   ```sh
   printf '%s\n' 'workflowExecutionTests' ':quit' | cabal repl watcher-core-test
   ```

3. Run the indexed workflow aggregate to cover the observed daemon audit
   surfaces used by issue-planning, issue-implement, and PR-review indexed
   paths:

   ```sh
   printf '%s\n' 'workflowIndexedTests' ':quit' | cabal repl watcher-core-test
   ```

4. If the local Cabal/GHCi path cannot run those focused checks
   noninteractively, record the exact failure and rely on the required full
   `watcher-core-test` run below, which includes the same daemon and workflow
   checks.

Run the baseline checks from the active verification bundle:

1. `cabal build all`
2. `cabal test watcher-core-test`
3. `git diff --check`
4. `git diff --cached --check` if staging is involved

Run import and facade scans that distinguish exact facade imports from direct
owner modules below the same namespace:

1. Exact Daemon facade import must be gone:

   ```sh
   rg -n '^import CodexWatcher\.Workflow\.EventLog($|[[:space:]]+qualified|[[:space:]]*\()' src/CodexWatcher/Daemon.hs
   ```

   Expected result: no matches.
2. Daemon direct owner imports should remain visible:

   ```sh
   rg -n '^import CodexWatcher\.Workflow\.(Audit|EventLog\.)' src/CodexWatcher/Daemon.hs
   ```

   Expected result: `CodexWatcher.Workflow.Audit` and
   `CodexWatcher.Workflow.EventLog.Commit.Core`, with no exact
   `CodexWatcher.Workflow.EventLog` facade import.
3. No stale facade qualifier should remain in Daemon:

   ```sh
   rg -n 'WorkflowEventLog\.' src/CodexWatcher/Daemon.hs
   ```

   Expected result: no matches.
4. Broad exact facade import scan should show only out-of-scope users:

   ```sh
   rg -n '^import CodexWatcher\.Workflow\.EventLog($|[[:space:]]+qualified|[[:space:]]*\()' src app test
   ```

   Expected result: no `src/CodexWatcher/Daemon.hs` match. Remaining matches,
   if any, are intentionally out of scope test/test-support facade imports.
5. Broad namespace scan may show direct owner modules such as
   `CodexWatcher.Workflow.EventLog.Core`, `.File.Core`, and `.Commit.Core`;
   do not count those as exact facade users:

   ```sh
   rg -n 'CodexWatcher\.Workflow\.EventLog' src app test docs *.cabal agent-workflow-*
   ```

   Record remaining exact facade users separately from direct-owner matches.
   Expected exact facade references after this round are public exposure/facade
   module, tests/test support, docs/policy references, and Cabal exposure only;
   `src/CodexWatcher/Daemon.hs` should be absent from the exact-facade set.

Run diff guards and record their results for review:

1. `git diff -- src/CodexWatcher/Daemon.hs`
2. `git diff --unified=0 -- src/CodexWatcher/Daemon.hs`
3. `git diff -- src/CodexWatcher/Daemon.hs | rg 'WorkflowEventLog|WorkflowAudit|WorkflowTickAudit|workflowSuccessAudit|workflowAuditPreCommitReports|workflowAuditPostCommitReports|module CodexWatcher.Daemon|event_committed|compatibility_written|observed transaction failed|daemonObservedAudit|daemonObservedTransactionFailureAudit'`

The diff should be import/type/qualifier-only. Any hits outside that narrow
audit import-convergence surface require review before proceeding.

### Worker Fan-Out

Not used. This is a narrow one-file import-convergence slice with one owner
module and one verification path, so worker fan-out would add coordination
risk without independent write ownership.
