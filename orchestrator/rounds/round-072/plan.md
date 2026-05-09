### Goal

Produce an artifact-only no-lawful-removal status round for
`milestone-008-gated-compatibility-removals`.

The round must make reviewable that milestone 008 is dependency-reached after
round 071, but currently blocked/held for removal because no exact public import
facade or runtime compatibility surface has satisfied every removal gate and
received reviewer approval. It must not select milestone 009 prematurely.

### Approach

Keep the work sequential and artifact-only. Do not use worker fan-out.

Create `orchestrator/rounds/round-072/no-lawful-removal-surface-status.md`
and `orchestrator/rounds/round-072/implementation-notes.md`. These artifacts
should cite the active rev-002 roadmap gates, the round 071 inventory/review
evidence, and the retry-subloop rule that removal without approval records a
hold or deferral and must not remove the surface.

The status artifact should classify both milestone-008 removal directions as
not currently lawful:

- `direction-021-remove-approved-import-facades`: held because no exact import
  facade has recorded satisfied policy, follow-up evidence, external
  inventory, unsupported-user, behavior/package-boundary, and reviewer-approval
  gates.
- `direction-022-remove-approved-runtime-compatibility-surfaces`: held because
  no exact runtime compatibility file or snapshot has recorded satisfied
  old-log/golden, repair, healthcheck or non-healthcheck, runtime-owner,
  fixture, operator, write-timing, unsupported-user, and reviewer-approval
  gates.

The status artifact must preserve the round 071 conclusion: unavailable
external downstream repositories, unavailable live state archives, unavailable
external operator scripts, blocked operator/reviewer/release-gate approval
evidence, no recorded unsupported-user decisions, and per-surface blockers are
removal blockers. Local absence is not approval.

### Steps

1. Re-read the required control artifacts:
   `orchestrator/rounds/round-072/selection.md`,
   `orchestrator/project-contract.md`,
   `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/roadmap.md`,
   `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/verification.md`,
   and
   `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/retry-subloop.md`.
2. Re-read round 071 evidence:
   `orchestrator/rounds/round-071/external-operator-downstream-inventory.md`,
   `orchestrator/rounds/round-071/review.md`, and
   `orchestrator/rounds/round-071/implementation-notes.md`.
3. Write
   `orchestrator/rounds/round-072/no-lawful-removal-surface-status.md` with
   these sections:
   - scope and non-goals;
   - active roadmap gate summary for milestone 008;
   - round 071 blocker summary;
   - direction-021 classification;
   - direction-022 classification;
   - milestone-009 sequencing note;
   - conservative conclusion.
4. In the status artifact, explicitly state that milestone 008 is
   blocked/held for removal because no exact surface has passed the gates.
   Do not mark milestone 008 complete, do not select milestone 009, and do not
   imply terminal family completion.
5. In the status artifact, explicitly forbid deprecation, migration, removal,
   package publication, upload, release, Cabal exposure changes, production
   import rewrites, schema changes, filename changes, event-type changes,
   write-timing changes, planner-turn changes, projection changes, healthcheck
   changes, repair changes, replay changes, restart-script changes, and
   operator behavior changes.
6. Write `orchestrator/rounds/round-072/implementation-notes.md` summarizing
   changed files, exact readbacks, why no worker fan-out was used, why Cabal
   and package baselines were skipped or run, and the final no-source-change
   claim.
7. Do not edit source, tests, docs outside round-local artifacts, scripts,
   fixtures, package files, roadmap files, `orchestrator/project-contract.md`,
   `orchestrator/state.json`, or any controller/review/merge artifacts.
8. Do not create `orchestrator/rounds/round-072/worker-plan.json` unless a
   later rejected review explicitly requires fan-out. This plan does not
   justify fan-out.

### Verification

Run these focused checks:

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
```

Read back enough of the status artifact and implementation notes to verify the
required classifications and non-goals:

```sh
sed -n '1,320p' orchestrator/rounds/round-072/no-lawful-removal-surface-status.md
sed -n '1,220p' orchestrator/rounds/round-072/implementation-notes.md
```

Inspect changed paths:

```sh
git diff --name-only
git ls-files --others --exclude-standard orchestrator/rounds/round-072 | sort
```

If the final changed paths are limited to round-local orchestrator artifacts
under `orchestrator/rounds/round-072/`, skip `cabal build all`,
`cabal test watcher-core-test`, and `scripts/validate-workflow-packages.sh`
under the rev-002 artifact-only allowance, and record that rationale in
`implementation-notes.md`.

If any changed path escapes `orchestrator/rounds/round-072/`, stop and either
revert the unauthorized edit you made or run the relevant full baseline and
revise the plan before review. Do not revert unrelated edits made by others.
