### Goal
Migrate `test/RunnerGuardSpec.hs` off the `CodexWatcher.Core.Ids` compatibility facade by importing the same identifier types and accessors from their direct owner modules, while preserving all existing runner-guard assertions and leaving public compatibility surfaces untouched.

### Approach
Keep the implementation to a single import-block change in `test/RunnerGuardSpec.hs`. Replace the existing combined `CodexWatcher.Core.Ids` import with:

- `CodexWatcher.Workflow.GitHub.Ids (RepoName (..))`
- `CodexWatcher.Workflow.Agent.Ids (RequestId (..), ThreadId (..), TurnId (..), unThreadId, unTurnId)`

Do not rewrite test bodies, helpers, assertions, package descriptors, facade modules, docs, or roadmap/control-plane files. This round is import convergence only; it is not deprecation, removal, Cabal exposure cleanup, runtime compatibility cleanup, milestone completion, or terminal completion.

### Steps
1. Open `test/RunnerGuardSpec.hs` and confirm the only `CodexWatcher.Core.Ids` import is the one carrying `RepoName`, `RequestId`, `ThreadId`, `TurnId`, `unThreadId`, and `unTurnId`.
2. Replace that import with the two direct owner imports: `RepoName` from `CodexWatcher.Workflow.GitHub.Ids`, and the request/thread/turn identifiers plus accessors from `CodexWatcher.Workflow.Agent.Ids`.
3. Leave the rest of `test/RunnerGuardSpec.hs` unchanged, including runner-guard health checks, stale-turn mappings, app-server failure formatting, repair-thread launch sequence checks, request-id/thread-id/turn-id assertions, and endpoint-backed app-server assertions.
4. Confirm no files beyond `test/RunnerGuardSpec.hs` are changed by the implementation.
5. Do not create `worker-plan.json`; this is a serial one-file migration with no useful fan-out boundary.

### Verification
Run verification after the import migration:

- `cabal test watcher-core-test`
- `cabal build all`
- `git diff --check`

Review the final diff to confirm it contains only the intended import migration in `test/RunnerGuardSpec.hs` and does not alter public compatibility facade exposure, package descriptors, docs, test logic, runtime compatibility files, or orchestrator state.
