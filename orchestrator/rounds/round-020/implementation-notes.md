### Changes Made
- `src/CodexWatcher/Daemon.hs`: routed the item-020 live `IssueImplementationReady` and `IssueImplementing` daemon observations through the indexed IssueImplement projection adapter, covering implementation-ready worker refresh, implementation turn start, blocked-from-ready, incomplete, blocked-from-implementing, and completed-from-implementing observations.
- `test/Main.hs`: extended the existing item-019 daemon projection harness to cover item-020 implementation-worker projections in dry-run and execute modes, including worker refresh, turn start, incomplete restart, blocked paths, completion with and without reviewer thread, completed-before-known-PR incomplete behavior, and stale PR completion blocking.
- `test/Main.hs`: updated automatic daemon-loop checks for implementation start, incomplete restart, missing-output blocking, and complete-without-known-PR behavior while keeping live discovery in the loop modules unchanged.
- `test/Main.hs`: updated source-scan guards so item-020 projectors are required in `Daemon.hs`, item-021+ projectors and observations remain forbidden there, and indexed IssueImplement routing remains forbidden from loop/runtime/automatic-loop modules.

### Tests
- `test/Main.hs`: daemon projection harness verifies compatibility event parity, indexed event parity, planned effect parity, compiled request ids, final state labels, replay source state, compatibility writes, execute appends, and dry-run non-mutation for item-020 routes.
- `test/Main.hs`: automatic-loop tests verify `StartIssueImplementationWorkerTurn` scheduling, request-id progression, active-turn classification, restart-on-incomplete, missing-output blocking and stop behavior, and completed-before-known-PR incomplete behavior.
- `cabal test watcher-core-test --test-option=--match --test-option='indexed workflow issue implement daemon'`: passed.
- `cabal test watcher-core-test --test-option=--match --test-option='automatic implementation'`: passed.
- `cabal test watcher-core-test --test-option=--match --test-option='implementation turn'`: passed.
- `cabal test watcher-core-test`: passed.
- `cabal build all`: passed.
- `git diff --check`: passed.
- `git diff --cached --check`: not run because no files are staged.

### Notes
No core indexed APIs, event codecs, golden fixtures, compatibility facades, child lifecycle code, runtime command rendering, prompt schemas, or structured-output field requirements were changed. Review handoff, PR merge wait, post-merge review, follow-up, issue close, child lifecycle, and item-021+ routes remain on the existing compatibility fallback.
