### Goal
Migrate `test/CliSpec.hs` off the `CodexWatcher.Core.Ids` compatibility facade for the CLI parser test slice in milestone 004, direction 011i, item `direction-011i-cli-spec-core-ids-import`, while preserving the existing CLI parse expectations, defaults, option names, parser rejection behavior, and `test/Main.hs` aggregate wiring.

### Approach
Keep the round sequential and limited to the selected test file. `test/CliSpec.hs` currently uses only `IssueNumber`, `RepoName`, and `ThreadId` from `CodexWatcher.Core.Ids`; import those from their direct owner modules instead:

- `CodexWatcher.Workflow.GitHub.Ids` for `IssueNumber` and `RepoName`
- `CodexWatcher.Workflow.Agent.Ids` for `ThreadId`

Do not change parser code, source modules, fixture data, Cabal exposure, docs, `test/Main.hs`, policy classification, runtime specs, public facade availability, or milestone completion state. Treat `orchestrator/project-contract.md` as the shared invariant source for public compatibility facade availability and cleanup sequencing.

### Steps
1. In `test/CliSpec.hs`, remove the import of `CodexWatcher.Core.Ids`.
2. Add direct imports for `ThreadId (..)` from `CodexWatcher.Workflow.Agent.Ids` and `IssueNumber (..), RepoName (..)` from `CodexWatcher.Workflow.GitHub.Ids`.
3. Leave every `parseCliCommand` assertion unchanged, including expected constructors, default values, option names, parser-error checks, and guard-domain assertions.
4. Leave `test/Main.hs` unchanged so the existing aggregate entries for `prop_cliParsesHealthcheckAndRunLoop`, `prop_cliParsesAppServerProbe`, `prop_cliRejectsBadDomain`, and `prop_cliParsesGenericRunnerGuardDomains` remain wired exactly as before.
5. Do not create `worker-plan.json`; this is a single-file import-ownership cleanup with no non-overlapping worker boundary.

### Verification
Run focused checks first:

1. `rg -n "CodexWatcher\\.Core\\.Ids" test/CliSpec.hs` and confirm it returns no matches.
2. `rg -n "IssueNumber|RepoName|ThreadId|prop_cliParses|prop_cliRejects" test/CliSpec.hs test/Main.hs` to record that the same CLI properties and constructor expectations remain present.
3. `cabal test watcher-core-test`; `test/Main.hs` wires these CLI properties through direct `quickCheckResult` calls, so the full test target is the focused behavioral check available for this suite.

Then run the active roadmap baseline checks for a test-code change:

1. `cabal build all`
2. `cabal test watcher-core-test`
3. `git diff --check`

No `git diff --cached --check` is required unless the implementer stages files.
