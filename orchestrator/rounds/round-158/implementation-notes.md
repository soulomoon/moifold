### Changes Made
- `src/CodexWatcher/Cli/Parser/Observe.hs`: replaced the combined `CodexWatcher.Core.Ids` compatibility facade import with direct owner imports from `CodexWatcher.Workflow.GitHub.Ids` for `CommitSha` and `PrNumber`, and `CodexWatcher.Workflow.Agent.Ids` for `TurnId`.

### Tests
- Focused import scan: confirmed `src/CodexWatcher/Cli/Parser/Observe.hs` no longer imports `CodexWatcher.Core.Ids` and now imports the direct GitHub and agent owner modules.
- `cabal build all`: passed on serial rerun. An earlier concurrent run collided in `dist-newstyle` with `package.conf.inplace already exists`; the serial rerun completed successfully.
- `cabal test watcher-core-test`: passed on serial rerun. An earlier concurrent run collided in `dist-newstyle` with `package.conf.inplace already exists`; the serial rerun completed successfully.
- `git diff --check`: passed.
- `git diff --cached --check`: skipped because there were no staged changes.

### Notes
This round is import convergence only. It does not approve or perform public facade deletion, Cabal exposure cleanup, package descriptor changes, docs updates, runtime compatibility cleanup, command execution changes, parser behavior changes, broader `Core.Ids` migration, milestone completion, terminal completion, release approval, or public compatibility removal.
