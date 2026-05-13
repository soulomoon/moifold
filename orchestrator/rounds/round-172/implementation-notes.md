### Changes Made
- `src/CodexWatcher/RunnerGuard.hs`: replaced the combined `CodexWatcher.Core.Ids` compatibility-facade import with direct owner imports from `CodexWatcher.Workflow.Agent.Ids` for `RequestId`, `ThreadId`, and `TurnId`, and `CodexWatcher.Workflow.GitHub.Ids` for `RepoName`. No function bodies, JSON field names, app-server request sequencing, thread/turn parsing, event-log replay handling, prompts, tests, Cabal files, docs, fixtures, runtime compatibility files, roadmap files, selection, plan, or the public `CodexWatcher.Core.Ids` facade were changed.

### Tests
- `git diff -- src/CodexWatcher/RunnerGuard.hs`: passed; diff is import-only and limited to replacing the `Core.Ids` import with the two direct owner imports.
- `rg -n '^import CodexWatcher\.Core\.Ids' src/CodexWatcher/RunnerGuard.hs`: passed; no matches.
- `cabal build all`: passed.
- `cabal test watcher-core-test`: passed; `1 of 1 test suites (1 of 1 test cases) passed`.
- `git diff --check`: passed.
- `git diff --cached --check`: skipped because there were no staged changes.
- `rg -n 'CodexWatcher\.Core\.Ids' src app test *.cabal docs packages 2>/dev/null || true`: completed; remaining users are intentionally outside this round and include `moifold.cabal`, `src/CodexWatcher/Core/Ids.hs`, other production modules, tests, and docs.

### Notes
This round is only `round-172-runner-guard-core-ids-split-import-migration`. Remaining `CodexWatcher.Core.Ids` users and the exposed compatibility facade are intentionally left for later reviewed rounds.
