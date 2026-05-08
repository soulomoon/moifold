### Changes Made
- `agent-workflow-core/src/CodexWatcher/Workflow/Transaction/Core.hs`: extracted generic prepared dry-run and detailed execute transaction helpers so a caller can supply an already planned `PlannedTransition` while preserving validation, compile, action, commit, replay, callback, audit, and failure-stage behavior.
- `src/CodexWatcher/Workflow/Moifold/PrReview/Mergeability/Indexed.hs`: added a moifold-owned projection helper for `ObservedMergeabilityClean` from `PrReview/WaitingMergeability` to `PrReview/Merging`; it wraps the indexed state/observation, plans through the indexed adapter, and returns existing moifold planned transition, final state, labels, and effect plan.
- `src/CodexWatcher/Daemon.hs`: routes only `PrWaitingForMergeability` plus `DaemonPrReviewObservation (ObservedMergeabilityClean commit)` through the indexed projection, then uses the prepared transaction helpers to return the existing `DaemonObservedTickResult` and detailed failure surfaces. All other observations continue through `observeDaemonState`.

### Tests
- `test/Main.hs`: added indexed live daemon dry-run parity coverage for event, state, replay, labels, compiled merge effect, action report, compatibility writes, audit fields, request-id stability, and no interpreter calls.
- `test/Main.hs`: added indexed live daemon execute parity coverage for pre-commit merge ordering, event append, committed events, compatibility writes, post-commit reports, audit fields, and no app-server request usage.
- `test/Main.hs`: added indexed live daemon failure coverage for pre-commit merge failure, detailed transaction stage, planned event, no committed events, compiled effects, empty reports, audit recommendation, formatted failure text, and no append/write side effects.
- `test/Main.hs`: added invalid observation coverage for mismatched clean commit and clean observation outside `PrWaitingForMergeability`.

### Notes
No event schemas, golden logs, compatibility facade exports, dry-run rendering, runtime command rendering, roadmap files, or `orchestrator/state.json` were intentionally changed. `orchestrator/state.json` was already dirty and remains controller-owned.

Verification run:
- `cabal build all`: passed.
- `cabal test watcher-core-test`: passed.
