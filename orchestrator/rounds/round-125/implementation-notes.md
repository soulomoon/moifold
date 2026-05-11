### Changes Made
- `test/IssueFanoutAppServerSpec.hs`: Added focused endpoint-backed IssueFanout coverage for app-server `thread/start` launches, request ids starting at `8000`, launch workdir `cwd`, developer instruction context, config/event/finalized manifest thread ids, child command rendering, retryable clone failure classification, app-server failure formatting, and the existing child-start classification source contract.
- `test/Main.hs`: Wired `issueFanoutAppServerTests` into the watcher-core test runner.
- `moifold.cabal`: Added `IssueFanoutAppServerSpec` to `watcher-core-test` `other-modules`.

### Tests
- `test/IssueFanoutAppServerSpec.hs`: Uses `withEndpointBackedAppServer` only; no real GitHub or remote app-server access. Workdir setup uses local git repositories so IssueFanout's existing workdir preparation path remains deterministic.
- `printf ':module + IssueFanoutAppServerSpec\nissueFanoutAppServerTests\n:quit\n' | cabal repl watcher-core-test`: Passed; GHCi loaded the watcher-core test modules and `issueFanoutAppServerTests` returned `True`.
- `cabal test watcher-core-test`: Passed.
- `cabal build all`: Passed.
- `git diff --check`: Passed.
- Scope guards passed: `IssueFanout.hs` still imports `CodexWatcher.AppServerClient`, `git diff -- src/CodexWatcher/Cli/Command/IssueFanout.hs` is empty, no `worker-plan.json` exists, and controller/round stage remains `implement`.

### Notes
No production code changed. `src/CodexWatcher/Cli/Command/IssueFanout.hs` still imports `CodexWatcher.AppServerClient`.

Direct runtime classification of `startIssueImplementerChildDetailed` would require a production test seam because the exported `StartChildLaunches` path starts the current executable as a daemon and waits on a pid file. This round keeps the stronger existing source-order assertion, mirrored in the new focused module, to prove `DaemonPidReady`, terminal-complete-before-ready, and non-running problem classification remain ordered as intended without adding production seams.
