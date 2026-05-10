### Changes Made
- `golden/runtime-compatibility/block-state/repair-failure/block-state.json`: added a checked-in repair-failure `block-state.json` fixture for the deterministic invalid event-log replay failure shape.
- `test/RuntimeCompatibilityFixtureSpec.hs`: extended runtime compatibility fixture coverage to assert exact parity with `repairFailureBlockStateJson`, snapshot `NodeBlockedState` reader tolerance, repair-failure-specific fields, non-interchangeability with normal blocked writes, and current block-state source boundary interactions.

### Tests
- `test/RuntimeCompatibilityFixtureSpec.hs`: verifies the new fixture decodes as JSON, matches the generated repair-failure shape, preserves `blockedKind`, `eventIndex`, `eventType`, and embedded event `type`, remains distinct from normal `RecordBlocked` / `BlockedState` compatibility writes, and keeps healthcheck, snapshot, repair, restart, and automatic-loop block-state path assertions in place.

### Notes
No production behavior, roadmap files, controller state, Cabal exposure, healthcheck behavior, snapshot behavior, repair behavior, restart behavior, or compatibility file names were changed. An initial `cabal test watcher-core-test` attempt failed on an ambiguous local test record field and was fixed before the successful rerun.
