### Goal

Move only `src/CodexWatcher/Workflow/DocsMigration.hs` off the mixed
`CodexWatcher.Workflow.EventLog` compatibility facade and onto direct owner
imports for the generic event-log, commit, and audit symbols it already uses,
while preserving all DocsMigration behavior and public exports.

This round is import convergence evidence under roadmap
`2026-05-11-00-highest-value-cleanup` revision `rev-001`, milestone
`milestone-003-import-convergence-package-boundaries`, direction
`direction-012-eventlog-permission-bridge-split-readiness`. Follow
`orchestrator/project-contract.md` for stable event schema, fixture,
permission, dry-run, public-facade, and compatibility invariants.

### Approach

Keep the implementation as a sequential one-module production edit. Replace the
single `CodexWatcher.Workflow.EventLog` import in DocsMigration with direct
owner imports for the same symbols:

- `CodexWatcher.Workflow.EventLog.Core`: `EventLogFixtureContract (..)`,
  `WorkflowReplaySummary (..)`, `formatWorkflowReplayFailure`, and
  `replayWorkflowEventLogDetailed`.
- `CodexWatcher.Workflow.EventLog.Commit.Core`: keep
  `WorkflowEventCommitter (..)`.
- `CodexWatcher.Workflow.Audit`: `WorkflowTickAudit (..)`,
  `workflowAuditPreCommitReports`, and `workflowAuditPostCommitReports`.
- `CodexWatcher.Workflow.EventLog.File.Core`: do not add an import unless the
  implementation discovers an existing DocsMigration line-decoding symbol from
  that owner module. The current selected scope is direct-owner convergence for
  existing symbols, not adding new file-event-log behavior.

The facade type alias `WorkflowTickAudit spec report` fixes the failure type to
`FailureClassification`. Direct `CodexWatcher.Workflow.Audit.WorkflowTickAudit`
has the spelling `WorkflowTickAudit spec failure report`, so the only expected
type-spelling adjustment is:

`WorkflowTickAudit DocsMigrationSpec FailureClassification DocsMigrationActionReport`

Do not change event labels, event JSON `type` fields, schema versions, fixture
shape, replay failure formatting, daemon audit report contents, dry-run versus
execute transaction behavior, permission validation, public exports, Cabal
exposure, docs, tests, or facade modules.

No worker fan-out is justified: the ownership is one production module plus
verification. Do not write `worker-plan.json`.

### Steps

1. Confirm the worktree and existing local edits before changing files:
   `git status --short`. Treat existing `orchestrator/state.json` or round
   artifacts as controller-owned/user-owned unless this role explicitly owns
   them.
2. Edit only `src/CodexWatcher/Workflow/DocsMigration.hs`.
3. Remove the `CodexWatcher.Workflow.EventLog` import block from
   DocsMigration.
4. Add or adjust the direct owner imports listed above. Keep the existing
   `CodexWatcher.Workflow.EventLog.Commit.Core` import if it already provides
   the required `WorkflowEventCommitter (..)`.
5. Apply the minimal audit type spelling adjustment only where the facade alias
   was previously used. Do not introduce a local compatibility alias unless a
   compile error proves it is the smallest way to preserve readability.
6. Compile or inspect enough to remove any unused imports. Do not add
   `CodexWatcher.Workflow.EventLog.File.Core` unless DocsMigration already uses
   one of its owner symbols.
7. Review the DocsMigration diff manually and confirm it contains only import
   convergence plus the required audit type spelling. If any event encoding,
   label, fixture, replay formatting, transaction, permission, export, or
   behavior body changed, revert that part of the edit before verification.
8. Leave these explicitly out of scope: `src/CodexWatcher/Daemon.hs`, tests,
   support imports, `CodexWatcher.Workflow.EventLog`,
   `CodexWatcher.Workflow.Permission`, moifold wrapper behavior, package
   descriptors, public API/Cabal exposure cleanup, docs, runtime compatibility
   files, public deprecation/removal, milestone completion, and terminal
   completion.

### Verification

Run the focused behavior gate first, then the full baseline:

1. `cabal test watcher-core-test --test-options='--match WorkflowDocsMigrationSpec.workflowDocsMigrationTests'`
   if the aggregate matcher is accepted by the current test runner. If not,
   run the equivalent focused existing DocsMigration aggregate and record the
   exact command used.
2. `cabal test watcher-core-test`
3. `cabal build all`
4. `git diff --check`

Run import and diff guards and record their results for review:

1. `rg -n 'CodexWatcher.Workflow.EventLog' src/CodexWatcher/Workflow/DocsMigration.hs`
   must return no matches.
2. `rg -n 'CodexWatcher.Workflow.EventLog' src app test docs *.cabal agent-workflow-*`
   should show only out-of-scope remaining users such as
   `src/CodexWatcher/Daemon.hs`, the facade module itself, tests/test support,
   docs/policy references, or package exposure. Do not clean those up in this
   round.
3. `git diff -- src/CodexWatcher/Workflow/DocsMigration.hs` must show no
   changes to DocsMigration event labels, JSON `"type"` fields,
   `schemaVersion`, fixture events, fixture contract values, replay failure
   text, daemon audit report logic, transaction hooks, permission validation,
   or module export list.
4. If a narrower guard is helpful, run
   `git diff -- src/CodexWatcher/Workflow/DocsMigration.hs | rg 'docs-migration-|\"type\"|schemaVersion|docsMigrationEventLogFixture|fixtureExpected|formatWorkflowReplayFailure|docsMigrationEffectAllowed|workflowTransaction|module CodexWatcher.Workflow.DocsMigration'`
   and confirm any hits are review-only context rather than behavior edits.

Run JSON state checks for later roles without editing state:

1. `jq -r '.roadmap_id, .roadmap_revision, .current_round_id // .active_round_id // empty' orchestrator/state.json`
   should still point at the active highest-value cleanup roadmap/revision and
   this round context.
2. `jq '.active_rounds // .rounds // empty' orchestrator/state.json` should not
   require planner changes for this sequential round.
3. Confirm `orchestrator/rounds/round-127/selection.md` is unchanged and no
   `orchestrator/rounds/round-127/worker-plan.json` exists.

### Worker Fan-Out

Not used. The round is a sequential one-module import-convergence plan, and
fan-out would add coordination risk without independent write ownership.
