### Changes Made
- `src/CodexWatcher/Daemon.hs`: routed the approved IssueImplement handoff, reviewer-thread-ready, idempotent completion-after-handoff, and waiting-for-PR-merge observations through the indexed IssueImplement projection while leaving loop ownership and PR polling in the existing daemon loop.
- `test/Main.hs`: added focused dry-run and execute daemon parity coverage for the item-021 projection routes, extended automatic-loop merge-wait assertions, and updated source-scan guards to require item-021 projectors while forbidding item-022+ daemon routing.
- `orchestrator/rounds/round-021/implementation-notes.md`: recorded the implementation scope and verification evidence for the round.

### Tests
- `test/Main.hs`: daemon projection cases verify compatibility/indexed event parity, final state shape, effect plan and compiled request-id equality, execute commit/write ordering, compatibility writes, audit labels, wrong-PR blocking, reviewer reuse, and PR-merge transitions with and without an existing reviewer.
- `test/Main.hs`: automatic-loop coverage verifies open PR merge polling via `gh pr view`, idle text `waiting for PR merge before post-merge review: #7`, indexed merge transitions, existing reviewer reuse without new thread start, and indexed reviewer-thread-ready routing after merge.
- `test/Main.hs`: source-scan guards require item-021 daemon projectors, forbid item-022+ post-merge/close routes in `Daemon.hs`, and keep indexed IssueImplement routing out of `Loop.hs`, `DaemonLoop`, and `AutomaticLoop` modules.

### Notes
- Focused verification passed: `cabal test watcher-core-test --test-options='--pattern indexed workflow issue implement'`.
- Full baseline passed: `cabal test watcher-core-test`.
- Build passed: `cabal build all`.
- Whitespace check passed: `git diff --check`.
- Staged whitespace check: no staged files, so `git diff --cached --check` was not applicable.
- Manual source scans passed for no item-022+ daemon routes and no indexed IssueImplement imports/projectors outside `src/CodexWatcher/Daemon.hs`.
