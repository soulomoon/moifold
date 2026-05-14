### Changes Made
- `test/CliSpec.hs`: replaced the `CodexWatcher.Core.Ids` compatibility facade import with direct owner imports from `CodexWatcher.Workflow.Agent.Ids` for `ThreadId` and `CodexWatcher.Workflow.GitHub.Ids` for `IssueNumber` and `RepoName`.

### Tests
- `test/CliSpec.hs`: existing CLI parser assertions are unchanged; the imported id constructors now come from direct owner modules.
- `test/Main.hs`: aggregate wiring was left unchanged and verified by scan.
- `rg -n "CodexWatcher\\.Core\\.Ids" test/CliSpec.hs`: no matches; command exited 1 as expected for no ripgrep matches.
- `rg -n "IssueNumber|RepoName|ThreadId|prop_cliParses|prop_cliRejects" test/CliSpec.hs test/Main.hs`: confirmed direct owner imports, CLI properties, id constructor expectations, and aggregate `quickCheckResult` wiring remain present.
- `cabal test watcher-core-test`: passed.
- `cabal build all`: passed.
- `cabal test watcher-core-test`: passed again after `cabal build all`.
- `git diff --check`: passed.
- `git diff -- test/CliSpec.hs`: inspected; diff is import-only.

### Notes
No parser assertions, expected constructors, defaults, option names, parser rejection behavior, guard-domain assertions, or `test/Main.hs` aggregate wiring were changed.
