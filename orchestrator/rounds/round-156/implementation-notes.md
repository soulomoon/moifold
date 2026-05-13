### Changes Made
- `test/PrReviewLaunchCliSpec.hs`: replaced the `CodexWatcher.Core.Ids` compatibility-facade import for `BranchName`, `IssueNumber`, `PrNumber`, and `RepoName` with the direct owner import from `CodexWatcher.Workflow.GitHub.Ids`.

### Tests
- `test/PrReviewLaunchCliSpec.hs`: existing PR-review launch CLI assertions were preserved unchanged; `cabal test watcher-core-test` passed and covered the launch CLI execute, dry-run endpoint rendering, runtime-owner skip, JSON-RPC failure, and decode-failure cases.

### Notes
- Focused import scan result: `rg -n "CodexWatcher\\.Core\\.Ids|CodexWatcher\\.Workflow\\.GitHub\\.Ids" test/PrReviewLaunchCliSpec.hs` reports only the direct `CodexWatcher.Workflow.GitHub.Ids` import.
- Verification run: `cabal test watcher-core-test` passed.
- Non-approval boundaries: this round did not approve or perform public facade deletion or deprecation, Cabal/package descriptor cleanup, production changes, docs changes, runtime compatibility cleanup, milestone completion, terminal completion, release approval, or package publication.
