### Goal

Migrate only `test/RuntimeSpec.hs` for
`direction-011i-runtime-spec-core-ids-import` from the
`CodexWatcher.Core.Ids` compatibility facade to direct id-owner imports, while
preserving the existing runtime command rendering, default-option, process,
GitHub/Git command assertions, PASS labels, and `test/Main.hs` aggregate
wiring.

### Approach

Make an import-only ownership change in `test/RuntimeSpec.hs`. Replace the
single `CodexWatcher.Core.Ids` import with direct imports from
`CodexWatcher.Workflow.Agent.Ids` for `ThreadId` and
`CodexWatcher.Workflow.GitHub.Ids` for `BranchName`, `CommitSha`,
`IssueNumber`, `PrNumber`, `RepoName`, and `ReviewThreadId`.

Keep all test declarations, runtime command examples, assertion bodies,
expected rendered command text, default-option checks, process checks, PASS
labels, and exported `RuntimeSpec` symbols unchanged. Do not touch
`test/RuntimeCompatibilityFixtureSpec.hs`, `test/FacadeImportPolicySpec.hs`,
`test/Main.hs`, production source, docs, Cabal exposure, public facade
availability, runtime compatibility fixture data, or roadmap state.

This follows `orchestrator/project-contract.md` by treating command rendering,
dry-run output, app-server defaults, process behavior, public compatibility
facades, and fixture semantics as stable contracts. It also follows the active
roadmap `2026-05-11-00-highest-value-cleanup` `rev-002` milestone 004 boundary:
this is a test import-burndown step, not public deprecation, removal,
milestone completion, policy classification, or runtime compatibility cleanup.

### Steps

1. In `test/RuntimeSpec.hs`, replace the `CodexWatcher.Core.Ids` import list
   with:
   - `CodexWatcher.Workflow.Agent.Ids (ThreadId (..))`
   - `CodexWatcher.Workflow.GitHub.Ids (BranchName (..), CommitSha (..), IssueNumber (..), PrNumber (..), RepoName (..), ReviewThreadId (..))`
2. Do not change any value definitions, property names, exported symbols,
   command examples, expected argument lists, expected stdin text, default
   option assertions, process assertions, PASS/FAIL label strings, or aggregate
   test wiring.
3. Inspect the resulting diff to confirm it is import-only in
   `test/RuntimeSpec.hs`.
4. Confirm the selected file no longer imports `CodexWatcher.Core.Ids` and does
   import the two direct owner modules.
5. Record remaining `CodexWatcher.Core.Ids` users as out-of-scope evidence:
   expected remaining test users are `test/RuntimeCompatibilityFixtureSpec.hs`,
   `test/FacadeImportPolicySpec.hs`, and `test/Main.hs`, plus docs, Cabal
   exposure, and `src/CodexWatcher/Core/Ids.hs` for later roadmap work.

### Verification

Run the focused and baseline checks appropriate for this test import-burndown
slice:

- `rg -n "CodexWatcher\\.Core\\.Ids" test/RuntimeSpec.hs`
- `rg -n "CodexWatcher\\.Workflow\\.(Agent|GitHub)\\.Ids" test/RuntimeSpec.hs`
- `git diff -- test/RuntimeSpec.hs`
- `rg -n "CodexWatcher\\.Core\\.Ids" src app test docs moifold.cabal`
- `cabal build all`
- `cabal test watcher-core-test`
- `git diff --check`

If staging is performed later, also run `git diff --cached --check`.
