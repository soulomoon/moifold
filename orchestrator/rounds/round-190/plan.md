### Goal
Migrate `test/WorkflowExecutionSpec.hs` for milestone-004 / direction-011h item `direction-011h-workflow-execution-spec-core-ids-import` away from the `CodexWatcher.Core.Ids` facade import, while preserving the existing workflow execution test behavior, event/replay expectations, runtime command rendering expectations, fixture values, assertion text, PASS labels, aggregate wiring, and behavior.

### Approach
Keep this as a sequential, single-file import migration. The selected scope and active state both point at only `test/WorkflowExecutionSpec.hs`, and the identifier ownership is explicit enough that worker fan-out would add integration risk without useful parallelism.

Replace only the `CodexWatcher.Core.Ids` import in `test/WorkflowExecutionSpec.hs` with the direct id-owner imports:

- `CodexWatcher.Workflow.Agent.Ids (ThreadId (..), TurnId (..))`
- `CodexWatcher.Workflow.GitHub.Ids (BranchName (..), CommitSha (..), IssueNumber (..), PrNumber (..), RepoName (..), ReviewThreadId (..))`

Do not import `RequestId`; it is not used by `test/WorkflowExecutionSpec.hs`. Keep `CodexWatcher.Core.Kinds`, `CodexWatcher.Core.Limits`, `CodexWatcher.Core.Reason`, `CodexWatcher.Core.State`, and `CodexWatcher.Core.Thread` unchanged. Use `orchestrator/project-contract.md` as the shared invariant source, especially for dry-run command rendering, action ordering, replay determinism, and public facade availability.

### Steps
1. Edit only `test/WorkflowExecutionSpec.hs`.
2. Remove `import CodexWatcher.Core.Ids`.
3. Add the two direct owner imports listed above, matching the style already used by nearby migrated workflow specs.
4. Leave all test bodies, fixture literals, assertion strings, PASS labels, runtime command expected values, aggregate wiring, and helper imports unchanged.
5. Confirm the target no longer imports `CodexWatcher.Core.Ids` and does not introduce an unnecessary `RequestId` import.
6. Do not touch `test/WorkflowIndexedSpec.hs`, runtime/CLI tests, `test/Main.hs`, `test/FacadeImportPolicySpec.hs`, source modules, docs, Cabal files, roadmap files, `state.json`, public facade removal/deprecation, runtime compatibility cleanup, fixture data, or milestone completion state.

### Verification
Run the focused and baseline checks required for a test/fixture `Core.Ids` import migration:

1. `rg -n "CodexWatcher\\.Core\\.Ids" test/WorkflowExecutionSpec.hs`
   - Expected: no matches in the selected target.
2. `rg -n "\\bRequestId\\b" test/WorkflowExecutionSpec.hs`
   - Expected: no matches.
3. `rg -n "CodexWatcher\\.Core\\.Ids" test src app docs moifold.cabal agent-workflow-*`
   - Record remaining users separately; this round only eliminates the selected target and must not claim public facade removal or milestone completion.
4. `cabal test watcher-core-test`
   - This protects the workflow execution assertions, PASS labels, aggregate path through `test/Main.hs`, replay behavior, permission checks, dry-run/runtime command rendering expectations, and fixture behavior.
5. `cabal build all`
6. `git diff --check`

Run `git diff --cached --check` only if a later role stages changes. Review the diff before handoff and confirm it is limited to the import migration in `test/WorkflowExecutionSpec.hs`.
