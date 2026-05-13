### Checks Run
- Command: `cabal build all`
  Result: pass. Output: `Up to date`.
- Command: `cabal test watcher-core-test`
  Result: pass. Built and ran `watcher-core-test` with GHC 9.12.2; final output: `Test suite watcher-core-test: PASS` and `1 of 1 test suites (1 of 1 test cases) passed`.
- Command: `git diff --check`
  Result: pass. No whitespace errors reported.
- Command: `git diff --cached --check`
  Result: pass. No staged whitespace errors reported; no files were staged.
- Command: `! rg -n 'import CodexWatcher\.Core\.Ids' src/CodexWatcher/Domain/PrReview/Loop.hs`
  Result: pass. No `CodexWatcher.Core.Ids` import remains in the selected file.
- Command: `rg -n 'import CodexWatcher\.Workflow\.Agent\.Ids \(ThreadId\)' src/CodexWatcher/Domain/PrReview/Loop.hs`
  Result: pass. Found `27:import CodexWatcher.Workflow.Agent.Ids (ThreadId)`.
- Command: `rg -n 'import CodexWatcher\.Workflow\.GitHub\.Ids \(CommitSha, PrNumber \(\.\.\)\)' src/CodexWatcher/Domain/PrReview/Loop.hs`
  Result: pass. Found `28:import CodexWatcher.Workflow.GitHub.Ids (CommitSha, PrNumber (..))`.
- Command: `rg -n 'import CodexWatcher\.Core\.Ids' src app test`
  Result: pass as inventory evidence. Remaining out-of-scope users are still present in production, app-adjacent, and test/support modules, including `PrReview/LaunchCli.hs`, issue-planning and issue-implementation modules, runtime/healthcheck/event-log modules, CLI parser/types, and tests.
- Command: `rg -n '^ *CodexWatcher\.Core\.Ids$' moifold.cabal`
  Result: pass. Found `46:    CodexWatcher.Core.Ids`, so the compatibility facade remains exposed.
- Command: `rg -n '^ *CodexWatcher\.Workflow\.Agent\.Ids$' agent-workflow-codex/agent-workflow-codex.cabal`
  Result: pass. Found `54:    CodexWatcher.Workflow.Agent.Ids`, so the agent owner module remains exposed.
- Command: `rg -n '^ *CodexWatcher\.Workflow\.GitHub\.Ids$' agent-workflow-github/agent-workflow-github.cabal`
  Result: pass. Found `48:    CodexWatcher.Workflow.GitHub.Ids`, so the GitHub owner module remains exposed.
- Command: `git diff --name-status`
  Result: pass. Tracked diff contains only `orchestrator/state.json` and `src/CodexWatcher/Domain/PrReview/Loop.hs`.
- Command: `git ls-files --others --exclude-standard orchestrator/rounds/round-165`
  Result: pass. Round artifacts before review were `selection.md`, `plan.md`, and `implementation-notes.md`; reviewer now owns this `review.md` and `review-record.json`.
- Command: `git diff --unified=0 -- src/CodexWatcher/Domain/PrReview/Loop.hs`
  Result: pass. Diff removes only `import CodexWatcher.Core.Ids (CommitSha, PrNumber (..), ThreadId)` and adds only `CodexWatcher.Workflow.Agent.Ids (ThreadId)` plus `CodexWatcher.Workflow.GitHub.Ids (CommitSha, PrNumber (..))`.

### Plan Compliance
- Step 1, locate the existing `CodexWatcher.Core.Ids (CommitSha, PrNumber (..), ThreadId)` import: met. The source diff shows the import removed from `src/CodexWatcher/Domain/PrReview/Loop.hs`.
- Step 2, replace with direct owner imports: met. Focused scans found `CodexWatcher.Workflow.Agent.Ids (ThreadId)` and `CodexWatcher.Workflow.GitHub.Ids (CommitSha, PrNumber (..))`.
- Step 3, leave function bodies and other imports unchanged except import ordering: met. The zero-context diff for `Loop.hs` contains only the import removal and two import additions.
- Step 4, preserve review-target loading, review-thread observation, pre-merge gate handling, mergeability waiting, PR number rendering, and error text: met. `git diff --unified=0 -- src/CodexWatcher/Domain/PrReview/Loop.hs` shows no body, type signature, string literal, or rendering change. The unchanged code still contains `loadReviewTargetAndRemote`, `ObservedReviewThreads`, `runPreMergeGate`, `mergeabilityRetryWithCheckOverride`, `waiting for PR merge completion for #`, and the `GitHub reports reviewDecision=CHANGES_REQUESTED for PR #` text.
- Step 5, do not stage or edit roadmap/controller state unless assigned later: met for implementation scope. Nothing is staged. Controller state changes are present as controller-owned round state; no roadmap files, package descriptors, compatibility facades, runtime compatibility files, fixtures, tests, public exposures, event schemas, or behavior surfaces changed.
- Baseline verification from `verification.md`: met. `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, and `git diff --cached --check` all passed.
- Alignment checks: met. Lineage remains `2026-05-11-00-highest-value-cleanup` / `rev-001`; no older roadmap family was edited. The round does not treat import convergence as deprecation or removal approval. `CodexWatcher.Core.Ids` remains exposed in `moifold.cabal`, and both direct owner modules remain exposed in their package descriptors.
- Project contract: met. The package-boundary cleanup moves this selected import toward owner modules without moving moifold lifecycle policy into reusable packages and without touching event schemas, fixtures, dry-run rendering, runtime compatibility files, public compatibility facades, or package exposure.

### Decision
**APPROVED**

### Evidence
The integrated round diff is exactly the expected production import migration plus controller/round artifacts. The `Loop.hs` zero-context diff has no behavior-bearing changes: it removes the `CodexWatcher.Core.Ids` import and adds the `Workflow.Agent.Ids` and `Workflow.GitHub.Ids` owner imports. Required build, test, diff hygiene, focused import scans, remaining-user inventory, and package exposure scans all passed.
