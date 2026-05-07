# Retry Subloop Contract

Active roadmap revision:
`orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-001/`.

## Scope

- Same-round retry is allowed after rejected review when the selected roadmap item remains valid and the required changes stay inside the round scope.
- Same-round retry is allowed after implementation failure when the planner can revise `plan.md` without changing `roadmap_item_id`.
- Worker-slice retry is not enabled by default. If a future plan uses `worker-plan.json`, retry must target the failed worker slice or integration pass named in that plan.
- A reviewed round may pause in `pending-merge` only when dependency ordering or base-branch freshness blocks immediate merge.

## Machine State

- Use existing `active_rounds[].resume_error` for per-round retryable failures.
- Use top-level `resume_error` only for controller-level failures.
- Use `pending_merge_rounds` for approved rounds waiting on merge ordering or base refresh.
- If worker fan-out is introduced, worker retry state must live in `active_rounds[].worker_records` and the round-local `worker-plan.json`.

## Review Output

- `REJECTED` because the plan was incomplete or scoped incorrectly returns the same round to `plan`.
- `REJECTED` because implementation diverged from an acceptable plan returns the same round to `implement`.
- `REJECTED` because verification evidence is missing or stale returns the same round to `review` after the missing checks are run.
- `APPROVED` with all baseline and task-specific checks passing finalizes review and allows `merge` or `pending-merge`.

## Roadmap Revision Rule

- If an accepted `update-roadmap` stage changes the roadmap contract
  semantically, author a new roadmap revision directory instead of rewriting a
  used revision.

## Pending-Merge Refresh

- Base-branch drift that changes touched files sends the round from `pending-merge` back to `implement`.
- Base-branch drift that does not change touched files sends the round back to `review` for baseline checks only.
- A dependency merge that invalidates the selected roadmap item sends the round back to `plan`.
- Without worker fan-out, the whole-round implementer owns refresh work. With worker fan-out, the integration implementer owns refresh unless `worker-plan.json` assigns otherwise.
