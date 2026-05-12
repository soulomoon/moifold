### Goal

Migrate only `test/WorkflowDocsMigrationSpec.hs` off the exact
`CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog`
compatibility-facade import. Use direct owner modules for the existing replay,
fixture, failure-diagnostic, and audit accessor use sites while preserving all
DocsMigration assertions, runner aggregation, fixture behavior, event schemas,
daemon audit behavior, and existing direct
`WorkflowEventLogCommit` / `WorkflowEventLogFileCore` imports.

This is import convergence evidence under roadmap
`2026-05-11-00-highest-value-cleanup` revision `rev-001`, milestone
`milestone-003-import-convergence-package-boundaries`, direction
`direction-012-eventlog-permission-bridge-split-readiness`. Follow
`orchestrator/project-contract.md` for stable event schema, fixture, replay,
daemon audit, public facade, and package-boundary invariants.

### Approach

Keep the implementation as a sequential one-test-file edit in
`test/WorkflowDocsMigrationSpec.hs`.

Remove only the exact
`CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog` import. Add
qualified direct-owner imports:

```haskell
import CodexWatcher.Workflow.Audit qualified as WorkflowAudit
import CodexWatcher.Workflow.EventLog.Core qualified as WorkflowEventLogCore
```

Use `WorkflowEventLogCore` for pure replay, fixture, and failure helpers:

1. `replayWorkflowEventLogDetailed`
2. `validateEventLogFixtureContract`
3. `workflowReplayFailureEventIndex`
4. `workflowReplayFailureEventLabel`
5. `workflowReplayFailurePriorStateLabel`
6. `workflowReplayFailureReason`

Use `WorkflowAudit` for audit record accessors:

1. `workflowAuditPreCommitReports`
2. `workflowAuditPostCommitReports`
3. `workflowAuditCommittedEventLabel`

Do not change direct owner imports for
`CodexWatcher.Workflow.EventLog.Commit.Core` or
`CodexWatcher.Workflow.EventLog.File.Core`. Do not change assertions, helper
exports, `workflowDocsMigrationTests` aggregation, event constructors, fixture
values, codec contracts, daemon tick behavior, permission checks, docs, Cabal
exposure, public facade modules, runtime compatibility files, or any file
outside `test/WorkflowDocsMigrationSpec.hs`.

### Steps

1. Confirm the precondition in the selected file:

   ```sh
   rg -n 'CodexWatcher\.Workflow\.EventLog qualified as WorkflowEventLog|WorkflowEventLog\.' test/WorkflowDocsMigrationSpec.hs
   ```

   Expected before editing: one exact facade import and only local
   `WorkflowEventLog.` use sites that map to `EventLog.Core` or
   `Workflow.Audit`.
2. Edit only `test/WorkflowDocsMigrationSpec.hs`.
3. Remove:

   ```haskell
   import CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog
   ```

4. Add the two direct-owner qualified imports listed in the Approach section,
   keeping the existing `WorkflowEventLogCommit` and
   `WorkflowEventLogFileCore` imports unchanged.
5. Replace every replay, fixture, and failure accessor use from
   `WorkflowEventLog.` to `WorkflowEventLogCore.`.
6. Replace every audit accessor use from `WorkflowEventLog.` to
   `WorkflowAudit.`.
7. Compile or inspect enough to remove only import issues introduced by this
   migration. If a compile error points to ownership assumptions, prefer the
   already exposed direct owner modules over restoring the facade import.
8. Review the diff manually. It should be limited to the import swap and
   qualifier replacements in `test/WorkflowDocsMigrationSpec.hs`, plus this
   plan artifact during planning. Revert any incidental assertion, fixture,
   schema, runner, export, production, docs, package descriptor, roadmap, or
   state change.

### Verification

Run a focused DocsMigration aggregate before the full baseline:

```sh
printf ':module + WorkflowDocsMigrationSpec\nworkflowDocsMigrationTests\n:quit\n' | cabal repl watcher-core-test
```

Expected focused result: `True`. If local Cabal/GHCi cannot run the aggregate
noninteractively, record the exact failure and rely on the required full
`watcher-core-test` run, which includes the same aggregate via `test/Main.hs`.

Run the required baseline checks from the active verification bundle:

```sh
cabal test watcher-core-test
cabal build all
git diff --check
git diff --cached --check
```

Run selected-file facade and stale-qualifier scans:

```sh
! rg -n '^import\s+CodexWatcher\.Workflow\.EventLog($|\s+(qualified|as|\(|hiding))' test/WorkflowDocsMigrationSpec.hs
! rg -n 'WorkflowEventLog\.' test/WorkflowDocsMigrationSpec.hs
rg -n '^import\s+CodexWatcher\.Workflow\.(Audit|EventLog\.Core|EventLog\.Commit\.Core|EventLog\.File\.Core)' test/WorkflowDocsMigrationSpec.hs
```

Expected result: no exact `CodexWatcher.Workflow.EventLog` facade import, no
stale `WorkflowEventLog.` qualifier, and direct owner imports for
`Workflow.Audit`, `Workflow.EventLog.Core`, `Workflow.EventLog.Commit.Core`,
and `Workflow.EventLog.File.Core`.

Run the broad exact EventLog facade import scan, distinguishing the exact
facade from direct owner modules below the same namespace:

```sh
rg -n '^import\s+CodexWatcher\.Workflow\.EventLog($|\s+(qualified|as|\(|hiding))' src app test
```

Expected result: no `test/WorkflowDocsMigrationSpec.hs` match. Remaining
matches are intentionally out of scope for this round and may include
`test/FacadeImportPolicySpec.hs`, `test/WorkflowEventLogSpec.hs`,
`test/WorkflowExecutionSpec.hs`, `test/WorkflowIndexedSpec.hs`, and
legacy `test/Main.hs`.

Run a broad namespace scan as review evidence, but do not count direct owner
modules as exact facade users:

```sh
rg -n 'CodexWatcher\.Workflow\.EventLog' src app test docs *.cabal agent-workflow-*
```

Record remaining exact facade references separately from direct-owner matches.
Expected exact facade references after this round are public exposure/facade
module, out-of-scope tests, policy/docs references, and Cabal exposure only.

Run diff guards and record their results for review:

```sh
git diff -- test/WorkflowDocsMigrationSpec.hs
git diff --unified=0 -- test/WorkflowDocsMigrationSpec.hs
git diff -- test/WorkflowDocsMigrationSpec.hs | rg 'WorkflowEventLog|WorkflowEventLogCore|WorkflowAudit|workflowAudit|replayWorkflowEventLogDetailed|validateEventLogFixtureContract|workflowReplayFailure|docs-migration-|schemaVersion|docsMigrationEventLogFixture|workflowDocsMigrationTests'
git status --short
```

The implementation diff should be import/qualifier-only in the selected test
file. Existing controller-owned or user-owned worktree changes, such as
`orchestrator/state.json`, must not be modified by this round.

### Worker Fan-Out

Not used. This is a single test-file import-convergence slice with one
verification path, so worker fan-out would add coordination overhead without
independent write ownership.
