### Source Round
- Round id: `round-123`
- Merged commit: `eaf8348` (`Add PR-review launch app-server coverage`)
- Evidence: `orchestrator/rounds/round-123/selection.md`, `orchestrator/rounds/round-123/implementation-notes.md`, `orchestrator/rounds/round-123/review.md`, `orchestrator/rounds/round-123/review-record.json`, `orchestrator/rounds/round-123/merge.md`, and a live import scan over `src`, `app`, and `test`.

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-001`
- Proposed revision: `rev-001`
- Files changed: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`, `orchestrator/roadmap-updates/round-123-roadmap-update.md`

### Rationale
Round 123 was accepted and merged as a coverage-only slice under `milestone-003-import-convergence-package-boundaries` / `direction-010-appserverclient-import-convergence`. It adds focused watcher-core coverage for `src/CodexWatcher/Domain/PrReview/LaunchCli.hs` endpoint-backed PR-review worker/reviewer thread launch before any import migration: request ids `9000` and `9001`, role-specific developer instructions, refreshed worker/reviewer thread-id persistence, dry-run child command rendering for root and non-root app-server paths, and selected JSON-RPC/decode failure formatting.

This changes roadmap status by recording `LaunchCli.hs` as a production `CodexWatcher.AppServerClient` user that is now covered for a later import-only migration decision. It does not change sequencing enough to require a new roadmap revision: milestone 003 and direction 010 both remain in progress, and the next work still belongs to the existing import-convergence lane.

Live import scans after round 123 show `CodexWatcher.AppServerClient` remains used by production `src/CodexWatcher/Domain/PrReview/LaunchCli.hs` and `src/CodexWatcher/Cli/Command/IssueFanout.hs`, plus test-policy and test-support imports. The round does not approve LaunchCli import migration, IssueFanout migration, test-policy/support import migration, public facade removal/deprecation, Cabal/API exposure cleanup, docs/package cleanup, protocol/runtime/owner changes, milestone completion, release approval, terminal completion, or public compatibility removal.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
