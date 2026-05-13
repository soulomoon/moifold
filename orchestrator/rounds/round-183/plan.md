### Goal
Migrate `src/CodexWatcher/Runtime/Compatibility.hs` off the `CodexWatcher.Core.Ids` compatibility facade to direct id owner imports when focused runtime compatibility evidence stays stable. If that evidence shows the split is unsafe, leave behavior unchanged and classify the exact runtime-compatibility blocker for this file.

Lineage: roadmap `2026-05-11-00-highest-value-cleanup`, revision `rev-002`, milestone `milestone-003-core-ids-production-import-burndown`, direction `direction-011c-core-ids-runtime-compatibility-production-classification`, item `round-183-runtime-compatibility-core-ids-import-migration-or-classification`.

### Approach
Keep the implementation import-only. Replace only the current `CodexWatcher.Core.Ids` import in `src/CodexWatcher/Runtime/Compatibility.hs` with the direct owner modules:

- `CodexWatcher.Workflow.Agent.Ids (ThreadId (..), TurnId (..))`
- `CodexWatcher.Workflow.GitHub.Ids (BranchName (..), CommitSha (..), IssueNumber (..), PrNumber (..), RepoName (..), ReviewThreadId (..))`

Do not change constructors, fields, JSON keys, file names, write ordering, write timing, repair paths, healthcheck reader/non-reader behavior, event schemas, replay behavior, domain-loop imports, public facade exposure, Cabal, docs, tests, or fixtures. If compilation exposes a missing direct owner import, make only the minimal import correction needed for this same file. If runtime compatibility evidence fails or indicates behavior drift, classify the precise blocker instead of broadening the slice.

### Steps
1. Confirm the pre-change target imports exactly the eight id types from `CodexWatcher.Core.Ids` and that `CodexWatcher.Core.Ids` is only acting as a re-export facade for the two direct owner modules.
2. Edit only `src/CodexWatcher/Runtime/Compatibility.hs` to remove the `CodexWatcher.Core.Ids` import and add the two direct owner imports listed above.
3. Keep the rest of the file byte-for-byte equivalent in behavior: `CompatibilityWrite`, `writeCompatibility`, `compatibilityStateWrites`, all helper JSON constructors, all file names, and all `un*` field projections must remain semantically unchanged.
4. Run focused source scans for the selected file:
   - prove it no longer imports `CodexWatcher.Core.Ids` if migrated;
   - prove it imports `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`;
   - inspect the diff to confirm the selected file changed only at imports unless compiler evidence required a minimal import correction.
5. Run focused runtime compatibility evidence from the existing tests and fixtures. At minimum, ensure the full `watcher-core-test` run covers `RuntimeCompatibilityFixtureSpec.runtimeCompatibilityFixtureTests`, `RuntimeSpec` runtime behavior, and healthcheck-related checks such as `HealthcheckSpec` plus the healthcheck/read-nonread assertions embedded in `RuntimeCompatibilityFixtureSpec`.
6. Run the broad remaining `CodexWatcher.Core.Ids` import scan over `src`, `app`, `test`, docs, package descriptors, and package candidates. Record remaining production users separately from test/fixture users, docs, Cabal exposure, and `src/CodexWatcher/Core/Ids.hs`.
7. If any verification failure is caused by the import split itself, either make the smallest import-only correction in `Runtime/Compatibility.hs` or classify the exact runtime-compatibility blocker. Do not change runtime compatibility files, healthcheck, repair, event replay, public facades, Cabal, docs, or tests to force the migration.

### Verification
Required commands:

```sh
cabal build all
cabal test watcher-core-test
git diff --check
```

Required scans/evidence:

```sh
rg -n "import CodexWatcher\\.Core\\.Ids" src/CodexWatcher/Runtime/Compatibility.hs
rg -n "import CodexWatcher\\.Workflow\\.(Agent|GitHub)\\.Ids" src/CodexWatcher/Runtime/Compatibility.hs
rg -n "import CodexWatcher\\.Core\\.Ids" src app test docs moifold.cabal agent-workflow-* 2>/dev/null
git diff -- src/CodexWatcher/Runtime/Compatibility.hs
```

The selected-file `Core.Ids` scan should return no matches after a successful migration. The broad scan should be reported by category: remaining production users under `src` or `app`, test/fixture users under `test`, docs, package descriptors, standalone package candidates, and the public facade module itself. Expected production users after a successful import-only migration should no longer include `src/CodexWatcher/Runtime/Compatibility.hs`; any remaining production users must be named exactly.

The `watcher-core-test` evidence must be interpreted against the runtime compatibility surface: current compatibility file names (`planner-state.json`, `planning-state.json`, `daemon-state.json`, `watcher-state.json`, `checker-state.json`, `reviewer-state.json`, `block-state.json`), JSON shapes, write timing, repair rewrite boundaries, healthcheck reader/non-reader contracts, summary paths, runtime state semantics, event schemas, and replay behavior must remain unchanged.

Do not run `git diff --cached --check` unless staging occurs; this round must not stage or commit.

### Worker Fan-Out
No worker fan-out. The selected work is one import-only production file with tightly coupled verification, so sequential implementation and review is the appropriate ownership boundary.
