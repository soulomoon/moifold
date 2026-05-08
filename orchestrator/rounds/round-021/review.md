### Findings

No blocking findings.

- `orchestrator/state.json` is no longer modified in the round diff. `git diff --name-only` lists only `src/CodexWatcher/Daemon.hs` and `test/Main.hs`; `git status --short -- orchestrator/state.json` produced no output.
- The implementation routes only the item-021 IssueImplement handoff and merge-wait observations through indexed projection in `prepareDaemonObservation`: `ObservedReviewHandoffInitialized`, `ObservedReviewHandoffStarted`, handoff/merge-wait idempotent `ObservedImplementationCompleted`, `ObservedIssueReviewerThreadReady`, and `ObservedPullRequestMerged` from `IssueWaitingForPrMerge`.
- Post-merge reviewer start/outcome, issue close, follow-up, child lifecycle, and item-022+ observations remain on compatibility fallback. The manual scan found no `ObservedPostMergeReviewStarted`, `ObservedPostMergeReviewerOutcome`, `ObservedIssueClosed`, or item-022+ post-merge/close projectors in `src/CodexWatcher/Daemon.hs`.
- PR merge polling through `gh pr view`, idle waiting text, wrong-PR blocking, existing reviewer reuse, `DaemonObservedTickResult` shape, detailed transaction failures, action ordering, compatibility writes, event append before compatibility writes, and request-id stability are covered by the focused daemon parity and automatic-loop tests.
- Source-scan guards and package boundaries remain intact. The loop/runtime/automatic-loop scan found no indexed IssueImplement imports or projectors outside `src/CodexWatcher/Daemon.hs`, and the round diff does not modify `agent-workflow-core` or move moifold lifecycle policy into indexed core.

### Verification Evidence

- Command: `cabal test watcher-core-test --test-options='--pattern indexed workflow issue implement'`
  Result: pass. `watcher-core-test` passed. Relevant passing output included item-021 dry-run and execute daemon projection cases for handoff initialization/start, duplicate/idempotent observations, reviewer-thread-ready, merge-wait, wrong-PR blocking, compatibility/indexed event parity, final-state shape, compiled request ids, compatibility writes, and execute append/write ordering. It also included the source-scan assertions: `indexed workflow issue implement daemon routing stays out of loop modules`, `indexed workflow issue implement daemon routes required item-020 and item-021 projectors`, and `indexed workflow issue implement daemon does not route item-022-plus projectors`.

- Command: `cabal test watcher-core-test`
  Result: pass. Full watcher core regression suite passed, including golden replay, daemon, indexed-spec, package-boundary, issue-planning, issue-implementation, classifier, repair, healthcheck, and fanout coverage.

- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`.

- Command: `git diff --check`
  Result: pass. No whitespace errors reported.

- Command: `git diff --cached --name-only`
  Result: no staged files. Per the review requirement, `git diff --cached --check` was not applicable.

- Command: `rg -n "projectIssueImplement(PostMergeReviewStarted|PostMergeReviewerOutcome|IssueClosed)|ObservedPostMergeReviewStarted|ObservedPostMergeReviewerOutcome|ObservedIssueClosed" src/CodexWatcher/Daemon.hs`
  Result: pass. No matches, so item-022+ post-merge-review and close daemon routes are not routed in `Daemon.hs`.

- Command: `rg -n "CodexWatcher.Workflow.Moifold.IssueImplement.Indexed|projectIssueImplement|IssueImplementIndexedSpec" src/CodexWatcher/Domain/IssueImplement src/CodexWatcher/DaemonLoop.hs src/CodexWatcher/DaemonLoop src/CodexWatcher/AutomaticLoop`
  Result: pass. No matches, so indexed IssueImplement routing remains out of `Loop.hs`, `DaemonLoop`, and `AutomaticLoop` modules.

- Command: `rg -n "projectIssueImplementReviewHandoffInitialized|projectIssueImplementReviewHandoffStarted|projectIssueImplementationCompletedHandoff|projectIssueImplementationCompletedWaitingForPrMerge|projectIssueImplementReviewerThreadReady|projectIssueImplementPullRequestMergedWaitingForPrMerge" src/CodexWatcher/Daemon.hs`
  Result: pass. Found only the item-021 daemon projection routes in `prepareDaemonObservation`.

### Plan Compliance

- Selected item identity is correct: `selection.md` records roadmap id `2026-05-07-00-workflow-kernel-indexing`, revision `rev-004`, roadmap dir `orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-004`, and item id `item-021-indexed-issue-implementation-handoff-and-merge-wait-daemon`.
- Implementation scope is correct: tracked implementation diff is limited to `src/CodexWatcher/Daemon.hs` and `test/Main.hs`; `orchestrator/state.json` is not modified.
- Item-021 daemon routing is complete: all requested handoff, reviewer-thread-ready, idempotent implementation-completed, and waiting-for-PR-merge observations route through `preparedFromIssueImplementProjection`.
- Item-022+ daemon routing is deferred: post-merge reviewer starts/outcomes, issue close, follow-up, and child lifecycle behavior are not routed in this round.
- Compatibility surfaces are preserved: tests cover dry-run and execute parity, event equality, state shape, pre/post-commit effect plans, compiled request ids, replay source state, audit labels, compatibility writes, event append ordering, wrong-PR blocking, reviewer reuse, and merge-wait idle behavior.
- Package boundary is preserved: no concrete IssueImplement policy, GitHub execution, app-server transport, daemon/runtime interpreter, event codec, compatibility write ownership, or child lifecycle code moved into indexed core.

### Decision

**APPROVED**
