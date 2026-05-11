### Changes Made
- `test/PrReviewLaunchCliSpec.hs`: added focused public-path coverage for PR-review launch CLI behavior: endpoint-backed worker/reviewer `thread/start`, refreshed thread-id persistence, dry-run child command rendering, and selected app-server failure formatting.
- `test/Main.hs`: wired `prReviewLaunchCliTests` into the watcher-core aggregate.
- `moifold.cabal`: added `PrReviewLaunchCliSpec` to `watcher-core-test` metadata.

### Tests
- `test/PrReviewLaunchCliSpec.hs`: verifies execute mode sends only the worker/reviewer command `thread/start` requests after session traffic is filtered, with request ids `9000` and `9001`, launch workdir, role-specific developer instructions, and persisted worker/reviewer ids in config/finalized manifest.
- `test/PrReviewLaunchCliSpec.hs`: verifies dry-run child command rendering for root and non-root app-server paths, including host, port, poll seconds, state paths, workdir, execute/loop flags, and pid file.
- `test/PrReviewLaunchCliSpec.hs`: verifies JSON-RPC and decode failures are formatted through the public execute path and stop before the reviewer request when the worker start fails.

### Notes
No production files were edited. The successful execute test writes a live `runtime-owner.json` lease for the current test process before launch so the public child-start path restores `watcher.pid` instead of spawning a child daemon. Developer-instruction assertions follow the existing rendered prompt contract; state paths are asserted through launch command/config/manifest persistence rather than adding prompt behavior.
