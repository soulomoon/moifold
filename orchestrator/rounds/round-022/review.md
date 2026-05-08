## Findings

No blocking findings.

The round diff is scoped to implementation, tests, and round artifacts. Current tracked implementation diff contains only:

- `src/CodexWatcher/Daemon.hs`
- `test/Main.hs`

`orchestrator/state.json` is not modified, staged, or included in the current implementation diff.

## Verification Evidence

### Diff Review

- `src/CodexWatcher/Daemon.hs` adds only five item-022 `prepareDaemonObservation` routes:
  - `IssuePostMergeReviewReady` plus `ObservedPostMergeReviewStarted`
  - `IssuePostMergeReviewing` plus clean final-review outcome
  - `IssuePostMergeReviewing` plus rework-required final-review outcome
  - `IssuePostMergeReviewing` plus incomplete final-review outcome
  - `IssuePostMergeReviewing` plus blocked final-review outcome
- The new daemon routes use the existing moifold-owned indexed projectors and immediately project back through `preparedFromIssueImplementProjection`.
- No implementation changes were made in `src/CodexWatcher/Domain/IssueImplement/Loop.hs`, `src/CodexWatcher/DaemonLoop.hs`, `src/CodexWatcher/DaemonLoop/ActiveTurn.hs`, `src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`, `src/CodexWatcher/AutomaticLoop`, event definitions, replay definitions, or effect definitions.
- Terminal issue close, child lifecycle, repair, healthcheck, fanout, and item-023+ routes remain outside this round's indexed daemon routing.
- Final-review classifier ownership remains in the domain layer. `IssueFinalReviewOutcome`, prompt-version validation, reviewed-commit validation, missing-field diagnostics, and missing `headRefOid` diagnostics are still in `src/CodexWatcher/Domain/IssueImplement`.
- The test change adds item-022 daemon parity cases for final-review start plus clean, rework, incomplete, and blocked outcomes. The shared helper checks dry-run/execute parity, event parity, planned effects, compiled request ids, compatibility writes, append ordering, replay source state, and final state labels.
- Source-scan guards were updated so item-022 post-merge projectors are required in `Daemon.hs`, item-023 issue-close routes remain forbidden in daemon routing, and indexed routing remains forbidden from domain, daemon-loop, runtime, and automatic-loop modules.

### Required Commands

- Command: `cabal test watcher-core-test --test-option=--match --test-option='indexed workflow issue implement daemon'`
  Result: PASS. The run included the new post-merge daemon dry-run and execute assertions for final-review turn start and clean/rework/incomplete/blocked outcomes.

- Command: `cabal test watcher-core-test --test-option=--match --test-option='automatic issue merge waits for issue close'`
  Result: PASS.

- Command: `cabal test watcher-core-test --test-option=--match --test-option='automatic issue final review findings request rework'`
  Result: PASS.

- Command: `cabal test watcher-core-test --test-option=--match --test-option='turn classifier maps domain outputs'`
  Result: PASS.

- Command: `cabal test watcher-core-test`
  Result: PASS.

- Command: `cabal build all`
  Result: PASS. Cabal reported `Up to date`.

- Command: `git diff --check`
  Result: PASS. No whitespace errors.

- Command: `git diff --cached --check`
  Result: Not run because no files are staged. Verified with `git diff --cached --name-only`.

### Manual Source-Scan Guards

- Command: `rg -n "ObservedIssueClosed|projectIssueImplementIssueClosed|runIssueWaitingForIssueClose" src/CodexWatcher/Daemon.hs src/CodexWatcher/DaemonLoop.hs src/CodexWatcher/Domain/IssueImplement/Loop.hs`
  Result: PASS. Matches are only `runIssueWaitingForIssueClose` and `ObservedIssueClosed` in `DaemonLoop.hs` / `Domain/IssueImplement/Loop.hs`; no item-023 issue-close daemon projector route was added to `Daemon.hs`.

- Command: `rg -n "CodexWatcher.Workflow.Moifold.IssueImplement.Indexed|IssueImplementIndexedSpec|projectIssueImplement" src/CodexWatcher/Domain src/CodexWatcher/DaemonLoop src/CodexWatcher/AutomaticLoop`
  Result: PASS. No matches.

- Command: `rg -n "projectIssueImplementPostMergeReviewStartedObservation|projectIssueImplementPostMergeReviewerOutcome" src/CodexWatcher/Daemon.hs test/Main.hs`
  Result: PASS. Item-022 projectors are present in `Daemon.hs` and covered in `test/Main.hs`.

- Command: `rg -n "IssueFinalReviewOutcome|reviewerPromptVersion|reviewed_commit_sha|final review state missing required fields|merged PR #.*headRefOid" src/CodexWatcher/Domain/IssueImplement test/Main.hs`
  Result: PASS. Final-review outcome type, prompt validation, reviewed-commit validation, missing-field diagnostics, and missing `headRefOid` diagnostics remain in the domain layer and tests.

## Decision

**APPROVED**

Round 022 satisfies item `item-022-indexed-issue-implementation-post-merge-review-daemon`: only post-merge final-review turn start and final-review clean/rework/incomplete/blocked outcomes route through indexed projection, while terminal issue close and later lifecycle surfaces remain on compatibility fallback. Baseline and task-specific verification passed.
