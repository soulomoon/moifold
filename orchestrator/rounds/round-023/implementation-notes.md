### Changes Made
- `src/CodexWatcher/Daemon.hs`: routed `IssueWaitingForIssueClose` plus `ObservedIssueClosed` through `projectIssueImplementIssueClosedObservation`, then projected back through the existing daemon observation shape.
- `test/Main.hs`: added daemon dry-run/execute parity coverage for issue-close success and wrong-PR close blocking; strengthened automatic issue-close polling coverage for retry ordering, execute idle text, dry-run close command rendering, no premature `IssueClosedEvent`, and closed-remote projection parity; updated the daemon source-scan guard so item-023 is required while item-024 blocked routing remains absent.
- `orchestrator/rounds/round-023/implementation-notes.md`: recorded implementation scope and verification evidence.

### Tests
- `test/Main.hs`: `workflowIssueImplementIndexedDaemonDryRunAndExecuteMatchIssueCloseProjections` verifies issue-close daemon dry-run/execute parity for successful close and stale-PR blocking, including compatibility/indexed event parity, effect/action/request-id parity, compatibility writes, final state labels, and replay source state.
- `test/Main.hs`: `automaticIssueMergeWaitsForIssueClose` now verifies open remote issues plan `CloseIssue` before `SleepUntilNextPoll`, execute mode idles with `closed issue after merged PR #7; waiting to observe closed issue`, dry-run renders the `GhIssueClose` command, no `IssueClosedEvent` is emitted before remote closed detection, and closed remote issue observations match the indexed projection with `StopDaemon`.
- `test/Main.hs`: `workflowIssueImplementIndexedDaemonDoesNotRouteLaterProjectors` now requires `projectIssueImplementIssueClosedObservation`/`ObservedIssueClosed` in `Daemon.hs` and keeps item-024 `ObservedIssueImplementBlocked`/generic blocked projectors out of live daemon routing.

### Notes
- `cabal test watcher-core-test`: passed.
- `cabal build all`: passed.
- `git diff --check`: passed.
- `git diff --cached --check`: not run because no files are staged.
- Source scan `rg -n "IssueWaitingForIssueClose|ObservedIssueClosed|projectIssueImplementIssueClosedObservation" src/CodexWatcher/Daemon.hs test/Main.hs`: showed the item-023 daemon route and test coverage.
- Source scan `rg -n "runIssueWaitingForIssueClose|retryCloseIssue|CloseIssue|SleepUntilNextPoll|waiting to observe closed issue|would close issue after merged PR" src/CodexWatcher/Domain/IssueImplement/Loop.hs test/Main.hs`: showed close polling/retry behavior remains in the domain loop and is tested.
- Source scan `rg -n "CodexWatcher.Workflow.Moifold.IssueImplement.Indexed|IssueImplementIndexedSpec|projectIssueImplement" src/CodexWatcher/Domain src/CodexWatcher/DaemonLoop src/CodexWatcher/AutomaticLoop`: no matches, so indexed IssueImplement routing remains confined to daemon projection.
- Item-024 lifecycle/fanout/healthcheck/repair guard was not run separately because the diff does not touch those surfaces.
