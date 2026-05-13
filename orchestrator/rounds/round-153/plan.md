### Goal
Migrate only `test/IssueFanoutAppServerSpec.hs` from the `CodexWatcher.Core.Ids` compatibility facade to the direct GitHub id owner import for `IssueNumber`, `RepoName`, and `unIssueNumber`, preserving the existing issue-fanout app-server behavior coverage.

### Approach
Keep this as a one-file, import-only convergence slice under `direction-011-core-ids-import-convergence`. The direct owner is `CodexWatcher.Workflow.GitHub.Ids`, which owns GitHub identifiers under the package-boundary contract. Do not change constructors, parser/rendering behavior, command text, app-server protocol behavior, package descriptors, public compatibility facades, docs, runtime compatibility files, or any other test modules.

Worker fan-out is not used because the selected scope has one file, one import replacement, and no non-overlapping ownership split.

### Steps
1. In `test/IssueFanoutAppServerSpec.hs`, replace the import of `CodexWatcher.Core.Ids (IssueNumber (..), RepoName (..), unIssueNumber)` with `CodexWatcher.Workflow.GitHub.Ids (IssueNumber (..), RepoName (..), unIssueNumber)`.
2. Leave all test bodies, fixture helpers, expected child argument rendering, retry classification assertions, child-start classification assertions, JSON-RPC failure assertions, and decode-failure assertions unchanged.
3. Confirm the selected file no longer imports `CodexWatcher.Core.Ids` and still imports `IssueNumber`, `RepoName`, and `unIssueNumber` from `CodexWatcher.Workflow.GitHub.Ids`.
4. Record in implementation notes that the change is import-only, package descriptors and public facade exposure are unchanged, and broader `Core.Ids` migration, facade deprecation/removal, Cabal exposure cleanup, docs cleanup, runtime compatibility cleanup, milestone completion, terminal completion, release approval, and public compatibility removal remain out of scope.

### Verification
- `rg -n "CodexWatcher\\.Core\\.Ids|CodexWatcher\\.Workflow\\.GitHub\\.Ids|IssueNumber|RepoName|unIssueNumber" test/IssueFanoutAppServerSpec.hs`
- `rg -n "CodexWatcher\\.Core\\.Ids" test/IssueFanoutAppServerSpec.hs` should return no matches.
- `cabal test watcher-core-test`
- `cabal build all`
- `git diff --check`
- `git diff --cached --check` when staging is involved
