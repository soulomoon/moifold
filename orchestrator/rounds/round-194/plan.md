### Goal
Migrate only `test/RuntimeCompatibilityFixtureSpec.hs` away from the `CodexWatcher.Core.Ids` compatibility facade by importing its ID constructors from their direct owner modules, while preserving all runtime compatibility fixture behavior and assertions.

### Approach
This round is a single-file import ownership cleanup. Replace the current `CodexWatcher.Core.Ids` import in `test/RuntimeCompatibilityFixtureSpec.hs` with direct owner imports:

- `CodexWatcher.Workflow.Agent.Ids` for `ThreadId (..)` and `TurnId (..)`.
- `CodexWatcher.Workflow.GitHub.Ids` for `BranchName (..)`, `IssueNumber (..)`, `PrNumber (..)`, and `RepoName (..)`.

Do not change fixture JSON, fixture paths, runtime compatibility writes, repair behavior, healthcheck reader boundary assertions, daemon-state assertions, planning graph assertions, PASS labels, aggregate wiring, source modules, docs, Cabal exposure, `test/FacadeImportPolicySpec.hs`, or `test/Main.hs`. This is import convergence evidence only; it is not public facade deprecation, removal approval, milestone completion, or terminal closeout.

### Steps
1. Edit `test/RuntimeCompatibilityFixtureSpec.hs` to remove the `CodexWatcher.Core.Ids` import.
2. Add direct imports from `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids` with the exact constructors listed in the approach.
3. Keep every test body, assertion label, fixture value, fixture path, helper, and exported `runtimeCompatibilityFixtureTests` aggregate unchanged.
4. Confirm `test/RuntimeCompatibilityFixtureSpec.hs` no longer imports `CodexWatcher.Core.Ids`.
5. Record remaining `CodexWatcher.Core.Ids` users separately if a broad scan is run; do not migrate or classify `test/FacadeImportPolicySpec.hs`, `test/Main.hs`, docs, Cabal exposure, or the public facade module in this round.

### Verification
Run focused import and behavior checks:

1. `rg -n "CodexWatcher\\.Core\\.Ids" test/RuntimeCompatibilityFixtureSpec.hs`
2. `cabal test watcher-core-test`
3. `git diff --check`

If time permits, also run `cabal build all` as the roadmap baseline. If staging is performed later, run `git diff --cached --check`.

The reviewer should verify that the selected file uses direct owner imports, that runtime compatibility fixture assertions and PASS labels were not weakened, and that no out-of-scope files or compatibility surfaces changed.

### Worker Fan-Out
No worker fan-out. The round is sequential and touches one test file with one import ownership change, so no `worker-plan.json` is needed.
