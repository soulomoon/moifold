### Changes Made
- `src/CodexWatcher/Workflow/Moifold/PrReview/Mergeability/Indexed.hs`: added blocked and complete target index markers so the existing mergeability indexed adapter can type the covered blocked and merge-terminal transitions while continuing to delegate behavior to `MoifoldSpec`.
- `test/Main.hs`: extended PR-review mergeability indexed parity coverage for retry, recheck, fix-required, blocked from waiting, blocked from merging, clean merge pre-commit, merge completion, invalid terminal observations, replay parity, effect validation/permission parity, effect label ordering, dry-run parity, request-id preservation, and merged compatibility write shape.

### Tests
- `test/Main.hs`: verifies indexed planning and observation parity against the compatibility PR-review path for `ObservedMergeabilityRetry`, `ObservedMergeabilityRecheck`, `ObservedMergeabilityFixRequired`, `ObservedPrReviewBlocked`, `ObservedMergeabilityClean`, and `ObservedMergeCompleted`.
- `test/Main.hs`: verifies invalid mergeability and merge-terminal observations fail like compatibility and produce no indexed plan.

### Notes
No daemon live paths were routed through the indexed adapter. Event schemas, golden logs, dry-run rendering, action ordering, request-id progression, compatibility facade exports, roadmap files, and `orchestrator/state.json` were left unchanged.
