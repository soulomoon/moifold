### Checks Run
- Command: `cabal build all`
  Result: pass. Cabal reported all targets up to date.
- Command: `cabal test watcher-core-test`
  Result: pass. The full watcher core suite passed, including `workflow DSL DocsMigration draft-produced port preserves transition, replay, permission, and dry-run parity` and `workflow DSL issue-planning turn-completed port preserves projection, replay, permission, action, and dry-run parity`.
- Command: `git diff --check`
  Result: pass. No whitespace errors.
- Command: `git diff --cached --check`
  Result: pass. No staged whitespace errors; nothing is currently staged.
- Command: `git diff --name-status`
  Result: pass. The implementation diff is limited to `src/CodexWatcher/Workflow/DocsMigration.hs`, `src/CodexWatcher/Workflow/Moifold/IssuePlanning/Indexed.hs`, and `test/Main.hs`; `orchestrator/state.json` only carries active round controller metadata for this review state.
- Command: `rg -n "^import " agent-workflow-core/src`
  Result: pass. `agent-workflow-core` imports remain limited to generic workflow modules and base/text/list/bytestring helpers.
- Command: `rg -n "CodexWatcher\\.(Workflow\\.DocsMigration|Workflow\\.Moifold|Domain|Runtime|Daemon|ActionExecutor|EventLog|Core\\.State)|GitHub|Codex|Aeson|System\\.|liftIO|IO\\b|WatcherEvent|SomeWatcherState|DocsMigration" agent-workflow-core/src`
  Result: pass. No forbidden moifold, DocsMigration, Codex, GitHub, runtime authority, concrete event/state, Aeson codec, direct IO, or filesystem/process ownership imports were introduced in `agent-workflow-core`.
- Command: `test ! -e orchestrator/rounds/round-029/worker-plan.json; echo worker_plan_absent=$?`
  Result: pass. Output was `worker_plan_absent=0`, confirming no worker fanout plan exists.

### Plan Compliance
- Inspect existing transition code and DSL law block: met. The selected DocsMigration draft-produced transition and issue-planning turn-completed projection are the transitions ported.
- Add a pure DocsMigration DSL helper: met. `docsMigrationDraftProducedDslTransition` uses `WorkflowDSL.advance`, emits `WriteDocsMigrationDraft` then `RunDocsMigrationValidation`, returns `DocsMigrationDraftReady`, and only the selected `DocsMigrationTurnActive` plus `DocsMigrationDraftProduced` path is routed through it.
- Add a pure moifold issue-planning DSL helper: met. `projectIssuePlanningTurnCompletedDslTransition` observes the existing compatibility transition, re-authors the event/effects/state through `WorkflowDSL.advance`, preserves `IssuePlanning/PlanMode` to `IssuePlanning/Complete`, and lowers back to `IssuePlanningIndexedProjection`.
- Keep helper APIs narrow: met. The only new exports are the two selected transition helpers needed by focused tests.
- DocsMigration parity coverage: met. The test covers event, next state, pre/post partition, replay, permission acceptance/rejection, compiled action ordering, and dry-run non-execution reports.
- Moifold issue-planning parity coverage: met. The test compares DSL projection with indexed and compatibility planning, replay, permission, phase-action validation, compiled action ordering, and dry-run reports.
- Wire assertions into `workflowFacadeExtractionTests`: met. Both new parity assertions run under `watcher-core-test`.
- Keep diff within selected implementation and tests: met for implementation files. The tracked `orchestrator/state.json` change is controller activation metadata matching round-029 review state; no roadmap files, golden fixtures, codecs, compatibility facades, daemon transaction code, or interpreter behavior were changed.

### Decision
**APPROVED**

### Evidence
The two production ports preserve the old observable behavior through the existing planning, replay, permission, compile, action-order, and dry-run surfaces. `agent-workflow-core/src/CodexWatcher/Workflow/DSL.hs` remains pure planning syntax over `WorkflowSpec`; it imports no concrete moifold, DocsMigration, Codex, GitHub, runtime, daemon, filesystem, codec, or interpreter authority. The full required baseline passed: `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, and `git diff --cached --check`.
