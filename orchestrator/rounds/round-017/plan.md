### Goal
Author the artifact-only IssueImplement indexed adoption plan after issue-planning indexed coverage has merged. This round creates the next roadmap revision at `orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-004/` and keeps indexed IssueImplement implementation deferred until that revision is approved.

The round must not edit production code, tests, golden fixtures, active roadmap status in `rev-003`, `orchestrator/state.json`, daemon behavior, event schemas, dry-run output, compatibility facades, or moifold lifecycle ownership.

### Approach
Keep the work sequential and single-owner. The selected item is a planning artifact and is not parallel-safe, so do not write `worker-plan.json`.

Base the new revision on the current IssueImplement surfaces:

- `src/CodexWatcher/Domain/IssueImplement/Watcher.hs` owns `IssueImplementObservation`, `IssueFinalReviewOutcome`, and compatibility observation policy.
- `src/CodexWatcher/Domain/IssueImplement/Loop.hs` owns live PR discovery, PR create/reuse, attempt-branch advancement, PR body update, issue plan recording, implementation turn classification, review handoff, PR merge polling, post-merge reviewer thread creation, issue close retry, and follow-up handling.
- `src/CodexWatcher/StateMachine.hs` owns the concrete `IssueImplement` state transitions and effects.
- `src/CodexWatcher/DaemonLoop.hs`, `src/CodexWatcher/DaemonLoop/ActiveTurn.hs`, and `src/CodexWatcher/DaemonLoop/TurnStart.hs` own live daemon dispatch and turn-start preconditions.
- `src/CodexWatcher/Cli/Command/IssueFanout.hs`, `src/CodexWatcher/AutomaticLoop/IssuePlanningFanout.hs`, and healthcheck/runtime surfaces own issue-implementer child lifecycle and readiness discovery.
- `test/Main.hs` already has anchors for IssueImplement replay, watcher policy, classifier output schemas, effect compilation, daemon/fanout behavior, compatibility writes, and repair behavior.

The new revision should keep concrete moifold policy in moifold. A future indexed adapter may live under `src/CodexWatcher/Workflow/Moifold/IssueImplement/Indexed.hs`, but `agent-workflow-core` must not acquire `IssueConfig`, `IssueFinalReviewOutcome`, `WatcherEvent`, `SomeWatcherState`, app-server transport, GitHub command execution, daemon runtime, filesystem writes, Aeson event codecs, compatibility writes, or lifecycle policy.

### Steps
1. Re-read the active round inputs before editing artifacts: `orchestrator/state.json`, `orchestrator/roles/planner.md`, `orchestrator/rounds/round-017/selection.md`, and `rev-003/{roadmap.md,verification.md,retry-subloop.md}`.
2. Inspect the IssueImplement policy, daemon, automatic-loop, and test surfaces named above to ensure the roadmap is grounded in current code rather than inferred from prior PR-review or issue-planning shapes.
3. Create `orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-004/roadmap.md`.
   - Keep roadmap id exactly `2026-05-07-00-workflow-kernel-indexing`.
   - Set roadmap revision to `rev-004`.
   - Carry forward completed items 007-016 from `rev-003`.
   - Mark item 017 done with completion notes explaining that the new revision plans IssueImplement only and does not start implementation.
   - Add ordered, non-parallel-safe IssueImplement adoption slices for policy coverage, plan/PR setup, implementation turns, review handoff and merge waiting, post-merge review and follow-up, issue close, and final lifecycle hardening.
4. In `rev-004/roadmap.md`, make every future item preserve event JSON schemas, event `type` fields, golden logs, daemon result constructors, detailed transaction failures, dry-run text, runtime command rendering, action ordering, request-id progression, compatibility facades, compatibility writes, replay behavior, effect validation, effect permissions, and moifold-owned lifecycle boundaries.
5. Create `rev-004/verification.md` by carrying forward the baseline checks and replacing issue-planning-specific task checks with IssueImplement checks.
   - Require indexed-vs-compatibility parity for every `IssueImplementObservation` and every `IssueFinalReviewOutcome`.
   - Require daemon dry-run and execute parity for PR setup, plan mode, implementation turns, handoff, merge wait, post-merge review, follow-up, and close.
   - Require classifier coverage for structured plan, implementation, and final-review outputs.
   - Require preservation of `issue-plan.md`, `issue-state.json`, PR URL compatibility writes, app-server request ids, retry/block behavior, and child lifecycle ownership.
6. Create `rev-004/retry-subloop.md` by carrying forward the retry contract and adding IssueImplement parity examples. Keep worker-slice retry disabled by default.
7. Write this `orchestrator/rounds/round-017/plan.md` in planner format and do not create `worker-plan.json`.
8. Inspect the final diff and verify it only adds/changes planning artifacts for this round and the new roadmap revision.

### Verification
Because this round is artifact-only, do not run production build or test commands as evidence of implementation behavior. Verify the authored artifacts directly:

- Confirm `orchestrator/rounds/round-017/plan.md` exists and keeps the round artifact-only.
- Confirm `orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-004/roadmap.md`, `verification.md`, and `retry-subloop.md` exist.
- Confirm no `orchestrator/rounds/round-017/worker-plan.json` exists.
- Confirm `rev-004/roadmap.md` keeps roadmap id `2026-05-07-00-workflow-kernel-indexing`, marks item 017 done, and orders the IssueImplement slices after item 017.
- Confirm no production source, tests, golden files, `rev-003` files, or `orchestrator/state.json` were edited by this round.
- Run `git diff --check`.
- If files are staged later, run `git diff --cached --check`.
