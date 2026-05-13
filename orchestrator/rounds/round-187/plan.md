### Goal

Migrate only `test/TestSupport/Workflow.hs` away from the `CodexWatcher.Core.Ids` compatibility facade by replacing that import with direct owner imports, while preserving the helper module's exported API, fixtures, assertions, PASS labels, and downstream workflow-test behavior.

### Approach

Use a one-file, import-only change. `TestSupport.Workflow` currently gets agent request/thread/turn ids and GitHub repo/issue/PR/branch/review-thread/commit ids from `CodexWatcher.Core.Ids`; those names are owned by `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`.

Do not edit workflow specs, runtime/CLI tests, `test/Main.hs`, `test/FacadeImportPolicySpec.hs`, source modules, docs, Cabal files, roadmap files, state files, or the public facade. Do not use worker fan-out; this is a single-file serial slice.

### Steps

1. Open `test/TestSupport/Workflow.hs` and confirm the only planned edit is the import currently reading `import CodexWatcher.Core.Ids`.
2. Replace that import with explicit direct owner imports:
   - `CodexWatcher.Workflow.Agent.Ids (RequestId (..), ThreadId, TurnId (..))`
   - `CodexWatcher.Workflow.GitHub.Ids (BranchName (..), CommitSha (..), IssueNumber (..), PrNumber (..), RepoName, ReviewThreadId (..))`
3. Do not change exports, helper definitions, fixture text/JSON, assertion strings, PASS/FAIL labels, QuickCheck properties, fake executor behavior, aggregate wiring, or formatting outside the import block.
4. Build and test. If compilation proves an imported name list is too narrow, widen only the direct owner import list needed by `test/TestSupport/Workflow.hs`; do not restore the facade unless direct-owner imports are unsafe.
5. If direct-owner compilation fails because the test suite cannot lawfully depend on the owner modules without Cabal/package changes, revert the import-only edit and classify `test/TestSupport/Workflow.hs` as blocked by package exposure/dependency evidence. Record the exact compiler error in implementation notes.
6. If evidence shows this helper intentionally imports `CodexWatcher.Core.Ids` as facade policy evidence, revert the import-only edit and classify the retained import as policy evidence with the exact reason. Do not weaken or move policy coverage.
7. If any behavior evidence changes after the import migration, revert the behavior-impacting change and keep this round to either a safe import-only migration or an explicit unsafe/classified result.

### Verification

Run baseline validation:

1. `cabal build all`
2. `cabal test watcher-core-test`
3. `git diff --check`

Run selected-file import evidence after a successful migration:

1. `rg -n "CodexWatcher\\.Core\\.Ids" test/TestSupport/Workflow.hs` and record that it has no matches.
2. `rg -n "CodexWatcher\\.Workflow\\.(Agent|GitHub)\\.Ids" test/TestSupport/Workflow.hs` and record the direct owner imports.

Run broad remaining `Core.Ids` classification:

1. `rg -n "CodexWatcher\\.Core\\.Ids" test src app moifold.cabal docs agent-workflow-codex agent-workflow-github -g '*.hs' -g '*.md' -g '*.cabal'`
2. Classify remaining matches separately as tests/fixtures, public facade (`src/CodexWatcher/Core/Ids.hs`), docs, or Cabal exposure. Confirm there are no production users beyond the public facade module.
3. For test/fixture matches, separate later workflow specs, runtime/CLI tests, `test/Main.hs`, and `test/FacadeImportPolicySpec.hs`; do not migrate them in this round.

Record focused workflow test-support behavior evidence:

1. The final diff for `test/TestSupport/Workflow.hs` is import-only.
2. `cabal test watcher-core-test` still reaches the workflow helper assertions through the existing aggregate wiring and reports the existing PASS labels without edits.
3. The helper API remains source-compatible for downstream tests: exported helper names stay unchanged, fixture builders keep the same output shape, assertion helpers keep their PASS/FAIL text, and fake executor call recording remains unchanged.
