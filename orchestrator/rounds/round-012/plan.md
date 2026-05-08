### Goal
Prepare the next-domain indexed adoption plan after the PR-review indexed coverage is real. The round should author `orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-003/` and choose `IssuePlanning` as the next indexed domain, with concrete parity surfaces and without starting any package-boundary rewrite.

The output of the implementation round is a roadmap revision, not a code port. It must not change `orchestrator/state.json`, production source, tests, review artifacts, merge artifacts, event schemas, golden logs, daemon result shapes, dry-run rendering, or compatibility facades.

### Approach
Keep this sequential and single-owner. The selected roadmap item is explicitly not parallel-safe, and the work is a planning/revision artifact that depends on one coherent domain decision. Do not write `worker-plan.json`.

Choose `IssuePlanning` before `IssueImplement`. The current `IssuePlanning` policy is a smaller bounded lifecycle around `PlanningReady`, `PlanningTurnActive`, `PlanningWaitingForReadyIssues`, blocked, and complete. Its policy surface is concentrated in `src/CodexWatcher/Domain/IssuePlanning/Watcher.hs` with daemon normalization and snapshot behavior in `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`. It already has focused replay, watcher, daemon, automatic-loop, graph-normalization, scope, and fanout tests in `test/Main.hs`.

Defer `IssueImplement` until after `IssuePlanning` because it has a wider lifecycle and more side-effect surfaces: PR discovery/creation/reuse, PR body updates, issue plan recording, implementation worker turns, review handoff, PR merge waiting, post-merge reviewer turns, issue follow-up updates, and issue close. Those should be planned from a proven `IssuePlanning` indexed shape instead of becoming the first non-PR-review indexed port.

The new roadmap revision should keep concrete moifold policy in moifold. `agent-workflow-core` continues to own only generic indexed workflow and transaction APIs. Do not move `PlannerConfig`, `PlanningGraph`, `IssueCreationRequest`, `WatcherEvent`, `SomeWatcherState`, Aeson codecs, GitHub snapshot fetching, app-server starts, fanout launch planning, compatibility writes, daemon-loop runtime, or filesystem writes into indexed core.

### Steps
1. Re-read the active roadmap bundle and prior indexed PR-review artifacts before editing the roadmap revision: `orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-002/roadmap.md`, `orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-002/verification.md`, `orchestrator/rounds/round-010/*`, and `orchestrator/rounds/round-011/*`.
2. Inspect the current issue-planning and issue-implementation policy surfaces to justify the next-domain decision in the new roadmap: `src/CodexWatcher/Domain/IssuePlanning/Watcher.hs`, `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`, `src/CodexWatcher/Domain/IssuePlanning/Fanout.hs`, `src/CodexWatcher/Domain/IssuePlanning/Scope.hs`, `src/CodexWatcher/Domain/IssuePlanning/Graph/Canonical.hs`, `src/CodexWatcher/Domain/IssuePlanning/TurnClassifier.hs`, `src/CodexWatcher/Domain/IssueImplement/Watcher.hs`, `src/CodexWatcher/Domain/IssueImplement/Loop.hs`, `src/CodexWatcher/StateMachine.hs`, `src/CodexWatcher/Workflow/Observation.hs`, `src/CodexWatcher/Daemon.hs`, and the issue-planning/issue-implementation sections of `test/Main.hs`.
3. Create `orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-003/` by carrying forward the rev-002 verification and retry contracts, then update them only where necessary for issue-planning. Keep the roadmap id exactly `2026-05-07-00-workflow-kernel-indexing`.
4. In `rev-003/roadmap.md`, mark item 012 done with completion notes explaining the domain decision: PR-review indexed adoption has policy and one live daemon path covered; `IssuePlanning` is the next best domain because it is smaller, policy-focused, and already has graph/scope/fanout parity tests; `IssueImplement` is intentionally deferred because of its larger effect and handoff surface.
5. Add the next roadmap items as non-parallel-safe, ordered issue-planning adoption slices. Recommended sequence:
   1. `item-013-indexed-issue-planning-policy`: add an indexed issue-planning adapter covering `IssuePlanningTurnStarted`, `IssuePlanningIssuesRequested`, `IssuePlanningGraphUpdated`, `IssuePlanningReadyIssuesFixed`, `IssuePlanningScopeCompleted`, `IssuePlanningTurnRetryRequested`, `IssuePlanningTurnCompleted`, and `WatcherBlocked` from valid planning states, with invalid-observation parity.
   2. `item-014-indexed-issue-planning-daemon-start`: route the live `PlanningReady` plus `ObservedPlanningTurnStarted` daemon observation through the indexed issue-planning adapter and project back to existing moifold transaction results.
   3. `item-015-indexed-issue-planning-daemon-graph-and-requests`: route the live active-turn planning completion observations for issue creation and graph update through the indexed adapter after classifier and normalization have produced `ObservedPlanningIssuesRequested` or `ObservedPlanningGraphUpdated`.
   4. `item-016-indexed-issue-planning-terminal-and-retry-daemon`: route retry, blocked, scope-complete, ready-issues-fixed, and completed planning observations through the indexed path while preserving systemError retry behavior and completion/fanout boundaries.
   5. `item-017-indexed-issue-implementation-next-domain-plan`: after issue-planning indexed coverage is merged, inspect `IssueImplement` and author the next adoption revision for its plan/implementation/handoff/post-merge slices.
6. For each new item, name the exact parity surfaces to preserve: event label/source/target labels, final state label, pre-commit effects, post-commit effects, replay result and replay effects, effect validation, effect permissions, action ordering, request-id progression, dry-run reports, `DaemonObservedTickResult`, `DaemonObservedTransactionFailure`, compatibility writes, graph normalization results, scope validation failures, fanout completion boundary, and invalid-observation failures.
7. In `rev-003/verification.md`, keep the baseline checks from rev-002: `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, and `git diff --cached --check`. Add issue-planning-specific verification bullets for:
   - Indexed-vs-compatibility parity for every `IssuePlanningObservation`.
   - Graph validation and normalization parity, including duplicate ready issues, ready/blocked overlap, dependency-on-ready rejection, out-of-scope blocking, scoped dependency closure, closed-dependency filtering, and canonical open-scope coverage.
   - Daemon dry-run and execute parity for planning start, issue creation requests, graph update/recording, retry, completion, blocked observations, and ready-issues-fixed.
   - Preservation of `planning-state.json`, `issue-snapshot.json`, issue creation command plans, planner thread/turn starts, app-server request ids, systemError retry/block behavior, and `issuePlanningCompletionEvent`.
8. In `rev-003/retry-subloop.md`, keep the existing retry-subloop contract and add only issue-planning examples if helpful. Do not change the roadmap revision rule or worker retry defaults.
9. Inspect the final artifact diff. Expected changed files for implementation are only the three new roadmap files under `orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-003/` plus `orchestrator/rounds/round-012/implementation-notes.md` when the implementer records work. Do not edit source files, tests, golden fixtures, rev-002 files, `orchestrator/state.json`, or round review/merge artifacts during implementation.

### Verification
Because this round plans a roadmap revision rather than production behavior, verification is mostly artifact inspection:

- Confirm `orchestrator/rounds/round-012/plan.md` names `IssuePlanning` as the next domain and explicitly defers `IssueImplement`.
- Confirm no `orchestrator/rounds/round-012/worker-plan.json` exists.
- After implementation, confirm `rev-003/roadmap.md`, `rev-003/verification.md`, and `rev-003/retry-subloop.md` exist and `rev-003/roadmap.md` keeps roadmap id `2026-05-07-00-workflow-kernel-indexing`.
- Confirm the new roadmap items are ordered, non-parallel-safe, and concrete enough for dependency-aware dispatch.
- Confirm the new verification contract preserves the baseline checks from rev-002 and adds issue-planning-specific parity surfaces.
- Run `git diff --check`.
- If the implementer stages the roadmap artifacts, run `git diff --cached --check`.
