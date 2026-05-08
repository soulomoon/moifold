### Changes Made
- `src/CodexWatcher/Daemon.hs`: routed only item-022 post-merge review daemon observations through the existing indexed IssueImplement projection: final-review turn start, clean outcome, rework outcome, incomplete outcome, and blocked outcome. Existing domain-loop ownership, terminal issue-close routing, and compatibility projection shape are unchanged.
- `test/Main.hs`: added daemon dry-run/execute parity coverage for post-merge final-review start and all four final-review outcomes, reusing `runIssueImplementDaemonProjectionCase` so event parity, effects, request ids, compatibility writes, append ordering, replay source state, and final-state labels are checked. Updated source-scan guards to require item-022 projectors in `Daemon.hs` and continue forbidding item-023 issue-close routing.

### Tests
- `test/Main.hs`: `workflowIssueImplementIndexedDaemonDryRunAndExecuteMatchPostMergeReviewProjections` verifies final-review turn start plus clean/rework/incomplete/blocked outcomes route through the indexed IssueImplement projection with dry-run/execute parity.
- `test/Main.hs`: `workflowIssueImplementIndexedDaemonDoesNotRouteLaterProjectors` now requires item-020 through item-022 daemon projectors and still forbids item-023-plus issue-close routing.
- Passed: `cabal test watcher-core-test --test-option=--match --test-option='indexed workflow issue implement daemon'`
- Passed: `cabal test watcher-core-test --test-option=--match --test-option='automatic issue merge waits for issue close'`
- Passed: `cabal test watcher-core-test --test-option=--match --test-option='automatic issue final review findings request rework'`
- Passed: `cabal test watcher-core-test --test-option=--match --test-option='turn classifier maps domain outputs'`
- Passed: `cabal test watcher-core-test`
- Passed: `cabal build all`
- Passed: `git diff --check`

### Notes
- No files were staged, so `git diff --cached --check` was not run.
- Manual guard passed: `rg -n "ObservedIssueClosed|projectIssueImplementIssueClosed|runIssueWaitingForIssueClose" src/CodexWatcher/Daemon.hs src/CodexWatcher/DaemonLoop.hs src/CodexWatcher/Domain/IssueImplement/Loop.hs` shows issue-close polling remains in `DaemonLoop.hs` and `Domain/IssueImplement/Loop.hs`; no item-023 issue-close projector route was added to `Daemon.hs`.
- Manual guard passed: `rg -n "CodexWatcher.Workflow.Moifold.IssueImplement.Indexed|IssueImplementIndexedSpec|projectIssueImplement" src/CodexWatcher/Domain src/CodexWatcher/DaemonLoop src/CodexWatcher/AutomaticLoop` produced no matches.
- Manual guard passed: `rg -n "projectIssueImplementPostMergeReviewStartedObservation|projectIssueImplementPostMergeReviewerOutcome" src/CodexWatcher/Daemon.hs test/Main.hs` shows item-022 routes in `Daemon.hs` and parity/source-scan coverage in `test/Main.hs`.
- Manual guard passed: `rg -n "IssueFinalReviewOutcome|reviewerPromptVersion|reviewed_commit_sha|final review state missing required fields|merged PR #.*headRefOid" src/CodexWatcher/Domain/IssueImplement test/Main.hs` confirms final-review classifier types, prompt-version validation, reviewed-commit validation, missing-field diagnostics, and missing `headRefOid` diagnostics remain in the domain layer and tests.
- `orchestrator/state.json` was already modified in the worktree and was not edited.
