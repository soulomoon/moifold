### Squash Commit
- Title: Migrate PR review launch CLI spec to direct GitHub ids
- Summary: Round 156 migrates `test/PrReviewLaunchCliSpec.hs` off the `CodexWatcher.Core.Ids` compatibility facade for its GitHub-owned `BranchName`, `IssueNumber`, `PrNumber`, and `RepoName` imports. The reviewed implementation is an import-only test-file change to `CodexWatcher.Workflow.GitHub.Ids`; PR-review launch CLI assertions, production code, package descriptors, public compatibility facades, docs, runtime compatibility files, Cabal exposure, milestone status, terminal status, release approval, and package-publication state remain unchanged.

### Merge Readiness
- Base branch freshness: confirmed. The current branch is `orchestrator/round-156-highest-value-cleanup-slice`, the base branch is `codex/workflow-facade-extraction`, and `git merge-base --is-ancestor codex/workflow-facade-extraction HEAD` succeeded with both branch tips at `e59e64d3404f8b55c2eeadb1e191d81c5363f17e`.
- Merge ordering satisfied: yes. `orchestrator/state.json` names active round `round-156`, stage `merge`, base branch `codex/workflow-facade-extraction`, `pending_merge_rounds: []`, `depends_on_round_ids: []`, `merge_after_item_ids: []`, and `merge_ready: true`.
- Pending dependencies: none.

### Follow-Up Notes
`review.md` and `review-record.json` explicitly approve the round. Recorded verification passed: `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, `git diff --cached --check`, focused import scans, and a `git diff -U0 -- test/PrReviewLaunchCliSpec.hs` check showing only the selected import replacement.

This merge decision is limited to the selected import-convergence slice under `2026-05-11-00-highest-value-cleanup/rev-001`, milestone `milestone-003-import-convergence-package-boundaries`, direction `direction-011-core-ids-import-convergence`, extracted item `round-156-pr-review-launch-cli-spec-github-id-direct-owner-migration`. It does not approve public facade deletion or deprecation, Cabal exposure cleanup, runtime compatibility cleanup, milestone completion, terminal completion, release approval, or package publication.
