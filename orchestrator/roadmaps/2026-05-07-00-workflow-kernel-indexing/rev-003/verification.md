# Verification Contract

Roadmap id: `2026-05-07-00-workflow-kernel-indexing`
Roadmap revision: `rev-003`

## Baseline Checks

- Command: `cabal build all`
  Why: Builds every internal library, executable, and test target across the moifold package split.
- Command: `cabal test watcher-core-test`
  Why: Runs the core regression suite, including golden replay, package-boundary, workflow-facade, daemon, execution, indexed-spec, adapter, issue-planning, graph, scope, and fanout tests.
- Command: `git diff --check`
  Why: Catches whitespace errors before review.
- Command: `git diff --cached --check`
  Why: Required when a round stages changes before review or merge.

## Task-Specific Checks

- Add focused tests for the selected roadmap item before relying on new behavior. Artifact-only roadmap rounds must instead verify the authored roadmap, verification, and retry contracts directly.
- For every indexed issue-planning port, prove old compatibility planning and indexed planning emit the same event label, source label, target label, final state label, pre-commit effect plan, post-commit effect plan, observed effects, replay result, replay effects, effect validation result, effect permission result, action ordering, request-id progression, dry-run reports, compatibility writes, and invalid-observation failures.
- Cover every `IssuePlanningObservation`: `ObservedPlanningTurnStarted`, `ObservedPlanningIssuesRequested`, `ObservedPlanningGraphUpdated`, `ObservedPlanningReadyIssuesFixed`, `ObservedPlanningScopeCompleted`, `ObservedPlanningTurnRetryRequested`, `ObservedPlanningTurnCompleted`, and `ObservedPlanningBlocked`.
- For graph validation and normalization, preserve duplicate ready issue rejection, duplicate blocked issue rejection, duplicate dependency entry rejection, ready/blocked overlap rejection, dependency-on-ready rejection, out-of-scope blocking, scoped dependency closure, closed-dependency filtering, canonical open-scope coverage, and fallback behavior when canonicalization cannot fetch facts.
- For daemon dry-run and execute routing, prove parity for planning start, issue creation requests, graph update and recording, retry, completion, blocked observations, scope completion, and ready-issues-fixed.
- Preserve `planning-state.json`, `issue-snapshot.json`, issue creation command plans, planner thread starts, planner turn starts, app-server request ids, systemError retry/block behavior, missing active turn retry/block behavior, and `issuePlanningCompletionEvent`.
- Preserve fanout boundaries: ready-issue launch planning, stopped implementer restarts, terminal ready-issue completion, active-issue capacity, scope filtering, and the point where graph update is considered a planning completion event.
- For daemon routing rounds, prove `DaemonTickResult`, `DaemonObservedTickResult`, `DaemonObservedTransactionFailure`, detailed transaction failure text, dry-run reports, action ordering, audit labels, and compatibility write timing remain compatible.
- For package-boundary-adjacent rounds, keep recursive boundary assertions passing: `agent-workflow-core` must not import moifold lifecycle policy, `PlannerConfig`, `PlanningGraph`, `IssueCreationRequest`, Codex app-server transport, GitHub adapters, daemon/runtime interpreters, Aeson event codecs, concrete `WatcherEvent`, or concrete `SomeWatcherState` ownership.
- Do not change event `type` fields, JSON schemas, golden fixtures, public compatibility module availability, daemon result constructors, dry-run rendering, or runtime command rendering unless a later roadmap item explicitly says so.

## Approval Criteria

- Every baseline check passes, except artifact-only planning rounds may run only artifact verification and must document why production build/test commands were not run.
- Every selected task-specific check passes.
- `selection.md` records `roadmap_id`, `roadmap_revision`, `roadmap_dir`, and `roadmap_item_id`.
- `implementation-notes.md` records changed files and verification evidence.
- `review.md` records evidence for the round.
- `review-record.json` records the same roadmap identity when the round finalizes.
- The round stays inside the active roadmap bundle recorded in `orchestrator/state.json`.
- The round's `roadmap_id` is exactly `2026-05-07-00-workflow-kernel-indexing`, not a recomputed title-derived value.
- If worker fan-out is used later, `worker-plan.json` must exist and reviewer approval must be based on the integrated round result.
- The reviewer decision is explicit.

## Reviewer Record Format

### Round `<round-id>`

- Baseline checks:
- Task-specific checks:
- Decision:
- Evidence:
