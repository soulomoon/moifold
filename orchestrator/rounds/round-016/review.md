### Checks Run
- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`.
- Command: `cabal test watcher-core-test`
  Result: pass. The `watcher-core-test` suite passed, including the new indexed issue-planning projection, daemon dry-run/execute parity, invalid-routing no-commit, fanout indexed-projection, golden replay, transaction, effect metadata, runtime, and boundary assertions.
- Command: `git diff --check`
  Result: pass. No whitespace errors.
- Command: `git diff --cached --quiet; echo staged=$?`
  Result: `staged=0`; no staged changes were present.
- Command: `git diff --cached --check`
  Result: pass. No staged whitespace errors.
- Command: `rg -n "Data\\.Aeson|PlannerConfig|PlanningGraph|IssueCreationRequest|WatcherEvent|SomeWatcherState|CodexWatcher\\.Daemon|CodexWatcher\\.Runtime|CodexWatcher\\.Workflow\\.Moifold|CodexWatcher\\.Workflow\\.Agent\\.GitHub|CodexWatcher\\.AppServerClient" agent-workflow-core || true`
  Result: pass. No forbidden moifold lifecycle, daemon/runtime, adapter, Aeson, concrete watcher state, or issue-planning ownership imports were found in `agent-workflow-core`.

### Plan Compliance
- Indexed projection helpers: met. `CodexWatcher.Workflow.Moifold.IssuePlanning.Indexed` now exports helpers for ready-issues-fixed, scope-completed, retry, turn-completed, and blocked from initialized, active-turn, and waiting-ready-issues source states. The focused projection tests assert source labels, target labels, final labels, event labels, effect plans, request-id stability, replay/effect parity, and compatibility writes.
- Daemon routing: met. `prepareDaemonObservation` routes `ObservedPlanningReadyIssuesFixed`, `ObservedPlanningScopeCompleted`, `ObservedPlanningTurnRetryRequested`, `ObservedPlanningTurnCompleted`, and `ObservedPlanningBlocked` through the indexed projections for the planned source states. Other daemon observations still fall back to the compatibility path.
- Invalid observations and detailed daemon behavior: met. The new invalid terminal/retry cases compare indexed rejection text with `workflowPlanObservation @MoifoldSpec` and assert no event commit. The dry-run and execute cases preserve `DaemonObservedTickResult`, audit labels, dry-run reports, append/write ordering, compatibility writes, and post-commit effects.
- Fanout writes: met. `blockPlanningFanout` and `markPlanningReadyIssuesFixed` derive the appended event and compatibility final state from indexed projections. Dry-run text, execute append-before-write order, current-state reload, stale marker skips, and moifold-local lifecycle policy remain in `IssuePlanningFanout`.
- Item 015 graph/request behavior: met. Existing graph/request daemon routes remain behavior-compatible; the only daemon change there is use of the shared `preparedFromIssuePlanningProjection` helper. Existing and new tests continue to cover graph/request dry-run, execute, invalid graph blocked routing, request ids, action ordering, and compatibility writes.
- Completion and fanout boundaries: met. `issuePlanningCompletionEvent` remains graph-update-only, and tests continue to assert retry, completed turn, issue request, turn start, ready-issues-fixed, scope-completed, and blocked are not fanout completion events.
- Compatibility surfaces: met. Event type/schema code and golden fixtures were not changed; watcher-core golden replay, codec, replay, effect validation, effect permission, package-boundary, transaction failure, and action ordering assertions pass.

### Decision
**APPROVED**

### Evidence
The integrated diff is confined to the planned indexed adapter, daemon routing, fanout projection use, tests, and orchestrator round artifacts. The indexed adapter continues to depend on moifold-owned compatibility planning rather than moving lifecycle policy or concrete event ownership into core. The daemon path projects indexed observations back into the existing `PreparedDaemonObservation` surface, so dry-run/execute runners, `DaemonObservedTransactionFailure`, compatibility writes, audit labels, action ordering, request-id progression, and replay behavior stay on the existing transaction path.

The watcher-core output included passing assertions for the new ready-issues-fixed, scope-completed, retry, turn-completed, initialized/active/waiting blocked routes in both dry-run and execute modes; invalid terminal/retry routing; fanout terminal writes through indexed projections; existing systemError retry/block behavior; missing active turn recovery; golden replay; codec type labels; effect validation and permissions; transaction failure surfaces; and package-boundary assertions.
