### Goal

Migrate only `src/CodexWatcher/Domain/IssueImplement/Loop.hs` away from the `CodexWatcher.Core.Ids` compatibility facade to direct id owner imports when the existing owner modules and behavior evidence prove the move safe. If the migration is not safe, leave the source unchanged and classify the exact blocker for this file.

### Approach

Use the preferred one-file import-only path. The target file currently imports `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, `RequestId`, and `ThreadId` through `CodexWatcher.Core.Ids`. `CodexWatcher.Core.Ids` is only a reexport facade for `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`, and the direct owner modules expose the needed identifiers.

The intended import replacement is:

```haskell
import CodexWatcher.Workflow.Agent.Ids (RequestId, ThreadId (..))
import CodexWatcher.Workflow.GitHub.Ids (BranchName (..), CommitSha (..), IssueNumber (..), PrNumber (..))
```

Keep the implementation import-only: no behavior changes, no public facade/Cabal/docs/runtime cleanup, no test or fixture import migrations, no changes to `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`, and no milestone or terminal completion claims. No worker fan-out is justified because the slice has one source file, one import replacement, and one integrated verification bundle.

### Steps

1. Confirm the working scope before editing: inspect `git diff -- src/CodexWatcher/Domain/IssueImplement/Loop.hs` and do not overwrite unrelated local changes if any are present.
2. In `src/CodexWatcher/Domain/IssueImplement/Loop.hs`, replace only the `CodexWatcher.Core.Ids` import with the two direct owner imports listed above.
3. Keep every use site unchanged: `unBranchName`, `unCommitSha` if present, `unIssueNumber`, `unPrNumber`, `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, `RequestId`, and `ThreadId` should continue to resolve from the owner imports.
4. Verify the diff is import-only with `git diff -- src/CodexWatcher/Domain/IssueImplement/Loop.hs`. If any non-import code changed, revert those source-line changes before continuing.
5. If compilation fails because an identifier is not exported by the direct owner modules, because a package boundary is missing, or because a direct import would require Cabal/public-surface work, revert the import replacement and classify `IssueImplement/Loop.hs` as blocked for that exact reason.
6. If focused behavior evidence fails after an import-only change, revert the import replacement and classify the file with the failing behavior surface: request-id threading, worker/reviewer thread handling, repo/issue/PR rendering, event append order, daemon transition behavior, app-server turn classification, command rendering, or failure text.
7. Do not expand into neighboring modules. `src/CodexWatcher/Domain/IssuePlanning/Loop.hs` was completed by round 185 and must remain untouched.

### Verification

Run the baseline checks:

```sh
cabal build all
cabal test watcher-core-test
git diff --check
```

Do not run `git diff --cached --check` unless files are staged; this round must not stage files.

Run selected import scans if the migration is applied:

```sh
rg -n "CodexWatcher\\.Core\\.Ids" src/CodexWatcher/Domain/IssueImplement/Loop.hs
rg -n "CodexWatcher\\.Workflow\\.Agent\\.Ids|CodexWatcher\\.Workflow\\.GitHub\\.Ids" src/CodexWatcher/Domain/IssueImplement/Loop.hs
```

The selected-file `Core.Ids` scan must have no matches. The direct-owner scan must show `CodexWatcher.Workflow.Agent.Ids` owning `RequestId` and `ThreadId`, and `CodexWatcher.Workflow.GitHub.Ids` owning `BranchName`, `CommitSha`, `IssueNumber`, and `PrNumber`.

Run and record a broad remaining-user classification:

```sh
rg -n "CodexWatcher\\.Core\\.Ids" src app test docs moifold.cabal agent-workflow-*/*.cabal
```

Classify matches separately as production users, `src/CodexWatcher/Core/Ids.hs` public facade, tests/fixtures, docs, Cabal/package exposure, or standalone package candidates. Do not treat remaining tests/docs/Cabal/public facade matches as milestone-003 production blockers.

For focused issue-implementation loop behavior evidence, use the full `watcher-core-test` output and record the relevant PASS/property coverage for:

- request-id threading and app-server request progression: `prop_effectInterpreterIssueTurnsUsePhaseSpecificPrompts`, `workflowIssueImplementIndexedDaemonDryRunAndExecuteMatchPlanPrSetupAndImplementationWorkerProjections`, and `workflowIssueImplementIndexedDaemonDryRunAndExecuteMatchPostMergeReviewProjections`;
- worker and reviewer thread handling: `prop_eventLogRefreshesIdleIssueWorkerThread`, `prop_issueImplementWatcherMergedStartsPostMergeReview`, and the indexed daemon handoff/post-merge projection checks;
- repo/issue/PR rendering and command rendering: `prop_effectInterpreterPrBodyUpdateUsesIssuePlan`, `prop_runtimeGhPrCreateKeepsStdoutJsonOnly`, `prop_runtimeGhPrBodyUpdateUsesPlanFile`, and the automatic PR retry/body-update PASS lines;
- event append order and daemon transition behavior: `prop_eventLogFullIssueImplementationPathCompletes`, `prop_eventLogIssueIncompleteCanContinueToComplete`, `prop_issueImplementWatcherIncompleteRestartsImplementation`, `prop_issueImplementWatcherBlockedStops`, and indexed daemon execute-mode checks that commit the event before compatibility writes;
- app-server turn classification and failure text: `prop_turnClassifierMapsDomainOutputs`, `prop_turnClassifierPrefersStructuredOutputs`, `prop_turnClassifierBlocksMissingOutputs`, and the automatic implementation incomplete/missing-output/complete-without-known-PR PASS lines.

The expected outcome for a successful round is an import-only diff in `src/CodexWatcher/Domain/IssueImplement/Loop.hs`, passing baseline checks, no selected-file `Core.Ids` import, direct owner imports for all needed identifiers, and a broad `Core.Ids` classification that leaves public facade, tests, docs, Cabal, and runtime cleanup for later selected milestones.
