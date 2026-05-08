### Checks Run
- Command: `cabal test watcher-core-test --test-options '--match indexed workflow'`
  Result: pass. The focused indexed workflow matcher completed with `Test suite watcher-core-test: PASS`; the output included the new indexed issue-planning transition, graph validation, and invalid-observation parity cases.
- Command: `cabal test watcher-core-test --test-options '--match issue planning'`
  Result: pass. The issue-planning matcher completed with `Test suite watcher-core-test: PASS`; the output included existing issue-planning and the new indexed issue-planning parity cases.
- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`.
- Command: `cabal test watcher-core-test`
  Result: pass. The full watcher core suite completed with `Test suite watcher-core-test: PASS`.
- Command: `git diff --check`
  Result: pass. No whitespace errors reported.
- Command: `git diff --cached --check`
  Result: pass. No staged whitespace errors reported.

### Plan Compliance
- Add the moifold-owned indexed adapter module for issue planning: met. `src/CodexWatcher/Workflow/Moifold/IssuePlanning/Indexed.hs` defines the issue-planning indexed markers and wrappers, and its `IndexedWorkflowSpec` instance delegates initial event, apply, observe, replay, validation, permissions, terminal checks, and labels to `MoifoldSpec`.
- Add adapter conversion helpers needed by tests: met. The adapter exposes `issuePlanningIndexedSomeEvent` and `issuePlanningIndexedTransitionToCompatibility` for replay and planned-transition parity checks.
- Add the new module to `moifold.cabal`: met. `CodexWatcher.Workflow.Moifold.IssuePlanning.Indexed` is listed beside the existing indexed PR-review modules. No new package dependency or `agent-workflow-core` facade was added.
- Add focused indexed issue-planning tests in `test/Main.hs`: met. The indexed workflow group registers issue-planning policy transition, graph validation, and invalid-observation parity tests.
- Cover all valid issue-planning policy transitions: met. Tests cover `IssuePlanningTurnStarted`, `IssuePlanningIssuesRequested`, `IssuePlanningGraphUpdated`, `IssuePlanningReadyIssuesFixed`, `IssuePlanningScopeCompleted`, `IssuePlanningTurnRetryRequested`, `IssuePlanningTurnCompleted`, and `WatcherBlocked` from ready, active, and waiting-ready-issues states.
- Cover graph validation and invalid-observation parity: met. Tests cover duplicate ready issue, duplicate blocked issue, duplicate dependency entry, ready/blocked overlap, dependency-on-ready, out-of-scope graph failure, scoped dependency closure success, and invalid observations matching `workflowObserve @MoifoldSpec` failure text.
- Preserve replay and observed effect contracts explicitly: met. The shared parity helper compares direct issue-planning observe, generic `MoifoldSpec` observe and plan, indexed observe and plan, generic/indexed apply, generic/indexed replay state and effects, effect labels, validation, permissions, and observed effects against pre/post planned effects.
- Preserve dry-run reports, action ordering, and request ids: met. The shared parity helper compares `compileEffectPlan` with `WorkflowExecution.compileWorkflowEffectPlanWithMetadata`, dry-run reports, planned action ordering, stable non-app-server request ids, and start-turn request id advancement from 900 to 901.
- Preserve compatibility writes at the resulting state boundary: met. The tests compare `compatibilityStateWrites` for compatibility and indexed final states, including graph update writes containing the same `PlanningGraph` JSON.
- Run focused validation first, then baseline validation: met. The focused indexed workflow and issue-planning matchers were run before `cabal build all`, the full watcher-core suite, and diff checks.
- Record implementation evidence in `implementation-notes.md`: met. The notes list changed source/test/cabal files and command results, and state that live daemon routing was not changed and no worker plan was used.
- No live daemon routing, event schema/golden, compatibility facade, daemon result, dry-run rendering, runtime command rendering, or `agent-workflow-core` ownership changes: met. The implementation diff is limited to cabal exposure, the new moifold adapter, and tests; no daemon routing or event codec/golden files are changed. `orchestrator/state.json` only records the active round metadata already used for review and does not contain implementation ownership.

### Decision
**APPROVED**

### Evidence
The adapter is moifold-owned and wraps compatibility types instead of moving issue-planning policy into `agent-workflow-core`. Its implementation delegates all behavior to `MoifoldSpec`, preserving compatibility semantics while adding indexed labels and conversion helpers.

The test additions exercise every listed issue-planning observation and the required blocked transitions, graph success/failure behavior, invalid-observation parity, replay/effect/permission/dry-run/request-id/action-ordering parity, and compatibility write preservation. The full required command set passed.
