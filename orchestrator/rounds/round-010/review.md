### Checks Run
- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`.
- Command: `cabal test watcher-core-test`
  Result: pass. The suite built and ran under GHC 9.12.2; `watcher-core-test` reported `PASS` and `1 of 1 test suites (1 of 1 test cases) passed`.
- Command: `git diff --check`
  Result: pass. No whitespace errors reported.
- Command: `git diff --cached --check`
  Result: pass. No staged whitespace errors reported.

### Plan Compliance
- Step 1, inspect current mergeability and terminal paths: met. Review covered the active diff in `src/CodexWatcher/Workflow/Moifold/PrReview/Mergeability/Indexed.hs` and the existing compatibility-backed tests in `test/Main.hs`; no daemon loop, state-machine, runtime compatibility, or public facade routing was changed.
- Step 2, extend typed points for covered transitions: met. The indexed adapter exports new `PrReviewIndexedBlocked` and `PrReviewIndexedComplete` markers, and tests type the required waiting, checking, fixing, merging, blocked, and complete transitions.
- Step 3, keep wrappers around existing moifold values: met. The adapter still wraps `SomeWatcherState`, `WatcherEvent`, `DaemonObservation`, `ObservedPolicyTick`, `SomeEffect`, `EffectPlan`, and `EventReplayResult`; no new event constructors, JSON fields, dry-run fields, daemon result constructors, or facade modules were added.
- Step 4, delegate indexed behavior to `MoifoldSpec`: met. `PrReviewMergeabilityIndexedSpec` continues delegating initial/apply event, observe, replay, validation, permission, labels, terminal checks, and planned transitions through `MoifoldSpec`, `legacyObservedPlannedTransition`, and `moifoldPlannedTransitionFromEffects`.
- Step 5, waiting-state observations: met. `watcher-core-test` passed assertions for `ObservedMergeabilityRetry`, `ObservedMergeabilityRecheck`, and `ObservedMergeabilityFixRequired`, including expected events, target labels, post-commit sleep or review-read/fix plans, replay parity, validation parity, permission parity, dry-run parity, and request-id preservation.
- Step 6, terminal merge completion: met. Tests cover `ObservedMergeCompleted` from `PrReview/Merging` to `PrReview/Complete`, event `PrReviewMergeCompleted`, `CompleteState (PrMerged mergeCommit)`, post-commit `[StopDaemon]`, replay parity, validation parity, permission parity, dry-run parity, and merged compatibility write shape.
- Step 7, stopped coverage: met by omission. The implementation did not introduce a PR-review stop-specific indexed path, and the plan made this conditional on modeling `StopWatcher` through this slice.
- Step 8, golden lifecycle helpers without modifying fixtures: met. The tests extend the golden prefix loader for `golden/event-log/pr-review/mlf2-pr6-merged/events.jsonl`; `git diff --name-only` shows no golden fixture edits.
- Step 9, focused indexed parity tests: met. The shared helper compares compatibility and indexed event, source label, target label, next state shape/label, pre-commit effects, post-commit effects, observed effects, replay state/effects, validation, permissions, compiled action ordering, dry-run reports, and request-id progression.
- Step 10, merge action ordering: met. The clean merge assertion preserves `MergePullRequest` as pre-commit, `GhPrCleanReviewAndMerge` as the planned command, empty post-commit effects before merge completion, and exact dry-run reports.
- Step 11, request-id progression: met. The new shared parity helper compiles each covered plan with metadata and verifies the compiled next request id matches legacy compilation, remains `RequestId 900`, and no covered action consumes an app-server request id.
- Step 12, daemon-loop parity as observation-surface evidence only: met. No live daemon routing changed. Existing daemon and dry-run tests still passed in `watcher-core-test`, including mergeability recheck, clean merge, unstable wait, fix-required, transient retry, and no accidental block-state writes surfaces.
- Step 13, invalid observations: met. Tests verify mismatched clean commits, merge completion outside merging, waiting observations outside waiting, and clean mergeability outside waiting fail like compatibility and produce no indexed plan.
- Step 14, final diff scope and unchanged surfaces: met with controller-state note. Implementation changes are limited to the indexed adapter and `test/Main.hs`; no event codecs, replay modules, daemon loops, runtime compatibility, dry-run rendering, command rendering, app-server/GitHub transport code, roadmap files, or golden fixtures changed. `orchestrator/state.json` already reflects the active review round dispatch; I did not edit it during review.

### Decision
**APPROVED**

### Evidence
The production indexed adapter change is limited to blocked and complete target markers while preserving delegation to `MoifoldSpec`. The passed `watcher-core-test` output includes the new focused assertions:

- `indexed workflow PR-review mergeability retry matches compatibility`
- `indexed workflow PR-review mergeability recheck matches compatibility`
- `indexed workflow PR-review mergeability fix-required matches compatibility`
- `indexed workflow PR-review mergeability clean matches compatibility from golden lifecycle`
- `indexed workflow PR-review mergeability blocked matches compatibility`
- `indexed workflow PR-review merging blocked matches compatibility`
- `indexed workflow PR-review merge completed matches compatibility`
- `indexed workflow PR-review merge completed preserves merged compatibility write shape`
- `indexed workflow PR-review mergeability clean keeps merge effect pre-commit`
- `indexed workflow PR-review mergeability clean rejects mismatched commit like facade`
- `indexed workflow PR-review merge completion outside merging fails like compatibility`
- `indexed workflow PR-review waiting observation outside waiting fails like compatibility`
- `indexed workflow PR-review mergeability clean outside waiting fails like compatibility`

The same suite also passed existing event-log golden type-field checks, daemon core projection checks, workflow metadata action-ordering/request-id/dry-run checks, and package-boundary/workflow facade tests, supporting preservation of event schemas, golden logs, daemon/dry-run surfaces, action ordering, request-id progression, and compatibility behavior.
