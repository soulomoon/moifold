### Findings

No blocking findings.

The implementation stays scoped to item-020 live IssueImplement implementation-turn daemon routing. `src/CodexWatcher/Daemon.hs` routes only these `IssueImplementationReady` and `IssueImplementing` observations through the moifold-owned indexed projection: worker refresh from implementation-ready, implementation turn start, blocked from ready, incomplete, blocked from implementing, and completed from implementing with or without a reviewer thread. Later review handoff, PR merge wait, post-merge review, follow-up, issue close, and child lifecycle observations remain on compatibility fallback.

### Verification Evidence

- Command: `cabal test watcher-core-test --test-option=--match --test-option='indexed workflow issue implement daemon'`
  Result: pass. Evidence included dry-run and execute parity for the plan/PR setup cases plus item-020 worker refresh, turn start, incomplete restart, blocked-from-ready, blocked-from-implementing, completed with reviewer thread, completed without reviewer thread, completed-before-known-PR incomplete behavior, and stale PR completion blocking. The output also showed the source-scan guard assertions passing.
- Command: `cabal test watcher-core-test --test-option=--match --test-option='automatic implementation'`
  Result: pass. Evidence covered live automatic-loop behavior for implementation start after PR body update, incomplete restart, missing-output blocking, and complete-without-known-PR staying incomplete.
- Command: `cabal test watcher-core-test --test-option=--match --test-option='implementation turn'`
  Result: pass. Evidence covered active-turn classification and implementation-turn handling.
- Command: `cabal test watcher-core-test --test-option=--match --test-option='indexed workflow issue implement daemon routing'`
  Result: pass. Evidence showed indexed IssueImplement routing remains out of `Loop.hs`, `DaemonLoop`, `DaemonLoop/ActiveTurn.hs`, `DaemonLoop/Runtime.hs`, `AutomaticLoop/Runner.hs`, and `AutomaticLoop/Output.hs`.
- Command: `cabal test watcher-core-test --test-option=--match --test-option='indexed workflow issue implement daemon does not route'`
  Result: pass. Evidence showed item-020 projectors are required in `Daemon.hs` and item-021+ projectors/observations remain absent there.
- Command: `cabal test watcher-core-test`
  Result: pass. Full core regression suite passed, including golden replay, event-log schema checks, package-boundary assertions, daemon surfaces, workflow transaction behavior, dry-run reporting, action ordering, request-id progression, and compatibility facades.
- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`.
- Command: `git diff --check`
  Result: pass. No whitespace errors.
- Command: `git diff --cached --quiet; code=$?; if [ $code -eq 0 ]; then printf 'no staged changes\n'; else git diff --cached --check; fi`
  Result: pass. Output: `no staged changes`.

Manual source scans:

- Command: `rg -n "CodexWatcher\\.Workflow\\.Moifold\\.IssueImplement\\.Indexed|projectIssueImplement|IssueImplementIndexedSpec" src/CodexWatcher/Domain/IssueImplement/Loop.hs src/CodexWatcher/DaemonLoop.hs src/CodexWatcher/DaemonLoop/ActiveTurn.hs src/CodexWatcher/DaemonLoop/Runtime.hs src/CodexWatcher/AutomaticLoop/Runner.hs src/CodexWatcher/AutomaticLoop/Output.hs || true`
  Result: pass. No matches, so indexed routing did not move into loop/runtime/automatic-loop modules.
- Command: `rg -n "projectIssueImplementWorkerThreadRefreshedImplementationReadyObservation|projectIssueImplementationTurnStartedObservation|projectIssueImplementationIncompleteObservation|projectIssueImplementationBlockedImplementationReadyObservation|projectIssueImplementationBlockedImplementingObservation|projectIssueImplementationCompletedImplementingObservation" src/CodexWatcher/Daemon.hs`
  Result: pass. Matches found at the item-020 `prepareDaemonObservation` routing block.
- Command: `rg -n "projectIssueImplementReviewHandoff|projectIssueImplementPullRequestMerged|projectIssueImplementReviewerThreadReady|projectIssueImplementPostMerge|projectIssueImplementIssueClosed|projectIssueImplementationCompletedHandoff|projectIssueImplementationCompletedWaitingForPrMerge|ObservedReviewHandoff|ObservedIssueReviewerThreadReady|ObservedPullRequestMerged|ObservedPostMerge|ObservedIssueClosed" src/CodexWatcher/Daemon.hs || true`
  Result: pass. No matches, so item-021+ routes remain compatibility fallback.
- Command: `rg -n "IssueConfig|IssueFinalReviewOutcome|WatcherEvent|SomeWatcherState|CodexWatcher\\.AppServerClient|CodexWatcher\\.Gh|Aeson|IssueImplement" agent-workflow-core src/Workflow src/Agent 2>/dev/null || true`
  Result: pass. No matches in `agent-workflow-core`; no concrete IssueImplement policy or moifold lifecycle ownership moved into core.

Plan compliance:

- Item-020 routing scope: met. `Daemon.hs` adds only the six requested item-020 projection calls and projects them back through `preparedFromIssueImplementProjection`.
- Compatibility fallback for item-021+: met. Review handoff, reviewer-thread-ready, PR merge wait, post-merge review, follow-up, issue close, later-state completed idempotence, and child lifecycle paths were not routed through indexed projection.
- Implementation-turn behavior preservation: met. Tests cover `StartIssueImplementationWorkerTurn`, active-turn reads, structured-output classification, missing-output blocking and `StopDaemon`, completed-before-known-PR incomplete behavior, stale PR blocking, restart-on-incomplete, request-id progression, and dry-run non-mutation.
- Daemon transaction/result surfaces: met. The projection harness compares compatibility and indexed events, planned pre/post effects, compiled request ids, replay source state, final labels, compatibility writes, execute appends, dry-run action reports, and audit labels for every covered case.
- Package boundary: met. No changes under `agent-workflow-core`; recursive boundary tests and manual scans show no concrete IssueImplement policy moved into core.
- Event JSON schemas/golden logs/facades: met. No golden, codec, schema, prompt, runtime-command, or compatibility facade files changed; full `watcher-core-test` passed the golden replay/schema coverage.

Notes:

- The worktree had a pre-existing modified `orchestrator/state.json` when review began. I did not modify it, per reviewer instruction.
- No files were staged.

### Decision

**APPROVED**
