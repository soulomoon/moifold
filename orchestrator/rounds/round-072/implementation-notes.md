### Changes Made

- `orchestrator/rounds/round-072/no-lawful-removal-surface-status.md`:
  added the reviewable no-lawful-removal hold/status artifact for
  milestone 008, classifying both removal directions as currently unlawful
  because no exact surface has every gate and reviewer approval satisfied.
- `orchestrator/rounds/round-072/implementation-notes.md`: recorded the
  implementation evidence, exact readbacks/checks, no-worker-fan-out decision,
  artifact-only baseline skip rationale, and final no-source-change claim.

### Tests

No production source, tests, fixtures, scripts, docs outside round-local
artifacts, package descriptors, roadmap files, project contract, review/merge
artifacts, or controller state were changed.

Required control readbacks:

```sh
git status --short --branch --untracked-files=all
sed -n '1,240p' orchestrator/roles/implementer.md
sed -n '1,240p' orchestrator/rounds/round-072/selection.md
sed -n '1,260p' orchestrator/rounds/round-072/plan.md
sed -n '1,260p' orchestrator/project-contract.md
sed -n '1,760p' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/roadmap.md
sed -n '1,260p' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/verification.md
sed -n '1,260p' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/retry-subloop.md
sed -n '1,360p' orchestrator/rounds/round-071/external-operator-downstream-inventory.md
sed -n '1,260p' orchestrator/rounds/round-071/review.md
sed -n '1,220p' orchestrator/rounds/round-071/implementation-notes.md
```

Final verification commands:

```sh
git status --short --branch --untracked-files=all
sed -n '1,240p' orchestrator/rounds/round-072/selection.md
sed -n '1,260p' orchestrator/rounds/round-072/plan.md
test -f orchestrator/rounds/round-072/no-lawful-removal-surface-status.md
test -f orchestrator/rounds/round-072/implementation-notes.md
test ! -e orchestrator/rounds/round-072/worker-plan.json
git diff --check
git diff --cached --check
rg -n "[ \t]+$" orchestrator/rounds/round-072
sed -n '1,320p' orchestrator/rounds/round-072/no-lawful-removal-surface-status.md
sed -n '1,220p' orchestrator/rounds/round-072/implementation-notes.md
git diff --name-only
git ls-files --others --exclude-standard orchestrator/rounds/round-072 | sort
```

Cabal and package baselines were intentionally skipped under the rev-002
artifact-only allowance. Final changed-path inspection showed only untracked
round-local artifacts under `orchestrator/rounds/round-072/`:
`implementation-notes.md`, `no-lawful-removal-surface-status.md`, `plan.md`,
and `selection.md`. `plan.md` and `selection.md` were pre-existing control
inputs for this implementation; this round's implementation edits are limited
to the two owned files above. The artifact does not touch Haskell source,
tests, fixtures, package descriptors, scripts, roadmap files,
`orchestrator/project-contract.md`, or `orchestrator/state.json`.

### Notes

No worker fan-out was used because the approved plan says to keep the work
sequential and artifact-only, and no `worker-plan.json` is justified.

The hold status cites the active rev-002 removal gates, round 071's
external/operator/downstream inventory and review evidence, and the retry
subloop rule that missing approval records a hold or deferral and must not
remove the surface.

`direction-021-remove-approved-import-facades` is recorded as not currently
lawful for removal because no exact import facade has satisfied policy,
follow-up evidence, external inventory, unsupported-user, behavior,
package-boundary, and reviewer-approval gates.

`direction-022-remove-approved-runtime-compatibility-surfaces` is recorded as
not currently lawful for removal because no exact runtime compatibility file
or snapshot has satisfied old-log/golden, repair, healthcheck or
non-healthcheck, runtime-owner, fixture, operator, write-timing,
unsupported-user, and reviewer-approval gates.

Milestone 008 remains blocked and held for removal. This round does not mark
milestone 008 complete, does not select milestone 009, and does not imply
terminal family completion.

Local absence remains unavailable or blocked evidence, not removal approval.
Round 071's unavailable external downstream repositories, unavailable live
state archives, unavailable external operator scripts, blocked approval
evidence, missing unsupported-user decisions, and per-surface blockers remain
blockers.

Final no-source-change claim: the intended changed paths are only
`orchestrator/rounds/round-072/no-lawful-removal-surface-status.md` and
`orchestrator/rounds/round-072/implementation-notes.md`.
