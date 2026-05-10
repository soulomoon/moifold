### Checks Run

- Command: `git status --short --branch --untracked-files=all`
  Result: pass. Branch is `orchestrator/round-073-final-compatibility-surface-report`; changed paths before reviewer-owned files were limited to untracked round-local artifacts:
  `orchestrator/rounds/round-073/final-compatibility-surface-report.md`,
  `orchestrator/rounds/round-073/implementation-notes.md`,
  `orchestrator/rounds/round-073/plan.md`, and
  `orchestrator/rounds/round-073/selection.md`.
- Command: `sed -n '1,260p' orchestrator/rounds/round-073/selection.md`
  Result: pass. Selection lineage is `milestone-009-close-cleanup-family` /
  `direction-023-final-compatibility-surface-report` /
  `round-073-final-compatibility-surface-report`; scope is final-report
  artifact only and excludes publication, release approval, deprecation,
  migration, removal, Cabal exposure changes, production import rewrites,
  compatibility behavior changes, and terminal done.
- Command: `sed -n '1,320p' orchestrator/rounds/round-073/plan.md`
  Result: pass. Plan requires a sequential artifact-only final report, no
  worker fan-out, carried-forward blockers from rounds 071 and 072, empty
  removed-surface set, and no direction-024 decision.
- Command: `test ! -e orchestrator/rounds/round-073/worker-plan.json`
  Result: pass. No worker fan-out plan exists.
- Command: `sed -n '1,260p' orchestrator/project-contract.md`
  Result: pass. Project contract preserves event schemas, golden logs,
  public compatibility facades, runtime compatibility files, healthcheck,
  repair, write timing, and compatibility cleanup sequencing.
- Command: `sed -n '1,760p' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-003/roadmap.md`
  Result: pass. Roadmap id `2026-05-09-01-compatibility-surface-cleanup`,
  revision `rev-003`, style `strategy-backlog`, complete milestones 001-007,
  held milestone 008, and pending milestone 009 were read back. Rev-003 says
  `direction-023-final-compatibility-surface-report` is the next lawful hold
  path dispatch and that held milestone 008 is not removal completion.
- Command: `sed -n '1,320p' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-003/verification.md`
  Result: pass. Verification contract read back baseline checks,
  artifact-only skip allowance, forbidden-diff checks, hold-before-final-report
  alignment, and removal approval gates.
- Command: `sed -n '1,260p' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-003/retry-subloop.md`
  Result: pass. Retry contract allows final hold/report retry only as
  artifact evidence and forbids turning held removal directions into removal,
  deprecation, migration, publication, upload, or release approval.
- Command: `sed -n '1,520p' orchestrator/rounds/round-071/external-operator-downstream-inventory.md`
  Result: pass. Round 071 evidence records public import and runtime surface
  blockers, unavailable external downstream repositories, unavailable live
  state archives, unavailable external operator scripts, blocked approval
  evidence, no unsupported-user decisions, and per-surface blockers.
- Command: `sed -n '1,320p' orchestrator/rounds/round-071/review.md`
  Result: pass. Round 071 review approved inventory only and did not approve
  deprecation, migration, removal, publication, upload, release, Cabal
  exposure changes, production import rewrites, or compatibility behavior
  changes.
- Command: `sed -n '1,320p' orchestrator/rounds/round-071/implementation-notes.md`
  Result: pass. Notes preserve evidence-only scope, unavailable/blocked
  external evidence, skipped baseline rationale, and no production behavior
  change.
- Command: `sed -n '1,320p' orchestrator/rounds/round-072/no-lawful-removal-surface-status.md`
  Result: pass. Round 072 records milestone 008 as dependency-reached but
  blocked/held; `direction-021` and `direction-022` are not currently lawful;
  local absence is not removal approval; milestone 009 and terminal completion
  were not selected.
- Command: `sed -n '1,320p' orchestrator/rounds/round-072/review.md`
  Result: pass. Round 072 review approved only the no-lawful-removal hold
  status and preserved all removal, publication, release, Cabal, import, and
  compatibility behavior prohibitions.
- Command: `sed -n '1,320p' orchestrator/rounds/round-072/implementation-notes.md`
  Result: pass. Notes record artifact-only scope, no worker fan-out, skipped
  baseline rationale, and no-source-change claim.
- Command: `test -f orchestrator/rounds/round-073/final-compatibility-surface-report.md`
  Result: pass. Final report artifact exists.
- Command: `test -f orchestrator/rounds/round-073/implementation-notes.md`
  Result: pass. Implementation notes artifact exists.
- Command: `rg -n "no surfaces were removed|removed-surface set is empty|milestone 008|held|direction-021|direction-022|direction-024|out of scope|new family|does not approve|package publication|release|deprecation|migration|removal|Cabal exposure|production import|compatibility behavior" orchestrator/rounds/round-073/final-compatibility-surface-report.md`
  Result: pass. Matches include hold/no-removal wording at lines 26-44 and
  74-78, new-family and non-approval wording at lines 151-158, direction-024
  out-of-scope wording at lines 163-166, and conservative conclusion wording
  at lines 170-178.
- Command: `rg -n "CodexWatcher\\.Core\\.Ids|CodexWatcher\\.AppServerClient|CodexWatcher\\.Workflow\\.EventLog|CodexWatcher\\.Workflow\\.Permission|planning-state\\.json|repair-state\\.json|runtime-owner\\.json|daemon-state\\.json|watcher-state\\.json|checker-state\\.json|agent-state\\.json|reviewer-state\\.json|issue-state\\.json|block-state\\.json|issue-snapshot\\.json|pr_url|prUrl" orchestrator/rounds/round-073/final-compatibility-surface-report.md`
  Result: pass. Matches cover all required import facades at lines 52-55 and
  100-103, and all required runtime compatibility surfaces at lines 63-70 and
  109-116.
- Command: `git diff --name-only`
  Result: pass. No tracked diff output.
- Command: `git ls-files --others --exclude-standard orchestrator/rounds/round-073 | sort`
  Result: pass. Output before reviewer-owned files was limited to
  `orchestrator/rounds/round-073/final-compatibility-surface-report.md`,
  `orchestrator/rounds/round-073/implementation-notes.md`,
  `orchestrator/rounds/round-073/plan.md`, and
  `orchestrator/rounds/round-073/selection.md`.
- Command: `git diff --check`
  Result: pass with no output.
- Command: `git diff --cached --check`
  Result: pass with no output; no staged diff exists.
- Command: `rg -n "[ \t]+$" orchestrator/rounds/round-073`
  Result: pass with no matches. `rg` exited 1 because no trailing-whitespace
  matches were found.

The active verification baseline also names `cabal build all`,
`cabal test watcher-core-test`, and `scripts/validate-workflow-packages.sh`.
I skipped those under the rev-003 artifact-only allowance because changed-path
inspection before reviewer-owned files was limited to round-local artifacts
under `orchestrator/rounds/round-073/`, and no production source, tests,
fixtures, scripts, package descriptors, roadmap files,
`orchestrator/project-contract.md`, `orchestrator/state.json`, controller
artifacts, merge artifacts, or compatibility behavior changed.

### Plan Compliance

- Step 1, re-read required control artifacts and confirm lineage: met.
  Selection, project contract, rev-003 roadmap, verification contract, and
  retry-subloop were read back. The selected lineage remains
  `milestone-009-close-cleanup-family` /
  `direction-023-final-compatibility-surface-report` /
  `round-073-final-compatibility-surface-report`.
- Step 2, re-read recent hold-path evidence: met. Round 071 inventory,
  review, and implementation notes plus round 072 status, review, and
  implementation notes were read back.
- Step 3, create final report with required sections: met. The report contains
  scope/non-goals, rev-003 hold-path status, kept surfaces, removed surfaces,
  deferred surfaces/blockers, validation evidence, new-family requirement,
  direction-024 out-of-scope note, and conservative conclusion.
- Step 4, include kept public import facades and runtime compatibility
  surfaces: met. The report covers `CodexWatcher.Core.Ids`,
  `CodexWatcher.AppServerClient`, `CodexWatcher.Workflow.EventLog`,
  `CodexWatcher.Workflow.Permission`, `planning-state.json`,
  `repair-state.json`, `runtime-owner.json`, `daemon-state.json`, PR review
  state files, PR URL/state paths, `block-state.json`, and
  `issue-snapshot.json`.
- Step 5, removed-surface section says the removed set is empty and no
  surfaces were removed after milestone 008 was held: met. Lines 74-78 state
  the empty removed-surface set and no-removal-after-hold claim without
  marking milestone 008 removal-complete.
- Step 6, deferred surfaces preserve round 071 blockers: met. The report
  carries forward unavailable external downstream repositories, unavailable
  live state archives, unavailable external operator scripts, unavailable CI
  and release evidence, blocked approvals, no unsupported-user decisions, and
  per-surface blockers.
- Step 7, preserve round 072 hold status: met. The report says no exact
  import facade or runtime compatibility surface satisfies every active gate
  and exact reviewer approval, and classifies `direction-021` and
  `direction-022` as held/not currently lawful.
- Step 8, validation and skipped-baseline rationale: met. The report and
  implementation notes record focused readbacks/checks and state that Cabal
  and package baselines may be skipped only while changed paths remain
  round-local artifacts.
- Step 9, new-family requirement: met. The report says further cleanup,
  removal, migration, deprecation, package publication, release, Cabal
  exposure changes, production import rewrites, or compatibility behavior
  changes require a later selected roadmap family or exact approved removal
  round.
- Step 10, direction-024 note: met. The report says this round does not
  choose, approve, or decide `direction-024-terminal-cleanup-gate`.
- Step 11, implementation notes: met. Notes summarize changed files,
  control/readback artifacts, carried-forward evidence, no worker fan-out,
  focused checks, skipped baseline rationale, and no-source-change claim.
- Step 12, stay inside allowed artifact scope and avoid worker-plan: met.
  Changed-path checks show only round-local artifacts before reviewer-owned
  files, and `orchestrator/rounds/round-073/worker-plan.json` does not exist.

### Decision

**APPROVED**

### Evidence

The integrated round result is artifact-only and round-local. Before this
review wrote reviewer-owned artifacts, `git status --short --branch --untracked-files=all`
and `git ls-files --others --exclude-standard orchestrator/rounds/round-073 | sort`
showed only `selection.md`, `plan.md`,
`final-compatibility-surface-report.md`, and `implementation-notes.md` under
`orchestrator/rounds/round-073/`. `git diff --name-only` had no tracked
output, `git diff --check` and `git diff --cached --check` were clean, and the
round-local trailing-whitespace scan had no matches.

The report matches the rev-003 hold path. It keeps milestone 008 held rather
than removal-complete, states that no exact import facade or runtime
compatibility surface currently satisfies every removal gate and exact
reviewer approval requirement, and keeps `direction-021` and `direction-022`
held/not currently lawful.

The removed-surface set is correctly empty. The report states that no
compatibility surfaces were removed after milestone 008 was held, and it does
not turn local absence, dependency reachability, or the existence of the hold
artifact into removal approval.

The report carries forward round 071 and 072 blockers. Unavailable external
downstream repositories, live state archives, external operator scripts,
hosted CI/upload/tag/release evidence, blocked operator/reviewer/release-gate
approval, missing unsupported-user decisions, and all listed per-surface
blockers remain blockers.

The report does not approve package publication, release, deprecation,
migration, removal, Cabal exposure changes, production import rewrites,
compatibility behavior changes, or `direction-024-terminal-cleanup-gate`.
Further cleanup is explicitly deferred to a later selected roadmap family or
exact approved removal round.
