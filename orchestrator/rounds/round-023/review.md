### Findings

No findings.

The round diff is scoped to `src/CodexWatcher/Daemon.hs`, `test/Main.hs`, and round artifacts. `orchestrator/state.json` is not modified. The implementation routes only `IssueWaitingForIssueClose` plus `ObservedIssueClosed` through `WorkflowIssueImplementIndexed.projectIssueImplementIssueClosedObservation` in `Daemon.hs`, then projects back through the existing daemon observation shape.

### Verification Evidence

- Command: `cabal test watcher-core-test`
  Result: pass. The full watcher-core suite passed, including the new `indexed workflow issue implement daemon dry-run issue close completes`, `wrong issue close blocks`, execute-mode issue-close parity assertions, automatic close-retry ordering/idling/dry-run assertions, and source-scan guard assertions.
- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date` and exited successfully.
- Command: `git diff --check`
  Result: pass. No whitespace errors reported.
- Command: `git diff --cached --name-only`
  Result: no staged files.
- Command: `git diff --cached --check`
  Result: pass/no output. This is not applicable for staged changes because no files are staged.

Manual/source-scan guards:

- Command: `rg -n "IssueWaitingForIssueClose|ObservedIssueClosed|projectIssueImplementIssueClosedObservation" src/CodexWatcher/Daemon.hs test/Main.hs`
  Result: pass. Output shows the required item-023 daemon route at `src/CodexWatcher/Daemon.hs:568-570` and test coverage in `test/Main.hs`, including the daemon projection cases and indexed closed-issue matcher.
- Command: `rg -n "runIssueWaitingForIssueClose|retryCloseIssue|CloseIssue|SleepUntilNextPoll|waiting to observe closed issue|would close issue after merged PR" src/CodexWatcher/Domain/IssueImplement/Loop.hs test/Main.hs`
  Result: pass. Output shows `runIssueWaitingForIssueClose` and `retryCloseIssue` remain in `src/CodexWatcher/Domain/IssueImplement/Loop.hs`, with `CloseIssue` before `SleepUntilNextPoll`, unchanged dry-run text, unchanged execute idle text, and tests asserting those behaviors.
- Command: `rg -n "CodexWatcher.Workflow.Moifold.IssueImplement.Indexed|IssueImplementIndexedSpec|projectIssueImplement" src/CodexWatcher/Domain src/CodexWatcher/DaemonLoop src/CodexWatcher/AutomaticLoop`
  Result: pass. No matches, so indexed IssueImplement routing remains confined outside those domain/loop/automatic-loop modules.
- Command: `git diff --name-only | rg -n "^(orchestrator/state\\.json|src/CodexWatcher/(Domain/IssueImplement/Loop|DaemonLoop|AutomaticLoop|Repair|Healthcheck)|src/CodexWatcher/AutomaticLoop|src/CodexWatcher/DaemonLoop|test/.*(health|repair|fanout|child|lifecycle))" || true`
  Result: pass. No matching changed paths, so the round does not touch `orchestrator/state.json`, issue-close polling owner code, daemon-loop, automatic-loop, repair, healthcheck, fanout, or child lifecycle surfaces.

Plan compliance:

- `Daemon.hs` item-023 route: met. The new case matches `SomeWatcherState IssueWaitingForIssueClose {}` with `DaemonIssueImplementObservation (ObservedIssueClosed prNumber)` and calls `projectIssueImplementIssueClosedObservation`.
- `runIssueWaitingForIssueClose` and `retryCloseIssue` preservation: met. No implementation diff touches `src/CodexWatcher/Domain/IssueImplement/Loop.hs`; source scan confirms the existing polling, close retry, dry-run text, and idle text remain present.
- Daemon parity tests: met. `workflowIssueImplementIndexedDaemonDryRunAndExecuteMatchIssueCloseProjections` covers successful close and wrong-PR close blocking in both dry-run and execute modes, checking compatibility/indexed event parity, effect/action/request-id parity, final state labels, replay source state, compatibility writes, and commit/write behavior.
- Automatic close polling behavior: met. `automaticIssueMergeWaitsForIssueClose` now asserts open remote issue close-before-sleep ordering, execute idle text after close, dry-run close command rendering, no premature `IssueClosedEvent`, closed remote detection, terminal complete phase, and closed-observation projection parity with `StopDaemon`.
- Source-scan guards: met. Required item-020 through item-023 daemon projector names are present, item-024 blocked routing remains forbidden, and indexed imports/projectors are absent from domain/daemon-loop/automatic-loop modules.
- Scope boundaries: met. The diff does not change GitHub close semantics, issue terminal success criteria, child lifecycle, repair, healthcheck, fanout, lifecycle hardening, compatibility write ownership, public event schema, daemon result constructors, dry-run rendering, or runtime command rendering.

### Decision

**APPROVED**
