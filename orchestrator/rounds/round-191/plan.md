### Goal
Migrate `test/WorkflowIndexedSpec.hs` off the `CodexWatcher.Core.Ids` compatibility facade by importing the identifier constructors from their direct owner modules, while preserving every indexed workflow assertion, fixture value, PASS label, runtime command expectation, event/replay expectation, and `workflowIndexedTests` aggregate entry.

### Approach
Keep this as a sequential one-file import migration. The selected file uses Codex app-server identifiers and GitHub identifiers that are owned by separate direct modules:

- `CodexWatcher.Workflow.Agent.Ids` owns `RequestId`, `ThreadId`, and `TurnId`.
- `CodexWatcher.Workflow.GitHub.Ids` owns `RepoName`, `IssueNumber`, `PrNumber`, `BranchName`, `CommitSha`, and `ReviewThreadId`.

Replace only the `CodexWatcher.Core.Ids` import in `test/WorkflowIndexedSpec.hs` with explicit direct-owner imports for those constructors. Do not change fixtures, assertion text, test labels, event schemas, replay behavior, daemon/runtime command expectations, or aggregate wiring. Do not touch runtime/CLI tests, `test/Main.hs`, `test/FacadeImportPolicySpec.hs`, source modules, docs, Cabal exposure, public facade removal, runtime compatibility files, fixture data, milestone completion, or roadmap/state files.

No worker fan-out is justified: the implementation is a single test-file import edit with shared compile/test verification, so splitting it would create coordination overhead without independent ownership boundaries.

### Steps
1. Edit `test/WorkflowIndexedSpec.hs` only in the import section.
2. Remove `import CodexWatcher.Core.Ids`.
3. Add `import CodexWatcher.Workflow.Agent.Ids (RequestId (..), ThreadId (..), TurnId (..))`.
4. Add `import CodexWatcher.Workflow.GitHub.Ids (BranchName (..), CommitSha (..), IssueNumber (..), PrNumber (..), RepoName (..), ReviewThreadId (..))`.
5. Leave all test bodies unchanged, especially fixture literals, `workflowIndexedTests`, assertion text, PASS labels, indexed projection checks, event/replay checks, and daemon dry-run/execute runtime command expectations.
6. Confirm the edited file no longer imports `CodexWatcher.Core.Ids`, and record any remaining facade imports elsewhere as out-of-scope users rather than migrating them in this round.

### Verification
Run these checks after the import edit:

1. `rg -n "CodexWatcher\\.Core\\.Ids" test/WorkflowIndexedSpec.hs`
   - Expected: no matches.
2. `rg -n "CodexWatcher\\.Core\\.Ids" test src moifold.cabal examples agent-workflow-codex agent-workflow-github`
   - Expected: `test/WorkflowIndexedSpec.hs` is absent; remaining matches, if any, are the known out-of-scope facade policy, runtime/CLI, aggregator, compatibility fixture, Cabal/public facade, or source-facade surfaces.
3. `cabal test watcher-core-test`
4. `cabal build all`
5. `git diff --check`

If staging happens later in the round, also run `git diff --cached --check`.
