### Changes Made
- `test/ObserveCommandSpec.hs`: replaced the combined `CodexWatcher.Core.Ids` compatibility-facade import with direct owner imports from `CodexWatcher.Workflow.GitHub.Ids` for `RepoName (..)` and `CodexWatcher.Workflow.Agent.Ids` for `ThreadId (..)`, `TurnId (..)`, and `unThreadId`.

### Tests
- `test/ObserveCommandSpec.hs`: existing observe-command coverage was preserved without test-body, helper, or assertion rewrites.

### Checks
- `git diff -- test/ObserveCommandSpec.hs`: diff is limited to the import migration.
- `rg -n "CodexWatcher\\.Core\\.Ids" test/ObserveCommandSpec.hs`: no matches in the selected file.
- `cabal test watcher-core-test`: passed; 1 of 1 test suites passed.
- `git diff --check`: passed.
- `git diff --cached --check`: passed on an empty index; no files were staged.

### Notes
This round is import convergence only. It does not approve public facade deletion or deprecation, Cabal exposed-module cleanup, broader `CodexWatcher.Core.Ids` migration, runtime compatibility cleanup, milestone completion, terminal completion, release approval, or package publication.
