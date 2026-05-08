# Retry Subloop Contract

Active roadmap revision:
`orchestrator/roadmaps/2026-05-09-00-external-package-extraction/rev-001/`.

## Scope

- Same-round retry is allowed after rejected review when the extracted item
  remains valid and required changes stay inside the recorded
  `milestone_id`, `direction_id`, and `extracted_item_id` boundaries.
- Same-round retry is allowed when package metadata, source distribution,
  Haddock, CI, or consumer validation fails and the planner can revise the
  round without changing package ownership.
- Same-round retry is allowed when a package-boundary check catches a leak; the
  retry must restore ownership rather than weakening the scan.
- Same-round retry is allowed when docs or release notes overstate publication
  status or framework ownership; the retry must narrow claims to implemented
  APIs and approved release gates.
- Publication is not a retry fallback. If a release-gate round is rejected or
  lacks explicit approval, retry may repair evidence or record blockers, but it
  must not upload packages.
- Worker-slice retry is not enabled by default. If a future plan uses
  `worker-plan.json`, retry must target the failed worker slice or integration
  pass named in that plan.
- A reviewed round may pause in `pending-merge` only when dependency ordering
  or base-branch freshness blocks immediate merge.

## Machine State

- Use `active_rounds[].resume_error` for per-round retryable failures.
- Use top-level `resume_error` only for controller-level failures.
- Use `pending_merge_rounds` for approved rounds waiting on merge ordering or
  base refresh.
- Use `roadmap_update` for delegated update-roadmap branches and artifacts.
- If worker fan-out is introduced, worker retry state must live in
  `active_rounds[].worker_records` and the round-local `worker-plan.json`.

## Review Output

- `REJECTED` because selection lineage is missing or scoped incorrectly returns
  the same round to `select-task`.
- `REJECTED` because the plan is incomplete or out of scope returns the same
  round to `plan`.
- `REJECTED` because implementation diverged from an acceptable plan returns
  the same round to `implement`.
- `REJECTED` because verification evidence is missing or stale returns the same
  round to `review` after the missing checks are run.
- `REJECTED` because package metadata, package layout, CI, docs, or release
  evidence overclaims readiness returns the same round to `implement` unless
  the reviewer says the plan must be narrowed.
- `REJECTED` because a publication action is not explicitly authorized returns
  the same round to `plan` or records a release hold; it must not proceed to
  upload.
- `APPROVED` with all baseline and task-specific checks passing finalizes
  review and allows `merge` or `pending-merge`.

## Roadmap Revision Rule

- If an accepted `update-roadmap` stage changes future coordination,
  sequencing, milestone boundaries, release policy, or active revision
  metadata, author a new roadmap revision directory instead of rewriting a used
  revision.
- Status-only updates for the just-merged round may update the active revision
  when the repo-local roadmap-update review approves that update.

## Pending-Merge Refresh

- Base-branch drift that changes touched files sends the round from
  `pending-merge` back to `implement`.
- Base-branch drift that does not change touched files sends the round back to
  `review` for baseline checks only.
- A dependency merge that invalidates the extracted item sends the round back
  to `plan`.
- Without worker fan-out, the whole-round implementer owns refresh work. With
  worker fan-out, the integration implementer owns refresh unless
  `worker-plan.json` assigns otherwise.
