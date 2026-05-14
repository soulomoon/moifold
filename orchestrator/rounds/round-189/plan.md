### Goal
Migrate only `test/WorkflowAgentSpec.hs` away from the `CodexWatcher.Core.Ids` compatibility facade by importing the direct id-owner modules, while preserving all existing workflow-agent behavior: agent adapter assertions, request/rendering expectations, turn classifier behavior, fixtures, assertion/PASS labels, aggregate wiring, and test behavior.

### Approach
Treat `CodexWatcher.Core.Ids` as the compatibility re-export facade for the two direct owner modules already used by adjacent workflow tests:

- `CodexWatcher.Workflow.Agent.Ids` owns app-server request/thread/turn identifiers and deterministic request-id progression: `RequestId`, `ThreadId`, `TurnId`, and `nextRequestId`.
- `CodexWatcher.Workflow.GitHub.Ids` owns GitHub/repo identifiers used by the spec: `RepoName`, `IssueNumber`, `PrNumber`, `BranchName`, `CommitSha`, and `ReviewThreadId`.

Keep the implementation path import-only in `test/WorkflowAgentSpec.hs`. Do not change the `workflowAgentTests` aggregate, helper functions, assertions, expected rendered app-server requests, parsed turn lifecycle expectations, classifier expectations, fixtures, PASS labels emitted through `assert`, or any surrounding workflow behavior. Do not edit `test/Main.hs`, other workflow specs, runtime/CLI tests, `FacadeImportPolicySpec`, source modules, docs, Cabal files, public facade exposure, fixture data, milestone status, or roadmap/state artifacts.

This should stay sequential. Worker fan-out is not justified because the selected scope has one file, one import ownership change, and one shared verification path; splitting it would add coordination without non-overlapping implementation ownership.

### Steps
1. Inspect the current `CodexWatcher.Core.Ids` import in `test/WorkflowAgentSpec.hs` and confirm the used identifiers are limited to agent-owned ids/progression and GitHub-owned ids.
2. Replace only `import CodexWatcher.Core.Ids` with direct owner imports:
   - `CodexWatcher.Workflow.Agent.Ids (RequestId (..), ThreadId (..), TurnId (..), nextRequestId)`
   - `CodexWatcher.Workflow.GitHub.Ids (BranchName (..), CommitSha (..), IssueNumber (..), PrNumber (..), RepoName (..), ReviewThreadId (..))`
3. Leave the rest of `test/WorkflowAgentSpec.hs` unchanged, including `workflowAgentTests`, all assertion labels, request rendering expected values, app-server turn parsing cases, PR-review role classifier cases, observation-kernel checks, and the final workflow observation law check.
4. Inspect the diff and confirm it is limited to the import ownership migration in `test/WorkflowAgentSpec.hs`; no behavior, fixture, aggregate, policy, source, docs, Cabal, or facade files should change.
5. Record the remaining `CodexWatcher.Core.Ids` users by category after the selected-file migration, separating remaining workflow specs, runtime/CLI tests, policy/aggregator candidates, docs/Cabal/public facade surfaces, and confirming no production `src` user was reintroduced.

### Verification
Run the selected-file no-facade scan:

```sh
rg -n "CodexWatcher.Core.Ids" test/WorkflowAgentSpec.hs
```

It should produce no matches. Also inspect direct-owner imports with:

```sh
rg -n "CodexWatcher.Workflow.Agent.Ids|CodexWatcher.Workflow.GitHub.Ids" test/WorkflowAgentSpec.hs
```

Run the behavior and baseline checks required for this test-import round:

```sh
cabal test watcher-core-test
cabal build all
git diff --check
```

Run a broad remaining-user classification scan and record the categories in implementation notes or review evidence:

```sh
rg -n "CodexWatcher.Core.Ids" src app test docs moifold.cabal agent-workflow-* packages 2>/dev/null || true
```

Finally inspect `git diff -- test/WorkflowAgentSpec.hs` and confirm the diff is import-only. If staging happens later, run `git diff --cached --check` before handoff.
