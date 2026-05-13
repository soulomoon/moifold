### Goal
Migrate only `src/CodexWatcher/EventLog/Types.hs` away from the `CodexWatcher.Core.Ids` compatibility facade to the direct id owner modules, preserving every watcher event constructor, JSON label, schema version, metadata label, codec field name, golden replay fixture, old-log parse behavior, runtime compatibility file, healthcheck behavior, public facade exposure, Cabal exposure, and docs surface.

### Approach
Keep this as a sequential, import-only production cleanup slice. `EventLog.Types` currently uses agent-owned `ThreadId` and `TurnId`, and GitHub-owned `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, `RepoName`, and `ReviewThreadId`. Replace the single `CodexWatcher.Core.Ids` import with direct imports from:

```haskell
import CodexWatcher.Workflow.Agent.Ids (ThreadId (..), TurnId (..))
import CodexWatcher.Workflow.GitHub.Ids
  ( BranchName (..)
  , CommitSha (..)
  , IssueNumber (..)
  , PrNumber (..)
  , RepoName (..)
  , ReviewThreadId (..)
  )
```

No worker fan-out is justified: there is one implementation file, one import ownership boundary, and one integrated verification path. If compiler evidence shows the exact import list needs a minimal correction, keep that correction inside `src/CodexWatcher/EventLog/Types.hs` and do not edit behavior, tests, fixtures, Cabal, docs, roadmap artifacts, compatibility files, healthcheck, or domain-loop modules.

### Steps
1. Confirm the pre-edit target still has exactly the selected facade import with:
   `rg -n "import CodexWatcher\\.Core\\.Ids|CodexWatcher\\.Workflow\\.(Agent|GitHub)\\.Ids" src/CodexWatcher/EventLog/Types.hs`.
2. In `src/CodexWatcher/EventLog/Types.hs`, replace only the `CodexWatcher.Core.Ids` import block with the two direct owner import blocks listed above.
3. Do not change the `WatcherEvent` type, `ReplayFailure`, `EventReplayResult`, `ToJSON`/`FromJSON` instances, `eventName`, `watcherEventCodecContract`, `watcherEventMetadataLabels`, `watcherEventSchemaVersion`, helper names, field names, ordering, or any codec/replay logic.
4. If `cabal build all` reports an import-list error in this selected file, make the smallest import-list-only correction needed in this file. If it reports behavior, package, fixture, or cross-module evidence that the split is unsafe, stop and record the exact blocker/classification instead of widening scope.
5. Leave remaining `CodexWatcher.Core.Ids` users in production, tests, docs, Cabal, and the public facade untouched. This round is not public facade deprecation/removal, Cabal cleanup, docs cleanup, runtime compatibility cleanup, milestone completion, or terminal completion.

### Verification
Run and record:

```sh
cabal build all
cabal test watcher-core-test
git diff --check
```

Run selected-file import scans and record the output:

```sh
rg -n "import CodexWatcher\\.Core\\.Ids" src/CodexWatcher/EventLog/Types.hs
rg -n "import CodexWatcher\\.Workflow\\.Agent\\.Ids|import CodexWatcher\\.Workflow\\.GitHub\\.Ids" src/CodexWatcher/EventLog/Types.hs
```

The first selected-file scan must have no matches. The second must show direct owner imports for `ThreadId`, `TurnId`, `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, `RepoName`, and `ReviewThreadId`.

Record focused event-log compatibility evidence from `watcher-core-test`: `test/Main.hs` imports and runs `WorkflowEventLogSpec.workflowEventLogTests`, and `test/WorkflowEventLogSpec.hs` covers `workflowEventCodecContractCoversWatcherEvents`, `workflowEventCodecToleratesMetadataAndPreservesGoldenTypes`, `workflowEventLogFileWrapperDecodesExistingFixtures`, `workflowEventLogCoreDetailedReplayMatchesMoifold`, `workflowEventLogCoreFixtureContractValidatesReplay`, and `workflowEventLogCoreTransitionContractsUseDirectReplay`. That is the focused evidence for event JSON `type` stability, schema version `1`, metadata tolerance, existing golden/old fixture decoding, replay parity, and transition/replay compatibility.

Run a broad remaining facade-user scan and classify remaining matches without changing them:

```sh
rg -n "import CodexWatcher\\.Core\\.Ids" src app test docs moifold.cabal agent-workflow-* -g '*.hs' -g '*.md' -g '*.cabal'
```

In the implementation notes, separate remaining matches into production users, test/test-support users, docs, Cabal/package descriptors, and the public facade `src/CodexWatcher/Core/Ids.hs`. The expected production users after this slice should exclude `src/CodexWatcher/EventLog/Types.hs` and continue to include only still-selected future surfaces such as runtime compatibility, healthcheck, and domain-loop imports if they remain present.
