### Source Round
- Round id: `round-125`
- Merged commit: `8efbab4` (`Add IssueFanout app-server launch coverage`)
- Evidence: `orchestrator/rounds/round-125/selection.md`, `orchestrator/rounds/round-125/plan.md`, `orchestrator/rounds/round-125/implementation-notes.md`, `orchestrator/rounds/round-125/review.md`, `orchestrator/rounds/round-125/review-record.json`, `orchestrator/rounds/round-125/merge.md`, and the merged squash commit `8efbab4`.

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-001`
- Proposed revision: `rev-001`
- Files changed: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`, `orchestrator/roadmap-updates/round-125-roadmap-update.md`

### Rationale
Round 125 was accepted and merged as the coverage gate under `milestone-003-import-convergence-package-boundaries` / `direction-010-appserverclient-import-convergence` before any `IssueFanout.hs` import-only migration. It added focused watcher-core coverage for the app-server-backed `src/CodexWatcher/Cli/Command/IssueFanout.hs` child implementer launch path.

This changes roadmap status by recording the IssueFanout app-server launch coverage gate as complete at merged commit `8efbab4`. The reviewed evidence covers endpoint-backed `thread/start` launches, request ids starting at `8000`, launch workdir `cwd`, developer instruction context, persisted config/event/finalized manifest thread ids, child command rendering, retryable clone failure classification, fallback child-start classification ordering, and selected app-server failure formatting. Verification included focused REPL execution of `issueFanoutAppServerTests`, `cabal test watcher-core-test`, `cabal build all`, diff checks, import/no-production-diff guards for `IssueFanout.hs`, no-worker-plan guard, changed-path checks, and review-stage JSON checks.

This does not change sequencing enough to require a new roadmap revision: milestone 003 and direction 010 both remain in progress, and the next work still belongs to the existing import-convergence lane. `src/CodexWatcher/Cli/Command/IssueFanout.hs` remains the production `CodexWatcher.AppServerClient` source user now covered for a later import-only migration decision; it was not migrated in this round. Test-policy and test-support imports remain, and the public compatibility facade remains exposed. Round 125 does not approve IssueFanout migration, test-policy/support import migration, facade deprecation/removal, Cabal exposure cleanup, public API cleanup, docs cleanup, package descriptor cleanup, protocol/runtime/owner changes, milestone completion, release/publication, terminal completion, or public compatibility removal.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
