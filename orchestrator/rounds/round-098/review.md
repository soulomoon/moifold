### Checks Run

- Command: `sed -n '1,240p' orchestrator/roles/reviewer.md`; `sed -n '1,260p' orchestrator/state.json`; `sed -n '1,240p' orchestrator/rounds/round-098/selection.md`; `sed -n '1,260p' orchestrator/rounds/round-098/plan.md`; `sed -n '1,260p' orchestrator/rounds/round-098/implementation-notes.md`; `sed -n '1,260p' orchestrator/project-contract.md`
  Result: pass. Reviewer role, active state, selection, plan, implementation notes, and project contract all point to `round-098` on roadmap `2026-05-11-00-highest-value-cleanup`, revision `rev-001`, for the narrow `BoundaryPolicySpec` GitHub ids import convergence.

- Command: `sed -n '1,260p' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`; `sed -n '480,590p' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`; `sed -n '1,220p' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/retry-subloop.md`
  Result: pass. Active roadmap verification requires `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, and `git diff --cached --check`; milestone 003 direction 011 allows safe `Core.Ids` user convergence without deprecation, removal, Cabal exposure changes, parser/renderer changes, or command-output changes.

- Command: `git branch --show-current`
  Result: pass. Current branch is `orchestrator/round-098-highest-value-cleanup-slice`.

- Command: `git status --short --branch`
  Result: pass for scope evidence. Tracked changes are `orchestrator/state.json` and `test/BoundaryPolicySpec.hs`; untracked round artifacts are under `orchestrator/rounds/round-098/`.

- Command: `git diff --name-status`
  Result: pass. Tracked diff is limited to `M orchestrator/state.json` and `M test/BoundaryPolicySpec.hs`.

- Command: `git ls-files --others --exclude-standard`
  Result: pass. Untracked files before this review were `orchestrator/rounds/round-098/implementation-notes.md`, `orchestrator/rounds/round-098/plan.md`, and `orchestrator/rounds/round-098/selection.md`; this review adds only `review.md` and `review-record.json` in the same round artifact directory.

- Command: `git diff --stat`
  Result: pass for tracked scope. Output was `orchestrator/state.json | 51 ++++++++++++++++++++++++++++++++++++++--------` and `test/BoundaryPolicySpec.hs | 2 +-`; no production source, package descriptor, fixtures, docs, roadmap files, or runtime compatibility files appear in the tracked diff.

- Command: `git diff -- test/BoundaryPolicySpec.hs moifold.cabal`
  Result: pass. `test/BoundaryPolicySpec.hs` has exactly one source change, replacing `import CodexWatcher.Core.Ids` with `import CodexWatcher.Workflow.GitHub.Ids`; `moifold.cabal` has no diff.

- Command: `git diff -- moifold.cabal`
  Result: pass. No output; package descriptor exposure was not changed.

- Command: `rg -n '^import[[:space:]]+(qualified[[:space:]]+)?CodexWatcher\.Core\.Ids([[:space:]]|$|\()' test/BoundaryPolicySpec.hs`
  Result: pass. Exit code 1 with no output; `BoundaryPolicySpec` no longer imports `CodexWatcher.Core.Ids`.

- Command: `rg -n '^import[[:space:]]+CodexWatcher\.Workflow\.GitHub\.Ids([[:space:]]|$|\()' test/BoundaryPolicySpec.hs`
  Result: pass. One match at line 9: `import CodexWatcher.Workflow.GitHub.Ids`.

- Command: `rg -n '\b(BranchName|CommitSha|IssueNumber|PrNumber|RepoName|ReviewThreadId|RequestId|ThreadId|TurnId|nextRequestId)\b' test/BoundaryPolicySpec.hs`
  Result: pass. Matches are limited to GitHub id tokens: `RepoName`, `IssueNumber`, `PrNumber`, `BranchName`, and `ReviewThreadId`.

- Command: `rg -n '\b(RequestId|ThreadId|TurnId|nextRequestId)\b' test/BoundaryPolicySpec.hs`
  Result: pass. Exit code 1 with no output; no agent id tokens are used.

- Command: `git diff --check`
  Result: pass. No whitespace errors.

- Command: `git diff --cached --check`
  Result: pass. No staged diff and no staged whitespace errors.

- Command: `git diff --cached --name-status`
  Result: pass. No staged files.

- Command: `cabal test watcher-core-test`
  Result: pass. The test suite reported `Test suite watcher-core-test: PASS` and `1 of 1 test suites (1 of 1 test cases) passed`.

- Command: `cabal build all`
  Result: pass. Output was `Up to date`.

### Plan Compliance

- Replace `CodexWatcher.Core.Ids` import in `test/BoundaryPolicySpec.hs`: met. The final source diff is a one-line import replacement to `CodexWatcher.Workflow.GitHub.Ids`.
- Confirm referenced ids are GitHub ids only: met. Token scan found `RepoName`, `IssueNumber`, `PrNumber`, `BranchName`, and `ReviewThreadId`; no `RequestId`, `ThreadId`, `TurnId`, or `nextRequestId` matches.
- Preserve assertions, labels, expected command arguments, helpers, and aggregation path: met. Diff in `test/BoundaryPolicySpec.hs` is only the import replacement.
- Do not edit public compatibility facade exposure or package descriptors: met. `moifold.cabal` has no diff, and the round does not claim deprecation, Cabal exposure change, or facade removal.
- Keep production, app code, fixtures, docs, roadmap files, and runtime compatibility files unchanged: met. Tracked diff is limited to controller state and the selected test file; untracked files are round artifacts only.
- Run focused scans and baselines: met. Required import scans, token scans, `git diff --check`, `git diff --cached --check`, `cabal test watcher-core-test`, and `cabal build all` all passed.

### Decision

**APPROVED**

### Evidence

The integrated round matches the selected import-convergence slice. `test/BoundaryPolicySpec.hs` no longer imports `CodexWatcher.Core.Ids`, imports `CodexWatcher.Workflow.GitHub.Ids` directly, and uses only GitHub-domain id tokens. `moifold.cabal` has no diff, so public facade exposure is unchanged.

The tracked implementation diff is exactly the selected test import replacement plus controller state. Round artifacts are confined to `orchestrator/rounds/round-098/`. Baseline verification passed with `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and `git diff --cached --check`.
