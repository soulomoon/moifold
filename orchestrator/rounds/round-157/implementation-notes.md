### Changes Made
- `test/RunnerGuardSpec.hs`: replaced the `CodexWatcher.Core.Ids` compatibility-facade import with direct owner imports from `CodexWatcher.Workflow.GitHub.Ids` for `RepoName` and `CodexWatcher.Workflow.Agent.Ids` for `RequestId`, `ThreadId`, `TurnId`, `unThreadId`, and `unTurnId`.

### Tests
- `test/RunnerGuardSpec.hs`: existing runner-guard active-turn, stale-turn, app-server failure, repair-launch, request-id, thread-id, turn-id, and endpoint-backed app-server assertions were preserved without body or assertion rewrites.
- `rg -n "CodexWatcher\\.Core\\.Ids|CodexWatcher\\.Workflow\\.(Agent|GitHub)\\.Ids" test/RunnerGuardSpec.hs`: passed; only the direct owner imports remain in the selected file.
- `cabal test watcher-core-test`: passed.
- `cabal build all`: passed.
- `git diff --check`: passed.
- `git diff --cached --check`: not run because no files are staged.

### Notes
This round is import convergence only. It does not approve or perform public facade deprecation/removal, Cabal/package descriptor cleanup, docs changes, production changes, runtime compatibility cleanup, milestone completion, terminal completion, release approval, or package publication.
