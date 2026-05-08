### Changes Made
- `src/CodexWatcher/Workflow/Moifold/PrReview/Checking/Indexed.hs`: added a PR-review checking indexed adapter that wraps existing moifold state, events, daemon observations, observed ticks, effect plans, effects, and replay results while delegating behavior to `MoifoldSpec`.
- `moifold.cabal`: exposed the checking indexed adapter from the moifold library.
- `test/Main.hs`: added focused indexed parity coverage for unresolved review threads, no unresolved threads, review feedback from checking/queued/verification-checking states, verification start from the golden lifecycle prefix, invalid observation failures, replay state/effects, pre/post effect partitioning, effect labels, validation, and permission parity.

### Tests
- `test/Main.hs`: verifies PR-review checking indexed observation planning and replay stay aligned with the compatibility facade and `MoifoldSpec` for the roadmap-covered observations.
- `cabal build all`: passed.
- `cabal test watcher-core-test`: passed.
- `git diff --check`: passed.
- `git diff --cached --check`: passed.

### Notes
No daemon live paths were routed through the indexed adapter in this round. `orchestrator/state.json` was left untouched and unstaged as controller-owned dirty state.
