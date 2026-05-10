# Retry Subloop Contract

Active roadmap revision:
`orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-003/`.

## Scope

- Same-round retry is allowed after rejected review when the extracted item
  remains valid and required changes stay inside the recorded `milestone_id`,
  `direction_id`, and `extracted_item_id` boundaries.
- Same-round retry is allowed when inventory evidence misses a compatibility
  surface, caller, writer, reader, fixture, repair path, healthcheck path, or
  operator/downstream path; the retry must expand the evidence rather than
  narrow the scope silently.
- Same-round retry is allowed when a policy or roadmap update overstates
  deprecation, migration, removal, publication, upload, or release readiness;
  the retry must narrow the claim to evidence-backed gates.
- Same-round retry is allowed when an import or runtime compatibility check
  fails; the retry must fix behavior or update the candidate classification
  rather than weakening scans or deleting coverage.
- Same-round retry is allowed when a final removal round discovers an
  unsupported remaining user, missing external inventory, missing fixture, or
  missing old-log evidence; the round must return to implementation or plan
  and may reclassify the surface as deferred.
- Removal is not a retry fallback. If approval is missing, the round records a
  hold or deferral; it must not remove the surface.
- Final hold/report work is retryable only as artifact evidence. A retry may
  clarify blockers, validation evidence, kept/deferred surfaces, or terminal
  hold wording, but it must not turn a held removal direction into a removal,
  deprecation, migration, publication, upload, or release approval.
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
- `REJECTED` because the plan is incomplete, skips required evidence, or
  selects removal before the gated-removal milestone returns the same round to
  `plan`.
- `REJECTED` because implementation changes compatibility behavior without
  authorization returns the same round to `implement`.
- `REJECTED` because verification evidence is missing or stale returns the
  same round to `review` after the missing checks are run.
- `REJECTED` because inventory, evidence, policy, or roadmap text overclaims
  readiness returns the same round to `implement` unless the reviewer says the
  plan must be narrowed.
- `REJECTED` because removal lacks explicit approval returns the same round to
  `plan` or records a deferral; it must not proceed as removal.
- `REJECTED` because final hold/report text overstates completion returns the
  same round to `implement` or `plan`; it must narrow the report to the
  approved hold and remaining blockers.
- `APPROVED` with all baseline and task-specific checks passing finalizes
  review and allows `merge` or `pending-merge`.

## Roadmap Revision Rule

- If an accepted `update-roadmap` stage changes future coordination,
  sequencing, milestone boundaries, cleanup policy, expansion decisions, or
  active revision metadata, author a new roadmap revision directory instead of
  rewriting a used revision.
- Future coordination or activation changes after rev-003 is used require a
  new immutable revision rather than rewriting used rev-003.
- Near the end of a roadmap list, a roadmap update must either expand
  follow-up cleanup items into a new revision or record why no expansion is
  needed before final removal work starts.
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
