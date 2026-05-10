### Changes Made

- `orchestrator/rounds/round-073/final-compatibility-surface-report.md`:
  added the final compatibility-surface report for the approved rev-003 hold
  path, recording kept surfaces, an empty removed-surface set, deferred
  surfaces and blockers, validation evidence, new-family requirements,
  direction-024 scope, and conservative hold conclusion.
- `orchestrator/rounds/round-073/implementation-notes.md`: recorded this
  round's readbacks, evidence carried forward, no-worker-fan-out decision,
  focused checks, artifact-only baseline rationale, and no-source-change
  claim.

### Tests

Required control and evidence readbacks performed before editing:

```sh
git status --short --branch
sed -n '1,260p' orchestrator/roles/implementer.md
sed -n '1,260p' orchestrator/rounds/round-073/selection.md
sed -n '1,320p' orchestrator/rounds/round-073/plan.md
sed -n '1,260p' orchestrator/project-contract.md
sed -n '1,760p' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-003/roadmap.md
sed -n '1,320p' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-003/verification.md
sed -n '1,260p' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-003/retry-subloop.md
sed -n '1,520p' orchestrator/rounds/round-071/external-operator-downstream-inventory.md
sed -n '1,320p' orchestrator/rounds/round-071/review.md
sed -n '1,320p' orchestrator/rounds/round-071/implementation-notes.md
sed -n '1,320p' orchestrator/rounds/round-072/no-lawful-removal-surface-status.md
sed -n '1,320p' orchestrator/rounds/round-072/review.md
sed -n '1,320p' orchestrator/rounds/round-072/implementation-notes.md
```

Final verification run after writing:

```sh
git status --short --branch --untracked-files=all
sed -n '1,260p' orchestrator/rounds/round-073/selection.md
sed -n '1,320p' orchestrator/rounds/round-073/plan.md
test ! -e orchestrator/rounds/round-073/worker-plan.json
sed -n '1,260p' orchestrator/project-contract.md
sed -n '1,760p' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-003/roadmap.md
sed -n '1,320p' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-003/verification.md
sed -n '1,260p' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-003/retry-subloop.md
sed -n '1,520p' orchestrator/rounds/round-071/external-operator-downstream-inventory.md
sed -n '1,320p' orchestrator/rounds/round-072/no-lawful-removal-surface-status.md
test -f orchestrator/rounds/round-073/final-compatibility-surface-report.md
test -f orchestrator/rounds/round-073/implementation-notes.md
rg -n "no surfaces were removed|removed-surface set is empty|milestone 008|held|direction-021|direction-022|direction-024|out of scope|new family|does not approve|package publication|release|deprecation|migration|removal|Cabal exposure|production import|compatibility behavior" orchestrator/rounds/round-073/final-compatibility-surface-report.md
rg -n "CodexWatcher\\.Core\\.Ids|CodexWatcher\\.AppServerClient|CodexWatcher\\.Workflow\\.EventLog|CodexWatcher\\.Workflow\\.Permission|planning-state\\.json|repair-state\\.json|runtime-owner\\.json|daemon-state\\.json|watcher-state\\.json|checker-state\\.json|agent-state\\.json|reviewer-state\\.json|issue-state\\.json|block-state\\.json|issue-snapshot\\.json|pr_url|prUrl" orchestrator/rounds/round-073/final-compatibility-surface-report.md
git diff --name-only
git ls-files --others --exclude-standard orchestrator/rounds/round-073 | sort
git diff --check
git diff --cached --check
rg -n "[ \t]+$" orchestrator/rounds/round-073
```

Results:

- `git status --short --branch --untracked-files=all`: pass. Branch is
  `orchestrator/round-073-final-compatibility-surface-report`; untracked paths
  are limited to `orchestrator/rounds/round-073/final-compatibility-surface-report.md`,
  `orchestrator/rounds/round-073/implementation-notes.md`,
  `orchestrator/rounds/round-073/plan.md`, and
  `orchestrator/rounds/round-073/selection.md`.
- Selection, plan, project contract, rev-003 roadmap, verification contract,
  retry-subloop, round 071 inventory, and round 072 no-lawful-removal status
  readbacks: pass.
- `test ! -e orchestrator/rounds/round-073/worker-plan.json`: pass.
- `test -f orchestrator/rounds/round-073/final-compatibility-surface-report.md`
  and `test -f orchestrator/rounds/round-073/implementation-notes.md`: pass.
- Required report content greps for hold wording, empty removed-surface set,
  directions 021/022/024, new-family requirement, non-approval language, and
  all required import/runtime surfaces: pass.
- `git diff --name-only`: pass with no tracked diff output.
- `git ls-files --others --exclude-standard orchestrator/rounds/round-073 | sort`:
  pass; output is limited to the four round-local artifacts listed above.
- `git diff --check`: pass with no output.
- `git diff --cached --check`: pass with no output; no staged diff exists.
- `rg -n "[ \t]+$" orchestrator/rounds/round-073`: pass with no matches
  (exit code 1 from `rg` because no trailing-whitespace matches were found).

`cabal build all`, `cabal test watcher-core-test`, and
`scripts/validate-workflow-packages.sh` were skipped under the rev-003
artifact-only allowance because final changed-path inspection remains limited
to round-local artifacts under `orchestrator/rounds/round-073/`. No production
source, tests, scripts, fixtures, package descriptors, roadmap files,
`orchestrator/project-contract.md`, `orchestrator/state.json`, controller
artifacts, merge artifacts, review artifacts, or compatibility behavior
changed.

### Notes

No worker fan-out was used. The approved plan requires sequential
artifact-only work and does not justify `worker-plan.json`.

Evidence carried forward from round 071:

- External downstream repositories were unavailable.
- Live state archives were unavailable.
- External operator scripts were unavailable.
- Hosted CI, uploads, tags, releases, and release announcements were
  unavailable.
- Operator, reviewer, and release-gate approval evidence was blocked.
- No unsupported-user decisions were recorded.
- Every public import facade and runtime compatibility surface retained at
  least one per-surface blocker.

Evidence carried forward from round 072:

- Milestone 008 is dependency-reached but blocked/held, not removal-complete.
- `direction-021-remove-approved-import-facades` is held and not currently
  lawful.
- `direction-022-remove-approved-runtime-compatibility-surfaces` is held and
  not currently lawful.
- No exact import facade or runtime compatibility surface currently satisfies
  every active removal gate and exact reviewer approval requirement.

The final report records that the removed-surface set is empty on the approved
rev-003 hold path and that no compatibility surfaces were removed after
milestone 008 was held. It also records that further cleanup, removal,
migration, deprecation, package publication, release, Cabal exposure changes,
production import rewrites, or compatibility behavior changes require a later
selected roadmap family or exact approved removal round.

No production source, tests, scripts, fixtures, package descriptors, roadmap
files, `orchestrator/project-contract.md`, `orchestrator/state.json`,
controller artifacts, merge artifacts, review artifacts, or compatibility
behavior were changed.
