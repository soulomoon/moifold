### Changes Made
- `test/AutomaticLoopRunnerSpec.hs`: added focused runner coverage through `runAutomaticLoop` using `TestSupport.AppServer.withEndpointBackedAppServer`, temporary event/state/work dirs, and one-shot `LoopCli` scenarios for execute and dry-run modes.
- `test/Main.hs`: wired `automaticLoopRunnerTests` into the watcher-core aggregate.
- `moifold.cabal`: added `AutomaticLoopRunnerSpec` to `watcher-core-test` `other-modules`.

### Tests
- `test/AutomaticLoopRunnerSpec.hs`: verifies execute mode uses the configured endpoint-backed app-server, including per-request default initialization handshakes and planner `thread/start`/`turn/start` traffic.
- `test/AutomaticLoopRunnerSpec.hs`: verifies the same runner-level dry-run planning scenario exits successfully without sending live endpoint traffic.
- `test/AutomaticLoopRunnerSpec.hs`: verifies retry/fallback classification keeps app-server transport failures retryable while app-server decode/replay failures and unexpected start plans remain fatal.

### Notes
No production seam was needed, so `src/CodexWatcher/AutomaticLoop/Runner.hs` was not changed and its `CodexWatcher.AppServerClient` import was not migrated. The pre-existing `orchestrator/state.json` worktree modification was left untouched.
