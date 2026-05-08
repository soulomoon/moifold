### Changes Made
- `src/CodexWatcher/Workflow/Moifold/IssueImplement/Indexed.hs`: added the moifold-owned indexed IssueImplement adapter, indexed state/event/observation/effect/replay wrappers, compatibility transition projection, and typed projection helpers for the current IssueImplement policy points.
- `src/CodexWatcher/Workflow/Moifold/IssueImplement/Indexed.hs`: retry fix for waiting-for-merge PR-merged projection now selects the `IssueImplementIndexedPostMergeReviewReady` target marker when compatibility observes a reviewer-present post-merge-ready state, while keeping the no-reviewer branch on the pending-reviewer marker and preserving the same compatibility event/effects.
- `moifold.cabal`: exposed the new indexed IssueImplement adapter from the main moifold library.
- `src/CodexWatcher/Domain/IssueImplement/Watcher.hs`: aligned `ObservedPullRequestMerged` compatibility observations with the existing state-machine ignored-merge behavior for non-waiting IssueImplement states.
- `src/CodexWatcher/EventLog/Replay.hs`: aligned replay for ignored merged-PR events with the compatibility/state-machine behavior so indexed and compatibility replay effects match.
- `test/Main.hs`: added indexed-vs-compatibility IssueImplement parity coverage for policy transitions, invalid observations, final-review outcomes, replay/apply/effect validation/permission/dry-run/request-id behavior, compatibility writes, and a source-scan guard proving live daemon routing does not import the new adapter.
- `test/Main.hs`: retry expansion covers the full accepted observation/source-state matrix called out by the review: PR created/reused from ready and implementing states; PR body update from plan-ready, implementation-ready, and implementing; implementation blocked from ready and active turns; handoff initialized/started idempotence; implementation completed from implementing, handoff-ready, handoff-initialized, and waiting-for-merge; reviewer-thread-ready from handoff, waiting, and post-merge states; waiting-for-merge merged PR with and without reviewer; ignored merged PR from all accepted non-waiting states; generic blocked from every accepted non-terminal state; and wrong PR body update, wrong handoff, and wrong issue close blocking parity.

### Tests
- `test/Main.hs`: `workflowIssueImplementIndexedSpecMatchesCompatibilityForPolicyTransitions` checks indexed and compatibility parity for source/target/final labels, event labels, pre/post effects, replay effects, effect validation/permission, compatibility writes, dry-run reports, action ordering, and request-id behavior across IssueImplement policy transitions.
- `test/Main.hs`: `workflowIssueImplementIndexedSpecCoversInvalidObservationsLikeCompatibility` checks representative invalid observations fail like the compatibility facade and blocking observations produce the same blocked compatibility transition.
- `test/Main.hs`: `workflowIssueImplementIndexedAdapterDoesNotRouteLiveDaemonPaths` scans daemon/automatic-loop routing modules to keep this round adapter-only.
- Retry run: `cabal test watcher-core-test --test-option=--match --test-option='indexed workflow issue implement'`; passed. The harness still ran the full property list, but the focused IssueImplement rows were included and passed.
- Retry run: `cabal test watcher-core-test`; passed.
- Retry run: `cabal build all`; passed.
- Retry run: `git diff --check`; passed.
- Retry run: `git diff --cached --name-only`; no staged files, so `git diff --cached --check` was not required.

### Notes
The plan expected ignored merged-PR observations from several IssueImplement states. The state machine already treated those merged-PR events as sleep/idempotent, but the compatibility observer and replay layer did not expose every listed route. This round aligned those compatibility/replay surfaces before proving indexed parity. No live IssueImplement daemon path imports or calls the new indexed adapter, and `agent-workflow-core` was not changed.

Retry note: wrong PR body update is intentionally asserted in the invalid/blocking test helper rather than the replay/apply parity helper because the compatibility observation path blocks it, while event replay rejects that malformed body-update event. This preserves the current compatibility behavior instead of widening replay acceptance.
