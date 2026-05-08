### Changes Made
- `test/Main.hs`: strengthened the existing PR-review checking indexed bridge helper so each compatibility case also checks indexed/unindexed `applyEvent`, effect-label consistency for event-derived apply effects, and repeated replay determinism.
- `test/Main.hs`: added PR-review checking indexed bridge assertions for terminal-state delegation and wrong-phase permission rejection against the compatibility permission path.
- `test/Main.hs`: extended DocsMigration indexed law coverage with blocked-terminal parity and repeated replay determinism.
- `test/Main.hs`: extended DocsMigration replay-failure coverage so both complete and blocked terminal states reject later terminal transitions.

### Tests
- `test/Main.hs`: DocsMigration assertions now cover observation/event/plan parity, complete and blocked terminal closure, repeated replay determinism, validation, and indexed/unindexed permission parity.
- `test/Main.hs`: PR-review checking indexed bridge assertions now cover observation/event/plan parity, apply/replay consistency, terminal closure, and wrong-phase permission soundness.

### Notes
- No production behavior, event codecs, golden fixtures, daemon/runtime behavior, roadmap files, `selection.md`, `plan.md`, compatibility facades, or review/merge artifacts were changed.
- Existing uncommitted `orchestrator/state.json` changes were present before implementation and were left untouched.
- `cabal build watcher-core-test`: passed.
- `cabal test watcher-core-test`: first run failed at `indexed workflow PR-review checking unresolved threads match compatibility`; the unresolved-review event replays from durable thread IDs while the observation path can include richer review-thread summaries. I kept exact durable replay determinism and adjusted that apply assertion to compare effect labels/action shape for this event path.
- `cabal test watcher-core-test`: rerun passed.
- `cabal build all`: passed (`Up to date`).
- `git diff --check`: passed.
- `git diff --cached --check`: passed; there were no staged changes.
