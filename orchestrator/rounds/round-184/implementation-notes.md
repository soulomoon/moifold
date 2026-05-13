### Changes Made
- `src/CodexWatcher/Healthcheck.hs`: replaced the `CodexWatcher.Core.Ids` compatibility facade import with direct owner imports from `CodexWatcher.Workflow.Agent.Ids` for `RequestId`, `ThreadId`, and `TurnId`, and `CodexWatcher.Workflow.GitHub.Ids` for `BranchName`, `CommitSha`, `PrNumber`, and `RepoName`.

### Tests
- `cabal build all`: passed.
- `cabal test watcher-core-test`: passed. The suite compiled `HealthcheckSpec` and `RuntimeCompatibilityFixtureSpec`, and the run reported PASS evidence for healthcheck worker thread/read behavior, request id `9001`, missing endpoint/thread skips, JSON-RPC/decode failures, healthcheck planner-state reader boundaries, runtime-state read/non-read contracts, daemon/block/repair/runtime-owner/issue-snapshot source boundaries, and repair-state non-reader behavior.
- `git diff --check`: passed.
- Selected-file no-`Core.Ids` import scan: `! rg -n "import CodexWatcher\\.Core\\.Ids" src/CodexWatcher/Healthcheck.hs` passed with no matches.
- Selected-file direct-owner import scan: `rg -n "import CodexWatcher\\.Workflow\\.(Agent|GitHub)\\.Ids" src/CodexWatcher/Healthcheck.hs` found:
  - `src/CodexWatcher/Healthcheck.hs:36`: `CodexWatcher.Workflow.Agent.Ids (RequestId (..), ThreadId (..), TurnId (..))`
  - `src/CodexWatcher/Healthcheck.hs:39`: `CodexWatcher.Workflow.GitHub.Ids (BranchName (..), CommitSha (..), PrNumber (..), RepoName (..))`

### Notes
Broad remaining `CodexWatcher.Core.Ids` scan:

- Production `src` users:
  - `src/CodexWatcher/Domain/IssueImplement/Loop.hs:38`
  - `src/CodexWatcher/Domain/IssuePlanning/Loop.hs:29`
- Public facade:
  - `src/CodexWatcher/Core/Ids.hs:1`
- Tests/test-support:
  - `test/FacadeImportPolicySpec.hs:11`
  - `test/WorkflowEventLogSpec.hs:65`
  - `test/RuntimeSpec.hs:30`
  - `test/WorkflowExecutionSpec.hs:65`
  - `test/CliSpec.hs:14`
  - `test/RuntimeCompatibilityFixtureSpec.hs:11`
  - `test/WorkflowIndexedSpec.hs:66`
  - `test/Main.hs:67`
  - `test/TestSupport/Workflow.hs:98`
  - `test/WorkflowAgentSpec.hs:66`
- Docs:
  - `docs/agentic-workflow-framework/release-candidate-bundle.md:70`
  - `docs/agentic-workflow-framework/compatibility-deprecation-policy.md:60`
  - `docs/agentic-workflow-framework/compatibility-deprecation-policy.md:86`
  - `docs/agentic-workflow-framework/compatibility-deprecation-policy.md:100`
  - `docs/agentic-workflow-framework/release-notes.md:98`
- Cabal/package descriptor:
  - `moifold.cabal:46`
- `app` users: none found.

No unsafe split blocker was found. No healthcheck logic, tests, Cabal, docs, runtime compatibility fixtures, roadmap files, `selection.md`, `plan.md`, or controller state were edited.
