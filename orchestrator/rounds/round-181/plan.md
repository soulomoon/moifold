### Goal

Migrate only `src/CodexWatcher/Cli/Command/IssueFanout.hs` away from the
`CodexWatcher.Core.Ids` compatibility facade to direct id-owner imports for
round `round-181`, under roadmap
`2026-05-11-00-highest-value-cleanup` revision `rev-002`, milestone
`milestone-003-core-ids-production-import-burndown`, direction
`direction-011f-core-ids-cli-production-imports`.

The intended result is import-only: `IssueFanout.hs` should no longer import
`CodexWatcher.Core.Ids`, while fanout planning, active issue discovery, child
launch state writes, request-id progression, command rendering, dry-run text,
process execution, parser/type modules, public facade exposure, Cabal, docs,
runtime compatibility files, and behavior stay unchanged.

### Approach

Use direct owner imports in `IssueFanout.hs`:

- `CodexWatcher.Workflow.Agent.Ids (RequestId (..), ThreadId (..))`
- `CodexWatcher.Workflow.GitHub.Ids (BranchName (..), IssueNumber (..), RepoName (..))`

Although the `BranchName` type name appears only in the old import list, the
file currently calls `unBranchName` while rendering the `git checkout -B`
command. Importing `BranchName (..)` from the GitHub id owner is therefore the
narrow direct-owner replacement for the existing accessor use. Do not add any
other ids unless the compiler proves another existing use is hidden by the
facade import.

Keep the slice serial. Worker fan-out is not justified because there is one
production file, one import group, and one integrated verification surface.

### Steps

1. Open `src/CodexWatcher/Cli/Command/IssueFanout.hs` and replace the single
   `CodexWatcher.Core.Ids` import with the direct owner imports listed above.
2. Keep the rest of the file unchanged unless `cabal build all` proves a
   compile error directly caused by the import migration.
3. If a minimal compile correction is required, limit it to the import list or
   an already-used id accessor/constructor qualification in `IssueFanout.hs`;
   do not touch behavior, data shapes, command text, state writes, or related
   parser/type modules.
4. Do not edit `src/CodexWatcher/Core/Ids.hs`, `moifold.cabal`, docs, tests,
   runtime compatibility files, public facade exposure, or any roadmap/control
   artifact as part of implementation.
5. After the edit, inspect the diff and confirm it is import-only unless step 3
   was required by compiler evidence.

### Verification

Run the baseline checks from the active roadmap verification file:

```sh
cabal build all
cabal test watcher-core-test
git diff --check
```

No staging is required for this implementation slice. If staging happens later,
also run:

```sh
git diff --cached --check
```

Run selected-file import scans proving the target no longer uses the facade and
does use the direct owners:

```sh
! rg -n 'CodexWatcher\.Core\.Ids' src/CodexWatcher/Cli/Command/IssueFanout.hs
rg -n 'CodexWatcher\.Workflow\.Agent\.Ids' src/CodexWatcher/Cli/Command/IssueFanout.hs
rg -n 'CodexWatcher\.Workflow\.GitHub\.Ids' src/CodexWatcher/Cli/Command/IssueFanout.hs
rg -n 'BranchName|unBranchName|IssueNumber|RepoName|RequestId|ThreadId' src/CodexWatcher/Cli/Command/IssueFanout.hs
```

Record focused fanout/CLI behavior evidence from the existing
`watcher-core-test` coverage. Applicable checks are discoverable in
`test/IssueFanoutAppServerSpec.hs` and `test/Main.hs`, including deterministic
request ids `8000`/`8001`, persisted app-server thread ids, launch manifests,
child args for root and non-root endpoints, JSON-RPC/decode failure formatting,
retryable clone failure classification, dry-run child command shape, and launch
write ordering. Because this round should be import-only, the full
`cabal test watcher-core-test` result is acceptable focused evidence for those
covered behavior surfaces.

Run and record a broad remaining-user scan that separates categories instead of
treating all `Core.Ids` imports as production blockers:

```sh
rg -n 'import CodexWatcher\.Core\.Ids' src app test docs moifold.cabal agent-workflow-* packages 2>/dev/null || true
```

Classify the scan results as:

- production users under `src/`, excluding the public facade module
  `src/CodexWatcher/Core/Ids.hs`
- application entrypoints under `app/`, if any
- tests and fixtures under `test/`
- docs under `docs/`
- package descriptors such as `moifold.cabal`
- standalone package candidates such as `agent-workflow-*` or `packages/`
- the public facade module `src/CodexWatcher/Core/Ids.hs`, which must remain
  exposed and is not a production burndown failure

Expected post-migration production users should no longer include
`src/CodexWatcher/Cli/Command/IssueFanout.hs`. Any remaining production users
belong to later milestone-003 slices or explicit classification; do not use
this round to migrate them.
