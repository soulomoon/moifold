### Source Round
- Round id: `round-140`
- Merged commit: `2bf7bee` (`Move test app-server endpoint helper to direct transport owner`)
- Evidence: `orchestrator/rounds/round-140/selection.md`, `orchestrator/rounds/round-140/plan.md`, `orchestrator/rounds/round-140/implementation-notes.md`, `orchestrator/rounds/round-140/review.md`, `orchestrator/rounds/round-140/review-record.json`, `orchestrator/rounds/round-140/merge.md`, and the merged squash commit `2bf7bee`.

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-001`
- Proposed revision: `rev-001`
- Files changed: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`, `orchestrator/roadmap-updates/round-140-roadmap-update.md`

### Rationale
Round 140 completed the `round-140-test-support-appserver-endpoint-direct-owner-migration` slice under `milestone-003-import-convergence-package-boundaries` / `direction-010-appserverclient-import-convergence` by migrating only `test/TestSupport/AppServer.hs` away from the exact `CodexWatcher.AppServerClient (AppServerEndpoint (..))` compatibility-facade import.

The merged change is status-only for the active roadmap revision. Review evidence records that the helper now imports `AppServerEndpoint (..)` from `CodexWatcher.Workflow.Agent.Codex.Transport`; helper exports and endpoint construction remain unchanged; the broad AppServerClient import scan no longer lists `test/TestSupport/AppServer.hs`; remaining hits are out of scope; and `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and `git diff --cached --check` passed.

This update does not change future coordination enough to require a new roadmap revision. It records another concrete internal AppServerClient direct-owner migration and preserves the operator steering: future selections should prefer lawful concrete migration or removal slices over readiness-only gate work where evidence already makes the slice lawful. Milestone 003 and direction 010 remain in progress because public facade/exposure, Cabal exposure, docs/policy references, policy tests, and other out-of-scope test imports remain.

This update does not approve public `CodexWatcher.AppServerClient` facade removal/deprecation, Cabal exposure removal, public API cleanup, package descriptor cleanup, docs/policy cleanup, release approval, milestone completion, terminal completion, or public compatibility removal.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
