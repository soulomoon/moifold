### Checks Run

- Command: `sed -n '1,240p' orchestrator/roles/reviewer.md`
  Result: pass. Loaded reviewer duties, output format, and the requirement to run baseline plus round-specific checks before deciding.

- Command: `sed -n '1,220p' orchestrator/state.json`
  Result: pass. Active state is `round-103` in `review` for roadmap `2026-05-11-00-highest-value-cleanup`, revision `rev-001`, milestone `milestone-003-import-convergence-package-boundaries`, direction `direction-011-core-ids-import-convergence`, extracted item `round-103-core-ids-remaining-blocker-readiness`.

- Command: `sed -n '1,260p' orchestrator/rounds/round-103/selection.md`
  Result: pass. Selection scopes the round to artifact-only `CodexWatcher.Core.Ids` remaining-blocker readiness evidence after rounds 098 through 102.

- Command: `sed -n '1,260p' orchestrator/rounds/round-103/plan.md`
  Result: pass. Plan requires live import scans, completed-candidate scans, blocker classification, package exposure checks, diff hygiene, changed-path evidence, and no source/test/package/roadmap/state behavior changes.

- Command: `sed -n '1,260p' orchestrator/rounds/round-103/implementation-notes.md`
  Result: pass. Notes report only `core-ids-remaining-blocker-readiness.md` plus implementation notes as implementer-owned changes and record artifact-only verification.

- Command: `sed -n '1,320p' orchestrator/rounds/round-103/core-ids-remaining-blocker-readiness.md`
  Result: pass. Artifact records the required lineage, inputs, commands, current counts, completed safe candidates, remaining importer classifications, no-safe-next-single-domain recommendation, and changed-path evidence.

- Command: `sed -n '1,260p' orchestrator/project-contract.md`
  Result: pass. Contract keeps public compatibility facades available, separates import convergence from deprecation/removal, and protects event logs, compatibility files, command rendering, package boundaries, and runtime behavior.

- Command: `sed -n '1,260p' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`
  Result: pass. Verification bundle allows package build/test skips only with changed-path evidence proving artifact-only scope; it also requires facade import scans and confirms `CodexWatcher.Core.Ids` remains available and exposed.

- Command: `for r in 098 099 100 101 102; do sed -n '1,160p' orchestrator/rounds/round-$r/implementation-notes.md; sed -n '1,180p' orchestrator/rounds/round-$r/review.md; done`
  Result: pass. Prior rounds show the five safe candidates were implemented and approved: `test/BoundaryPolicySpec.hs`, `src/CodexWatcher/Workflow/Execution.hs`, `src/CodexWatcher/Core/State.hs`, `app/Main.hs`, and `test/WorkflowDocsMigrationSpec.hs`.

- Command: `git status --short`
  Result: pass for scope. Output is `M orchestrator/state.json` and untracked `orchestrator/rounds/round-103/`; the state change is controller-owned and pre-existing for this review.

- Command: `git diff --name-status`
  Result: pass for tracked scope. Output is only `M orchestrator/state.json`; source, test, app, descriptor, package, roadmap, and docs files have no tracked diff.

- Command: `git ls-files --others --exclude-standard orchestrator/rounds/round-103`
  Result: pass. Untracked round files are `core-ids-remaining-blocker-readiness.md`, `implementation-notes.md`, `plan.md`, and `selection.md`; this review adds only `review.md` and `review-record.json` in the same round artifact directory.

- Command: `rg -n '^import[[:space:]]+(qualified[[:space:]]+)?CodexWatcher\.Core\.Ids([[:space:]]|$|\()' src app test agent-workflow-core agent-workflow-codex agent-workflow-github`
  Result: pass. Live scan found 39 imports, matching the artifact list.

- Command: `rg -n '^import[[:space:]]+(qualified[[:space:]]+)?CodexWatcher\.Core\.Ids([[:space:]]|$|\()' src app test agent-workflow-core agent-workflow-codex agent-workflow-github | cut -d: -f1 | awk -F/ '{count[$1]++; total++} END {for (k in count) print k, count[k]; print "total", total}'`
  Result: pass. Output: `src 29`, `test 10`, `total 39`; no `app`, `agent-workflow-core`, `agent-workflow-codex`, or `agent-workflow-github` matches.

- Command: `rg -n '^import[[:space:]]+(qualified[[:space:]]+)?CodexWatcher\.Core\.Ids([[:space:]]|$|\()' test/BoundaryPolicySpec.hs src/CodexWatcher/Workflow/Execution.hs src/CodexWatcher/Core/State.hs app/Main.hs test/WorkflowDocsMigrationSpec.hs`
  Result: pass. Exit code 1 with no output; all five prior safe candidates no longer import the facade.

- Command: `rg -n '^import[[:space:]]+CodexWatcher\.Workflow\.(GitHub|Agent)\.Ids([[:space:]]|$|\()' test/BoundaryPolicySpec.hs src/CodexWatcher/Workflow/Execution.hs src/CodexWatcher/Core/State.hs app/Main.hs test/WorkflowDocsMigrationSpec.hs`
  Result: pass. Direct owner imports are present in all five files: GitHub ids in `BoundaryPolicySpec`, `Core.State`, and `app/Main`; Agent ids in `Workflow.Execution` and `WorkflowDocsMigrationSpec`.

- Command: `rg -l '^import[[:space:]]+(qualified[[:space:]]+)?CodexWatcher\.Core\.Ids([[:space:]]|$|\()' src app test agent-workflow-core agent-workflow-codex agent-workflow-github | sort | xargs rg -n '\b(RepoName|IssueNumber|PrNumber|BranchName|ReviewThreadId|CommitSha|RequestId|ThreadId|TurnId|nextRequestId|unRepoName|unIssueNumber|unPrNumber|unBranchName|unReviewThreadId|unCommitSha|unRequestId|unThreadId|unTurnId)\b'`
  Result: pass. Token scan supports the artifact classification: remaining production importers combine agent and GitHub id surfaces or sit on parser/output, runtime compatibility, event-log/replay, prompt/classifier, or loop-policy surfaces; remaining test importers are test-policy evidence surfaces.

- Command: `rg -n 'CodexWatcher\.Core\.Ids|CodexWatcher\.Workflow\.(Agent|GitHub)\.Ids|agent-workflow-(codex|github)' moifold.cabal agent-workflow-codex/agent-workflow-codex.cabal agent-workflow-github/agent-workflow-github.cabal cabal.project`
  Result: pass. `moifold.cabal` still exposes `CodexWatcher.Core.Ids`; `agent-workflow-codex` exposes `CodexWatcher.Workflow.Agent.Ids`; `agent-workflow-github` exposes `CodexWatcher.Workflow.GitHub.Ids`; `cabal.project` includes both standalone packages.

- Command: `git diff -- moifold.cabal agent-workflow-core/agent-workflow-core.cabal agent-workflow-codex/agent-workflow-codex.cabal agent-workflow-github/agent-workflow-github.cabal cabal.project`
  Result: pass. No output; package descriptors and `cabal.project` were not changed.

- Command: `git diff -- src app test moifold.cabal cabal.project agent-workflow-core agent-workflow-codex agent-workflow-github`
  Result: pass. No output; package build/test baselines may be skipped under the artifact-only allowance.

- Command: `git diff -- orchestrator/rounds/round-103/plan.md orchestrator/rounds/round-103/core-ids-remaining-blocker-readiness.md`
  Result: pass. No tracked diff output because round artifacts are untracked; content was reviewed directly.

- Command: `test ! -e orchestrator/rounds/round-103/worker-plan.json`
  Result: pass. No worker plan was created for this no-fan-out evidence round.

- Command: `python3 -m json.tool orchestrator/state.json >/dev/null`
  Result: pass. Controller state JSON is syntactically valid.

- Command: `git diff --check`
  Result: pass. No whitespace or conflict-marker errors.

- Command: `git diff --cached --check`
  Result: pass. No staged diff hygiene errors; no staged changes.

### Plan Compliance

- Re-read coordination inputs: met. Reviewed state, selection, plan, project contract, active verification bundle, round-097 context through current artifact, and rounds 098-102 notes/reviews.
- Record starting scope: met. Live status shows only controller-owned `orchestrator/state.json` as tracked diff and untracked round-103 artifacts.
- Run current exact `CodexWatcher.Core.Ids` scan: met. Live result is 39 imports: `src` 29, `test` 10, `app` 0, standalone packages 0.
- Confirm five prior safe candidates completed: met. Facade scan over the five files has no matches; direct-owner imports are present in each file.
- Classify remaining importers and blockers: met. The artifact lists all 39 remaining files with blocker type and observed token groups; the live token scan supports the combined/blocker classification.
- Check package/public facade exposure unchanged: met. `CodexWatcher.Core.Ids` remains exposed in `moifold.cabal`, direct owner modules remain exposed by standalone packages, and descriptor diffs are empty.
- Produce required evidence artifact: met. `core-ids-remaining-blocker-readiness.md` includes scope, inputs, commands, counts, completed candidates, remaining importers, recommendation, and changed-path evidence.
- Avoid worker fan-out and implementation broadening: met. No `worker-plan.json`; no source, test, app, descriptor, package, roadmap, docs, fixture, runtime compatibility, or behavior file diffs.
- Artifact-only validation path: met. `git diff --check`, `git diff --cached --check`, changed-path checks, descriptor checks, and no-source-diff checks passed. `cabal build all` and `cabal test watcher-core-test` are skipped because changed-path evidence proves artifact-only scope.

### Decision

**APPROVED**

### Evidence

The integrated round matches the selected artifact-only readiness task. Live import scans confirm exactly 39 remaining `CodexWatcher.Core.Ids` imports: 29 under `src`, 10 under `test`, and none under `app` or the standalone package candidates. The five safe candidates from rounds 098 through 102 no longer import the facade and now use direct owner imports.

The remaining users are not safe single-domain candidates based on the live token scan and artifact classification. They are combined agent/GitHub users or sit on parser/output, runtime compatibility, event-log/replay, prompt/classifier, loop-policy, or test-policy evidence surfaces. The recommendation to close direction 011's single-domain queue and move later work to split-import or bridge-readiness slices is supported.

`CodexWatcher.Core.Ids` remains exposed and available. Package descriptors and `cabal.project` have no diff. There are no source, test, app, package, roadmap, docs, fixture, runtime compatibility, or behavior diffs; package build/test were therefore correctly skipped under the active verification bundle's artifact-only allowance.
