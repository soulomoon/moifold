### Changes Made
- `test/ObserveCommandSpec.hs`: added focused black-box `observeOnce` coverage for execute-mode endpoint rejection, dry-run fallback without an endpoint, and execute-mode endpoint-backed app-server traffic.
- `test/Main.hs`: wired the new observe command aggregate into `watcher-core-test` while preserving the existing observe parsing coverage.
- `moifold.cabal`: added `ObserveCommandSpec` to the `watcher-core-test` `other-modules` metadata.

### Tests
- `test/ObserveCommandSpec.hs`: verifies execute mode without an endpoint fails with the required flag message, dry-run without an endpoint succeeds with one dry-run action, and execute mode with a configured endpoint reaches the fake app-server session and planner `turn/start` request.

### Notes
No production seam was needed. `src/CodexWatcher/Cli/Command/Observe.hs` was not edited, and no import migration was performed.
