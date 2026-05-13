### Goal

Migrate or classify only the `CodexWatcher.Core.Ids` import in
`src/CodexWatcher/Healthcheck.hs` for round
`round-184-healthcheck-core-ids-import-migration-or-classification`, preserving
the active `2026-05-11-00-highest-value-cleanup` / `rev-002` boundaries.

The preferred success path is an import-only split to direct id owner modules:

- `CodexWatcher.Workflow.Agent.Ids (RequestId (..), ThreadId (..), TurnId (..))`
- `CodexWatcher.Workflow.GitHub.Ids (BranchName (..), CommitSha (..), PrNumber (..), RepoName (..))`

If focused healthcheck evidence shows that direct split is unsafe, classify the
exact blocker instead of widening scope.

### Approach

Keep this as a sequential, one-file production import cleanup. Do not change
healthcheck JSON shapes, summary paths, runtime-state reader/non-reader sets,
command rendering, app-server thread checks, repair behavior, compatibility
file names, runtime-state semantics, public facade exposure, Cabal, docs, tests,
or roadmap/controller artifacts.

The implementation may edit only `src/CodexWatcher/Healthcheck.hs`, and only
for the `CodexWatcher.Core.Ids` import unless the compiler proves a minimal
import-list correction is required. No worker fan-out is justified because the
slice has one source file, one import boundary, and one integrated verification
set.

### Steps

1. Confirm the current target import in `src/CodexWatcher/Healthcheck.hs` is
   only the `CodexWatcher.Core.Ids` import for `BranchName`, `CommitSha`,
   `PrNumber`, `RepoName`, `RequestId`, `ThreadId`, and `TurnId`.
2. Replace that single import with the two direct owner imports listed in the
   goal. Keep the imported constructors/accessors as narrow as the existing
   source requires; if the compiler reports an unused or missing import, make
   only the minimal import-list correction.
3. Do not touch any healthcheck logic. In particular, preserve
   `threadReadRequest (RequestId 9001) (ThreadId ...) True`,
   branch/commit/PR/repo command construction and parsing, `latestTurnId`
   extraction, state file specs, runtime owner fallback, and skipped app-server
   thread reporting.
4. If the direct split fails in a way that implies an ownership or behavior
   dependency rather than a trivial import-list correction, restore
   `Healthcheck.hs` to its prior behavior and record the exact blocker as the
   round outcome. Do not migrate adjacent files, weaken tests, alter Cabal/docs,
   or move compatibility/public facade surfaces.
5. After migration or classification, record remaining `CodexWatcher.Core.Ids`
   users by category: production `src` users, tests/fixtures, docs, Cabal
   exposure, and the public facade module `src/CodexWatcher/Core/Ids.hs`.

### Verification

Run the baseline checks:

- `cabal build all`
- `cabal test watcher-core-test`
- `git diff --check`

Run selected-file import evidence after a migration:

- `! rg -n "import CodexWatcher\\.Core\\.Ids" src/CodexWatcher/Healthcheck.hs`
- `rg -n "import CodexWatcher\\.Workflow\\.(Agent|GitHub)\\.Ids" src/CodexWatcher/Healthcheck.hs`

Record focused healthcheck evidence from the test suite. The discoverable
HealthcheckSpec coverage includes app-server thread/read behavior, stable
request id rendering, JSON-RPC/decode failures, daemon-required statuses,
dirty-workdir warnings, issue-implementation lifecycle reporting, singleton
domain handling, summary JSON kind fields, typed analyzer dispatch, and CLI
healthcheck parsing.

Record relevant runtime compatibility fixture evidence. The discoverable
RuntimeCompatibilityFixtureSpec coverage includes
`healthcheckPlannerReaderBoundaryTest`,
`healthcheckRuntimeStateReadNonReadContractTest`,
`daemonStateSourceBoundaryTest`, `blockStateSourceBoundaryTest`,
`repairStateSourceBoundaryTest`, `runtimeOwnerSourceBoundaryTest`, and
`issueSnapshotSourceBoundaryTest`. These checks protect the healthcheck reader
set, non-reader contracts, compatibility file names, runtime-owner summary
path, repair boundaries, and source-level runtime-state semantics.

Run and record a broad remaining-user scan, separating production users from
tests, docs, Cabal, and the public facade:

- `rg -n "import CodexWatcher\\.Core\\.Ids" src app test docs moifold.cabal`

Expected migrated production result for this round: `src/CodexWatcher/Healthcheck.hs`
is absent from the `Core.Ids` import scan. Remaining production users should be
classified separately, currently expected to include only
`src/CodexWatcher/Domain/IssuePlanning/Loop.hs` and
`src/CodexWatcher/Domain/IssueImplement/Loop.hs` unless the current scan proves
otherwise.
