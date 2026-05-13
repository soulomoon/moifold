### Goal
Migrate only `src/CodexWatcher/GoldenReplay.hs` away from the `CodexWatcher.Core.Ids` compatibility facade by importing its existing ID types from the direct owner modules, while preserving golden replay, snapshot normalization, replay warnings, bootstrap events, old fixture behavior, exports, constructors, and public compatibility surfaces.

### Approach
Keep this as a single production-file import convergence change. Replace the current `CodexWatcher.Core.Ids` import with:

- `CodexWatcher.Workflow.Agent.Ids (ThreadId (..), TurnId (..))`
- `CodexWatcher.Workflow.GitHub.Ids (BranchName (..), CommitSha (..), IssueNumber (..), PrNumber (..), RepoName (..))`

Do not change any function body, export list, constructor use, fixture, test, package descriptor, docs file, roadmap file, or `CodexWatcher.Core.Ids` itself. This round is not a public facade removal, Cabal exposure cleanup, runtime compatibility cleanup, deprecation decision, milestone closeout, release approval, or terminal roadmap action. It is a serial plan; worker fan-out is not justified for a one-file import migration.

### Steps
1. Open `src/CodexWatcher/GoldenReplay.hs` and confirm its only `CodexWatcher.Core.Ids` dependency is the current import list containing `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, `RepoName`, `ThreadId`, and `TurnId`.
2. Replace that one compatibility-facade import with the two direct owner imports named in the approach.
3. Preserve the existing constructor availability exactly: use `(..)` for all seven migrated identifiers so existing `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, `RepoName`, `ThreadId`, and `TurnId` construction sites continue to compile unchanged.
4. Do not reorder or rewrite replay code. In particular, leave `normalizeNodeSnapshot`, `replayTypedSnapshot`, `bootstrapNodeSnapshotEvents`, `bootstrapNodePrReviewSnapshotEvents`, `bootstrapNodeIssueImplementSnapshotEvents`, warning strings, default blocked reasons, `bootstrapPlanTurn`, `bootstrapImplementationTurn`, and `bootstrapReviewerTurn` unchanged.
5. Inspect the zero-context diff for `src/CodexWatcher/GoldenReplay.hs` and confirm the diff is import-only.
6. Do not stage unless the surrounding orchestrator step explicitly asks for staging. If staging happens later, run the staged whitespace check listed below.

### Verification
Run the baseline checks sequentially:

```bash
cabal build all
cabal test watcher-core-test
git diff --check
git diff --cached --check   # only if changes are staged
```

Run focused selected-file scans:

```bash
rg -n "CodexWatcher\.Core\.Ids" src/CodexWatcher/GoldenReplay.hs
rg -n "CodexWatcher\.Workflow\.Agent\.Ids \(ThreadId \(\.\.\), TurnId \(\.\.\)\)" src/CodexWatcher/GoldenReplay.hs
rg -n "CodexWatcher\.Workflow\.GitHub\.Ids \(BranchName \(\.\.\), CommitSha \(\.\.\), IssueNumber \(\.\.\), PrNumber \(\.\.\), RepoName \(\.\.\)\)" src/CodexWatcher/GoldenReplay.hs
```

The first command must have no matches. The direct-owner scans must show the two new imports.

Run and record a broad remaining-user scan, separating remaining production users from tests, docs, Cabal/package descriptors, and the public facade module:

```bash
rg -n "CodexWatcher\.Core\.Ids" src app test docs *.cabal agent-workflow-* -g '*.hs' -g '*.md' -g '*.cabal'
```

The implementation notes should explicitly state that any remaining `src` production users are outside this round, `src/CodexWatcher/Core/Ids.hs` remains the public compatibility facade, test/fixture users are milestone-004 scope, and `moifold.cabal` exposure remains unchanged.

Record golden replay and snapshot-normalization evidence from `watcher-core-test`. The existing `test/Main.hs` coverage runs `goldenReplayCases`, `goldenEventLogCases`, and `goldenBootstrapCases`; the notes should call out PASS output for the golden replay fixtures and bootstrap checks, especially the bootstrap domain/phase parity between `replayNodeSnapshot` normalization and `bootstrapNodeSnapshotEvents` replay.

### Worker Fan-Out
Not used. This is a single-file, import-only production migration with no non-overlapping worker ownership to split.
