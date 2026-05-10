### Goal

Produce the terminal cleanup gate artifact for the current rev-003 hold path.

The round should create a reviewable decision artifact at
`orchestrator/rounds/round-074/terminal-cleanup-gate.md` plus round-local
implementation notes. The decision must state whether the current
`direction-024-terminal-cleanup-gate` path closes as a reviewed terminal hold
or remains blocked, with explicit blockers and validation evidence.

On the current selected evidence, the expected decision is to close the
rev-003 compatibility-surface cleanup family as a reviewed hold. That hold is
not removal completion. It preserves milestone 008 as held, preserves the
removed-surface set as empty, carries forward round 073's kept and deferred
surfaces and blockers, and states that further cleanup requires a later
selected roadmap family or an exact approved removal round.

This round must not approve package publication, public release, upload,
deprecation, migration, removal, Cabal exposure changes, production import
rewrites, compatibility behavior changes, schema or filename changes,
event-type changes, write-timing changes, planner-turn changes, projection
changes, healthcheck changes, repair changes, replay changes, restart-script
changes, operator behavior changes, or any direction-024 action beyond this
artifact's reviewed hold decision.

### Approach

Keep the work sequential, artifact-only, and round-local. Do not use worker
fan-out and do not create `orchestrator/rounds/round-074/worker-plan.json`.

Use `orchestrator/project-contract.md` for stable compatibility invariants and
the active rev-003 roadmap bundle for current sequencing. Treat round 073's
approved final compatibility surface report, review, merge notes, and
roadmap-update review as the immediate evidence base for the terminal gate.
The terminal gate should be a conservative closeout record for the current
hold path, not a new cleanup selection.

The implementer should write only:

- `orchestrator/rounds/round-074/terminal-cleanup-gate.md`
- `orchestrator/rounds/round-074/implementation-notes.md`

The gate artifact should include a direct decision, the evidence readback that
supports it, the blockers that remain after closeout, and the exact
non-approvals. If required readbacks contradict the current evidence, the
implementer should record the contradiction as a blocker in the round-local
artifacts and keep the terminal gate held rather than inventing approval.

### Steps

1. Re-read the required control artifacts before editing:
   `orchestrator/rounds/round-074/selection.md`,
   `orchestrator/project-contract.md`,
   `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-003/roadmap.md`,
   `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-003/verification.md`,
   and
   `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-003/retry-subloop.md`.
   Confirm the selected lineage remains
   `milestone-009-close-cleanup-family` /
   `direction-024-terminal-cleanup-gate` /
   `round-074-terminal-cleanup-gate`.

2. Re-read the round 073 final-report and roadmap-update evidence:
   `orchestrator/rounds/round-073/final-compatibility-surface-report.md`,
   `orchestrator/rounds/round-073/review.md`,
   `orchestrator/rounds/round-073/review-record.json`,
   `orchestrator/rounds/round-073/merge.md`,
   `orchestrator/roadmap-updates/round-073-roadmap-update.md`, and
   `orchestrator/roadmap-updates/round-073-roadmap-update-review.md`.
   Carry forward the approved final-report evidence: milestone 008 remains
   held/not removal-complete, `direction-021` and `direction-022` remain
   held/not currently lawful, `direction-023` is complete, the removed-surface
   set is empty, and `direction-024` is the only current terminal gate scope.

3. Create
   `orchestrator/rounds/round-074/terminal-cleanup-gate.md` with these
   sections:
   - scope and non-goals;
   - required evidence readback;
   - terminal gate decision;
   - preserved hold state;
   - remaining blockers after closeout;
   - validation evidence and skipped baseline rationale;
   - further-cleanup requirement;
   - conservative conclusion.

4. In the terminal gate decision, state the direct outcome. If the readbacks
   match the current selection and round 073 evidence, use this decision:
   the current rev-003 hold path closes as a reviewed terminal hold. State
   explicitly that this is not package publication, release approval,
   deprecation, migration, removal, Cabal exposure change, production import
   rewrite, compatibility behavior change, or removal completion. If readbacks
   show missing approval, missing final-report evidence, forbidden changed
   paths, or a new unrepresented cleanup item, record the terminal gate as
   held/blocked with the exact blocker instead.

5. Preserve milestone 008 exactly as held and not removal-complete. State that
   `milestone-008-gated-compatibility-removals` remains held after round 072,
   that the hold is only a lawful predecessor for this final hold path, and
   that no exact surface currently has every removal gate plus exact reviewer
   approval.

6. Preserve the removal-direction statuses. State that
   `direction-021-remove-approved-import-facades` remains held/not currently
   lawful and that `direction-022-remove-approved-runtime-compatibility-surfaces`
   remains held/not currently lawful. Do not mark either direction complete by
   removal.

7. Preserve round 073's report outcome. State that
   `direction-023-final-compatibility-surface-report` is complete via round
   073 and commit `37cde0a`, that its removed-surface set is empty, and that
   no surfaces were removed. State that all kept/deferred public import
   facades and runtime compatibility surfaces remain available and
   behaviorally unchanged.

8. Carry forward the blockers recorded by round 073. At minimum include
   unavailable external downstream repositories, unavailable live state
   archives, unavailable external operator scripts, unavailable hosted CI,
   upload, tag, release, and announcement evidence, blocked operator/reviewer
   and release-gate approval evidence, no recorded unsupported-user decisions,
   and every per-surface blocker for the kept/deferred import facades and
   runtime compatibility surfaces.

9. State the further-cleanup rule. Further cleanup, removal, migration,
   deprecation, package publication, public release, upload, Cabal exposure
   changes, production import rewrites, or compatibility behavior changes
   require a later selected roadmap family or an exact approved removal round
   that names the surface, lists every satisfied gate, records
   unsupported-user decisions where needed, and receives reviewer approval for
   the exact evidence.

10. Write
    `orchestrator/rounds/round-074/implementation-notes.md` summarizing changed
    files, required readbacks, the terminal decision, blockers carried
    forward, whether worker fan-out was used, checks run, skipped baseline
    rationale if applicable, and the no-source-change claim.

11. Do not edit production source, tests, docs outside round-local artifacts,
    scripts, fixtures, package descriptors, roadmap files,
    `orchestrator/project-contract.md`, `orchestrator/state.json`, selection
    artifacts, controller artifacts, review artifacts, merge artifacts,
    implementation artifacts from earlier rounds, roadmap updates, or roadmap
    update reviews.

12. Do not create `orchestrator/rounds/round-074/worker-plan.json` unless a
    later rejected review explicitly requires fan-out. This plan does not
    justify fan-out.

### Verification

Run the required focused checks:

```sh
git status --short --branch --untracked-files=all
sed -n '1,260p' orchestrator/rounds/round-074/selection.md
sed -n '1,320p' orchestrator/rounds/round-074/plan.md
test ! -e orchestrator/rounds/round-074/worker-plan.json
```

Read back the required control and terminal-gate evidence:

```sh
sed -n '1,260p' orchestrator/project-contract.md
sed -n '1,760p' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-003/roadmap.md
sed -n '1,320p' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-003/verification.md
sed -n '1,260p' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-003/retry-subloop.md
sed -n '1,260p' orchestrator/rounds/round-073/final-compatibility-surface-report.md
sed -n '1,260p' orchestrator/rounds/round-073/review.md
jq . orchestrator/rounds/round-073/review-record.json
sed -n '1,260p' orchestrator/rounds/round-073/merge.md
sed -n '1,260p' orchestrator/roadmap-updates/round-073-roadmap-update.md
sed -n '1,320p' orchestrator/roadmap-updates/round-073-roadmap-update-review.md
```

After the gate artifact is written, verify required content:

```sh
test -f orchestrator/rounds/round-074/terminal-cleanup-gate.md
test -f orchestrator/rounds/round-074/implementation-notes.md
rg -n "terminal hold|reviewed hold|terminal gate|closeout|blocker|blocked|milestone 008|milestone-008|held|not removal-complete|direction-021|direction-022|direction-023|direction-024|removed-surface set is empty|no surfaces were removed|new selected roadmap family|exact approved removal round|does not approve|package publication|public release|release approval|deprecation|migration|removal|Cabal exposure|production import|compatibility behavior" orchestrator/rounds/round-074/terminal-cleanup-gate.md
rg -n "no source changes|artifact-only|skipped|cabal build all|cabal test watcher-core-test|scripts/validate-workflow-packages\\.sh|worker fan-out|not used" orchestrator/rounds/round-074/implementation-notes.md
```

Validate the artifact-only diff:

```sh
git diff --name-only
git ls-files --others --exclude-standard orchestrator/rounds/round-074 | sort
git diff --check
git diff --cached --check
rg -n "[ \t]+$" orchestrator/rounds/round-074
```

If changed paths are limited to round-local orchestrator artifacts under
`orchestrator/rounds/round-074/`, record that `cabal build all`,
`cabal test watcher-core-test`, and `scripts/validate-workflow-packages.sh`
were skipped under the rev-003 artifact-only allowance because no production
source, tests, fixtures, scripts, package descriptors, roadmap files,
`orchestrator/project-contract.md`, `orchestrator/state.json`, runtime
compatibility files, import surfaces, or compatibility behavior changed.

If any changed path escapes `orchestrator/rounds/round-074/`, stop and either
revert only the unauthorized edit you made or run the relevant full baseline
and revise the notes before review. Do not revert unrelated edits made by
others.
