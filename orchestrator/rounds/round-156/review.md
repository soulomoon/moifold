### Checks Run
- Command: `cabal test watcher-core-test`
  Result: pass. `watcher-core-test` built and ran successfully; output included the selected PR-review launch CLI coverage: execute thread creation, dry-run root and non-root endpoint rendering, runtime-owner skip behavior, JSON-RPC failure formatting, and decode-failure formatting. Final result: `Test suite watcher-core-test: PASS`.
- Command: `cabal build all`
  Result: pass. The `moifold` executable built and linked successfully with GHC 9.12.2.
- Command: `git diff --check`
  Result: pass. No whitespace errors reported.
- Command: `git diff --cached --check`
  Result: pass. No staged whitespace errors reported; there are no staged changes.
- Command: `! rg -n "CodexWatcher\\.Core\\.Ids" test/PrReviewLaunchCliSpec.hs`
  Result: pass. No matches; the selected file no longer imports `CodexWatcher.Core.Ids`.
- Command: `rg -n "CodexWatcher\\.Workflow\\.GitHub\\.Ids" test/PrReviewLaunchCliSpec.hs`
  Result: pass. The selected file contains the direct owner import at line 18.
- Command: `git diff -U0 -- test/PrReviewLaunchCliSpec.hs`
  Result: pass. The selected file diff removes only the `CodexWatcher.Core.Ids` import and adds only the `CodexWatcher.Workflow.GitHub.Ids` import for `BranchName`, `IssueNumber`, `PrNumber`, and `RepoName`; no test bodies or assertions changed.
- Command: `git status --short --branch && git diff --name-status && git diff --cached --name-status && git ls-files --others --exclude-standard`
  Result: pass. Branch is `orchestrator/round-156-highest-value-cleanup-slice`. Modified tracked paths are `orchestrator/state.json` and `test/PrReviewLaunchCliSpec.hs`; there are no staged changes. Untracked round artifacts before review were `orchestrator/rounds/round-156/selection.md`, `orchestrator/rounds/round-156/plan.md`, and `orchestrator/rounds/round-156/implementation-notes.md`.
- Command: `jq -e '.decision == "approved" and .roadmap_id == "2026-05-11-00-highest-value-cleanup" and .roadmap_revision == "rev-001" and .roadmap_dir == "orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001" and .milestone_id == "milestone-003-import-convergence-package-boundaries" and .direction_id == "direction-011-core-ids-import-convergence" and .extracted_item_id == "round-156-pr-review-launch-cli-spec-github-id-direct-owner-migration" and .roadmap_item_id == "round-156-pr-review-launch-cli-spec-github-id-direct-owner-migration" and (.evidence_summary | contains("APPROVED"))' orchestrator/rounds/round-156/review-record.json`
  Result: pass. The review record is valid JSON and contains the required roadmap lineage, item identifiers, approved decision, and explicit approval evidence.

### Plan Compliance
- Confirm only in-scope `CodexWatcher.Core.Ids` use in `test/PrReviewLaunchCliSpec.hs`: met. The focused scan found no remaining `CodexWatcher.Core.Ids` reference in the selected file after the migration.
- Replace the selected import with `CodexWatcher.Workflow.GitHub.Ids`: met. The direct owner import is present and imports `BranchName`, `IssueNumber`, `PrNumber`, and `RepoName`.
- Preserve PR-review launch CLI assertions: met. The `git diff -U0 -- test/PrReviewLaunchCliSpec.hs` output shows an import-only change, and `watcher-core-test` passed the PR-review launch CLI cases.
- Avoid production, package descriptor, public facade, docs, runtime compatibility, and other test-module changes: met for implementation code. The only selected source/test diff is `test/PrReviewLaunchCliSpec.hs`; the other tracked diff is `orchestrator/state.json`, reflecting active round controller state for this review, and the untracked files are round artifacts.
- Record implementation notes: met. `orchestrator/rounds/round-156/implementation-notes.md` exists.

### Decision
**APPROVED**

### Evidence
The selected scope was an import-owner migration in `test/PrReviewLaunchCliSpec.hs`. The file now imports `BranchName`, `IssueNumber`, `PrNumber`, and `RepoName` directly from `CodexWatcher.Workflow.GitHub.Ids`, and no longer references `CodexWatcher.Core.Ids`.

The source diff for the selected file is import-only:

```diff
-import CodexWatcher.Core.Ids (BranchName (..), IssueNumber (..), PrNumber (..), RepoName (..))
+import CodexWatcher.Workflow.GitHub.Ids (BranchName (..), IssueNumber (..), PrNumber (..), RepoName (..))
```

No test bodies, helpers, assertions, production modules, package descriptors, public compatibility facades, docs, runtime compatibility files, deprecation policy, Cabal exposure, milestone status, terminal status, release approval, or package-publication approval changed in the implementation diff.

Roadmap lineage remains `2026-05-11-00-highest-value-cleanup` revision `rev-001`, milestone `milestone-003-import-convergence-package-boundaries`, direction `direction-011-core-ids-import-convergence`, extracted item `round-156-pr-review-launch-cli-spec-github-id-direct-owner-migration`. This approval is limited to the selected import convergence slice and does not approve facade deletion, deprecation, Cabal exposure cleanup, runtime compatibility cleanup, milestone completion, terminal completion, release approval, or package publication.
