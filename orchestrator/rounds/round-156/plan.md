### Goal
Migrate `test/PrReviewLaunchCliSpec.hs` off the `CodexWatcher.Core.Ids` compatibility facade for its existing GitHub-owned identifiers, without changing PR-review launch CLI behavior or any public compatibility surface.

### Approach
Keep this as a one-file import-owner migration. The only intended code change is to replace the current `CodexWatcher.Core.Ids (BranchName (..), IssueNumber (..), PrNumber (..), RepoName (..))` import with `CodexWatcher.Workflow.GitHub.Ids (BranchName (..), IssueNumber (..), PrNumber (..), RepoName (..))`.

Do not rewrite test bodies, helper structure, assertions, package descriptors, docs, public facade modules, or runtime compatibility code. This round is import convergence under `2026-05-11-00-highest-value-cleanup/rev-001`; it is not deprecation, removal, Cabal exposure cleanup, milestone completion, or terminal completion.

Worker fan-out is not justified: the selected scope is a single import line in one test module with no independent ownership boundaries.

### Steps
1. Open `test/PrReviewLaunchCliSpec.hs` and confirm the only in-scope `CodexWatcher.Core.Ids` use is the import of `BranchName`, `IssueNumber`, `PrNumber`, and `RepoName`.
2. Replace that import with `CodexWatcher.Workflow.GitHub.Ids (BranchName (..), IssueNumber (..), PrNumber (..), RepoName (..))`.
3. Leave all PR-review launch CLI assertions unchanged, including execute thread creation, dry-run command rendering, root and non-root endpoint handling, runtime-owner skip behavior, JSON-RPC failure formatting, and decode-failure formatting.
4. Do not edit production source, package descriptors, public compatibility facades, docs, orchestrator state, roadmap files, or any other test module.
5. Record implementation notes only after the import migration and verification are complete, if the implementer role requires them.

### Verification
Run focused checks that prove both the import migration and the PR-review launch CLI behavior are preserved:

1. `rg -n "CodexWatcher\\.Core\\.Ids|CodexWatcher\\.Workflow\\.GitHub\\.Ids" test/PrReviewLaunchCliSpec.hs`
   - Expect no `CodexWatcher.Core.Ids` import in this file.
   - Expect the direct owner import from `CodexWatcher.Workflow.GitHub.Ids`.
2. `cabal test watcher-core-test`
   - This is required because the touched file is test code and the selected behavior is covered by `watcher-core-test`.
3. `git diff --check`
   - Ensure the one-file source diff is whitespace-clean.

Do not run or report `git diff --cached --check` unless a later role stages changes.
