### Goal
Migrate only `test/WorkflowEventLogSpec.hs` away from the `CodexWatcher.Core.Ids` compatibility facade by importing the direct id-owner modules, while preserving the existing event-log assertions, golden fixture checks, PASS labels, aggregate wiring, event JSON expectations, and behavior.

### Approach
Treat `CodexWatcher.Core.Ids` as a re-export facade for the two direct id-owner modules already used throughout the repo:

- `CodexWatcher.Workflow.Agent.Ids` owns app-server `ThreadId` and `TurnId`.
- `CodexWatcher.Workflow.GitHub.Ids` owns GitHub/repo identifiers used by the spec: `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, `RepoName`, and `ReviewThreadId`.

Keep the change to the selected file's imports only. Do not change assertions, helper names, fixture paths, canonical event examples, JSON `type` expectations, `workflowEventLogTests`, `test/Main.hs`, source modules, Cabal files, docs, fixtures, facade policy tests, or any public facade exposure. This is a sequential single-file slice; worker fan-out is not justified because the ownership boundary is one import block plus one compile/test feedback loop.

### Steps
1. In `test/WorkflowEventLogSpec.hs`, remove `import CodexWatcher.Core.Ids`.
2. Add direct owner imports for the ids used by this spec:
   - `CodexWatcher.Workflow.Agent.Ids (ThreadId (..), TurnId (..))`
   - `CodexWatcher.Workflow.GitHub.Ids (BranchName (..), CommitSha (..), IssueNumber (..), PrNumber (..), RepoName (..), ReviewThreadId (..))`
3. Leave all event-log tests and fixtures unchanged, including `goldenEventLogFixturePaths`, `canonicalEventExamples`, all `assert` labels, JSON `type` field checks, replay/fixture contract checks, and the `workflowEventLogTests` aggregate.
4. Inspect the final diff and confirm it is limited to the selected spec's import ownership migration. Do not edit `test/Main.hs`, other workflow specs, runtime/CLI tests, policy specs, source modules, docs, fixtures, or package descriptors.

### Verification
Run the selected-file import scan:

```sh
rg -n "CodexWatcher.Core.Ids" test/WorkflowEventLogSpec.hs
```

It should produce no matches. Then run the behavior and baseline checks required by the active verification bundle for a test import change:

```sh
cabal test watcher-core-test
cabal build all
git diff --check
```

Also inspect `git diff -- test/WorkflowEventLogSpec.hs` and confirm the only intended behavioral surface touched is the import block. If staging is performed later, run `git diff --cached --check` before handoff.
