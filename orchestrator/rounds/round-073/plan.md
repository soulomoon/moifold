### Goal

Produce the final compatibility surface report for the approved rev-003 hold
path.

The round should create a reviewable artifact at
`orchestrator/rounds/round-073/final-compatibility-surface-report.md` plus
round-local implementation notes. The report must record kept, removed, and
deferred compatibility surfaces, validation evidence, blockers carried forward
from rounds 071 and 072, and whether any further cleanup requires a new roadmap
family.

This is an artifact-only report round. It must state that no compatibility
surfaces were removed after milestone 008 was held. It must not approve package
publication, release, deprecation, migration, removal, Cabal exposure changes,
production import rewrites, compatibility behavior changes, terminal cleanup
completion, or direction 024.

### Approach

Keep the work sequential and round-local. Do not use worker fan-out.

Use `orchestrator/project-contract.md` for stable compatibility invariants and
the active rev-003 roadmap bundle for the current hold path. Treat round 071's
external operator/downstream inventory and round 072's approved
no-lawful-removal status as carried-forward blockers, not as removal approval.

The implementer should write one final report artifact and one implementation
notes artifact:

- `orchestrator/rounds/round-073/final-compatibility-surface-report.md`
- `orchestrator/rounds/round-073/implementation-notes.md`

The report should be a conservative closeout record for
`direction-023-final-compatibility-surface-report`. It should summarize the
surfaces that remain kept, the removed-surface set as empty on the approved
hold path, and deferred surfaces whose blockers remain unresolved. It should
not select or decide `direction-024-terminal-cleanup-gate`; that terminal gate
is explicitly out of scope for this round.

### Steps

1. Re-read the required control artifacts before editing:
   `orchestrator/rounds/round-073/selection.md`,
   `orchestrator/project-contract.md`,
   `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-003/roadmap.md`,
   `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-003/verification.md`,
   and
   `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-003/retry-subloop.md`.
   Confirm the selected lineage remains
   `milestone-009-close-cleanup-family` /
   `direction-023-final-compatibility-surface-report` /
   `round-073-final-compatibility-surface-report`.

2. Re-read the recent hold-path evidence:
   `orchestrator/rounds/round-071/external-operator-downstream-inventory.md`,
   `orchestrator/rounds/round-071/review.md`,
   `orchestrator/rounds/round-071/implementation-notes.md`,
   `orchestrator/rounds/round-072/no-lawful-removal-surface-status.md`,
   `orchestrator/rounds/round-072/review.md`, and
   `orchestrator/rounds/round-072/implementation-notes.md`.
   Carry forward their unavailable external evidence, blocked approval
   evidence, missing unsupported-user decisions, and per-surface blockers.

3. Create
   `orchestrator/rounds/round-073/final-compatibility-surface-report.md` with
   these sections:
   - scope and non-goals;
   - rev-003 hold-path status;
   - kept compatibility surfaces;
   - removed compatibility surfaces;
   - deferred compatibility surfaces and blockers;
   - validation evidence and skipped baseline rationale;
   - new-family requirement for further cleanup;
   - direction-024 out-of-scope note;
   - conservative conclusion.

4. In the kept-surfaces section, include the current kept public import
   facades and runtime compatibility surfaces from rounds 071 and 072. At
   minimum cover `CodexWatcher.Core.Ids`,
   `CodexWatcher.AppServerClient`,
   `CodexWatcher.Workflow.EventLog`,
   `CodexWatcher.Workflow.Permission`,
   `planning-state.json`, `repair-state.json`, `runtime-owner.json`,
   `daemon-state.json`, PR review compatibility state files, PR URL/state
   paths, `block-state.json`, and `issue-snapshot.json`.

5. In the removed-surfaces section, state that the removed-surface set is
   empty on the approved rev-003 hold path and that no surfaces were removed
   after milestone 008 was held. Do not imply that held milestone 008 is
   removal-complete.

6. In the deferred-surfaces section, summarize why each surface remains
   deferred or blocked. Preserve round 071 blockers: unavailable external
   downstream repositories, unavailable live state archives, unavailable
   external operator scripts, unavailable hosted CI/upload/tag/release evidence,
   blocked operator/reviewer/release-gate approval evidence, no recorded
   unsupported-user decisions, and every per-surface blocker recorded there.

7. Preserve round 072's hold status. State that no exact import facade or
   runtime compatibility surface currently satisfies every active removal gate
   and exact reviewer approval requirement. Classify `direction-021` and
   `direction-022` as held/not currently lawful, not as completed removal work.

8. Add a validation section that records the focused checks the implementer
   runs and the rev-003 artifact-only baseline rationale. If changed paths
   remain limited to round-local artifacts under
   `orchestrator/rounds/round-073/`, the implementer may skip
   `cabal build all`, `cabal test watcher-core-test`, and
   `scripts/validate-workflow-packages.sh` under the rev-003 artifact-only
   allowance. If any changed path escapes round-local artifacts, require the
   relevant full baseline before review.

9. Add a new-family section that says further cleanup, removal, migration,
   deprecation, package publication, release, Cabal exposure changes,
   production import rewrites, or compatibility behavior changes require a
   later selected roadmap family or exact approved removal round. Do not make
   that selection in this report.

10. Add a direction-024 note that this round does not choose, approve, or
    decide the terminal cleanup gate. It only prepares the report artifact that
    a later terminal gate can read.

11. Write
    `orchestrator/rounds/round-073/implementation-notes.md` summarizing changed
    files, control/readback artifacts, evidence carried forward, whether worker
    fan-out was used, checks run, skipped baseline rationale if applicable, and
    the no-source-change claim.

12. Do not edit production source, tests, docs outside round-local artifacts,
    scripts, fixtures, package descriptors, roadmap files,
    `orchestrator/project-contract.md`, `orchestrator/state.json`, controller
    artifacts, merge artifacts, or review artifacts. Do not create
    `orchestrator/rounds/round-073/worker-plan.json` unless a later rejected
    review explicitly requires fan-out; this plan does not justify fan-out.

### Verification

Run the required focused checks:

```sh
git status --short --branch --untracked-files=all
sed -n '1,260p' orchestrator/rounds/round-073/selection.md
sed -n '1,320p' orchestrator/rounds/round-073/plan.md
test ! -e orchestrator/rounds/round-073/worker-plan.json
```

Read back the required control and hold-path evidence:

```sh
sed -n '1,260p' orchestrator/project-contract.md
sed -n '1,760p' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-003/roadmap.md
sed -n '1,320p' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-003/verification.md
sed -n '1,260p' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-003/retry-subloop.md
sed -n '1,520p' orchestrator/rounds/round-071/external-operator-downstream-inventory.md
sed -n '1,320p' orchestrator/rounds/round-072/no-lawful-removal-surface-status.md
```

After the report is written, verify required report content:

```sh
test -f orchestrator/rounds/round-073/final-compatibility-surface-report.md
test -f orchestrator/rounds/round-073/implementation-notes.md
rg -n "no surfaces were removed|removed-surface set is empty|milestone 008|held|direction-021|direction-022|direction-024|out of scope|new family|does not approve|package publication|release|deprecation|migration|removal|Cabal exposure|production import|compatibility behavior" orchestrator/rounds/round-073/final-compatibility-surface-report.md
rg -n "CodexWatcher\\.Core\\.Ids|CodexWatcher\\.AppServerClient|CodexWatcher\\.Workflow\\.EventLog|CodexWatcher\\.Workflow\\.Permission|planning-state\\.json|repair-state\\.json|runtime-owner\\.json|daemon-state\\.json|watcher-state\\.json|checker-state\\.json|agent-state\\.json|reviewer-state\\.json|issue-state\\.json|block-state\\.json|issue-snapshot\\.json|pr_url|prUrl" orchestrator/rounds/round-073/final-compatibility-surface-report.md
```

Validate the artifact-only diff:

```sh
git diff --name-only
git ls-files --others --exclude-standard orchestrator/rounds/round-073 | sort
git diff --check
git diff --cached --check
rg -n "[ \t]+$" orchestrator/rounds/round-073
```

If changed paths are limited to
`orchestrator/rounds/round-073/selection.md`,
`orchestrator/rounds/round-073/plan.md`,
`orchestrator/rounds/round-073/final-compatibility-surface-report.md`, and
`orchestrator/rounds/round-073/implementation-notes.md`, record that
`cabal build all`, `cabal test watcher-core-test`, and
`scripts/validate-workflow-packages.sh` were skipped under the rev-003
artifact-only allowance. If any changed path escapes that round-local set, run
the relevant full baseline and update the notes before review.
