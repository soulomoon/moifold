### Changes Made
- `src/CodexWatcher/Workflow/DocsMigration.hs`: replaced the mixed `CodexWatcher.Workflow.EventLog` facade import with direct owner imports from `CodexWatcher.Workflow.EventLog.Core` for replay/fixture symbols and `CodexWatcher.Workflow.Audit` for `WorkflowTickAudit` plus audit field selectors.
- `src/CodexWatcher/Workflow/DocsMigration.hs`: updated `docsMigrationDaemonAudit` to use the direct audit type spelling `WorkflowTickAudit DocsMigrationSpec FailureClassification DocsMigrationActionReport`.
- `src/CodexWatcher/Workflow/DocsMigration.hs`: kept `CodexWatcher.Workflow.EventLog.Commit.Core (WorkflowEventCommitter(..))` unchanged and did not add `CodexWatcher.Workflow.EventLog.File.Core`.

### Tests
- `cabal test watcher-core-test --test-options='--match WorkflowDocsMigrationSpec.workflowDocsMigrationTests'`: passed; the focused DocsMigration matcher was accepted by the current test runner.
- `cabal test watcher-core-test`: passed.
- `cabal build all`: passed.
- `git diff --check`: passed.
- `rg -n 'CodexWatcher.Workflow.EventLog' src/CodexWatcher/Workflow/DocsMigration.hs`: returned two matches for the direct owner imports:
  - `import CodexWatcher.Workflow.EventLog.Core`
  - `import CodexWatcher.Workflow.EventLog.Commit.Core (WorkflowEventCommitter (..))`
- `rg -n '^import CodexWatcher\.Workflow\.EventLog(\s|$|qualified|\()' src/CodexWatcher/Workflow/DocsMigration.hs`: no matches, confirming the mixed `CodexWatcher.Workflow.EventLog` facade import is gone.
- `rg -n 'CodexWatcher.Workflow.EventLog' src app test docs *.cabal agent-workflow-*`: remaining matches are out of scope facade exposure, direct owner modules/imports, tests/test support, docs/policy references, `src/CodexWatcher/Daemon.hs`, `src/CodexWatcher/EventLog/File.hs`, and the new direct owner imports in DocsMigration.
- `git diff -- src/CodexWatcher/Workflow/DocsMigration.hs`: reviewed; the diff is limited to imports and the direct audit type spelling.
- `git diff -- src/CodexWatcher/Workflow/DocsMigration.hs | rg 'docs-migration-|"type"|schemaVersion|docsMigrationEventLogFixture|fixtureExpected|formatWorkflowReplayFailure|docsMigrationEffectAllowed|workflowTransaction|module CodexWatcher.Workflow.DocsMigration'`: only matched the changed import-list occurrence of `formatWorkflowReplayFailure`; no behavior-body, schema, fixture, permission, transaction, or export-list changes.
- `jq -r '.roadmap_id, .roadmap_revision, .current_round_id // .active_round_id // empty' orchestrator/state.json`: still reports `2026-05-11-00-highest-value-cleanup`, `rev-001`, and `round-127`.
- `jq '.active_rounds // .rounds // empty' orchestrator/state.json`: still reports round-127 at implement stage with `worker_mode: "none"`.

### Notes
The literal no-match guard for `CodexWatcher.Workflow.EventLog` conflicts with the approved direct-owner mapping because both `CodexWatcher.Workflow.EventLog.Core` and `CodexWatcher.Workflow.EventLog.Commit.Core` contain that substring. I kept the direct owner imports required by the plan and recorded a tighter facade-only guard above.

`orchestrator/state.json` was already modified and `orchestrator/rounds/round-127/` was already untracked before this implementation. I did not edit controller-owned state, selection, or plan files, and no `orchestrator/rounds/round-127/worker-plan.json` exists.
