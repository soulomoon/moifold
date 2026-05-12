### Source Round
- Round id: `round-144`
- Merged commit: `03ff2bc` (`Move RunnerGuardSpec to AppServerClient owner imports`)
- Evidence: `orchestrator/rounds/round-144/selection.md`, `orchestrator/rounds/round-144/plan.md`, `orchestrator/rounds/round-144/implementation-notes.md`, `orchestrator/rounds/round-144/review.md`, `orchestrator/rounds/round-144/review-record.json`, `orchestrator/rounds/round-144/merge.md`, and the merged squash commit `03ff2bc`.

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-001`
- Proposed revision: `rev-001`
- Files changed: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`, `orchestrator/roadmap-updates/round-144-roadmap-update.md`

### Rationale
Round 144 completed the `round-144-runner-guard-spec-appserverclient-direct-owner-migration` slice under `milestone-003-import-convergence-package-boundaries` / `direction-010-appserverclient-import-convergence` by migrating only `test/RunnerGuardSpec.hs` away from the exact `CodexWatcher.AppServerClient (AppServerClientFailure (..), AppServerEndpoint, JsonRpcError (..), formatAppServerClientFailure)` compatibility-facade import.

The merged change is status-only for the active roadmap revision. Review evidence records that the selected test now imports `AppServerClientFailure (..)`, `JsonRpcError (..)`, and `formatAppServerClientFailure` from `CodexWatcher.Workflow.Agent.Codex.Client`, and imports `AppServerEndpoint` from `CodexWatcher.Workflow.Agent.Codex.Transport`; RunnerGuard active-turn inspection, materialization fallback, problem mapping, app-server failure formatting, repair-launch sequencing, endpoint-backed fake app-server behavior, and guard config helper assertions remain reachable; the broad AppServerClient import scan no longer lists `test/RunnerGuardSpec.hs`; remaining hits are expected out-of-scope public facade/exposure, other tests, docs, and policy references; and `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and `git diff --cached --check` passed.

This update does not change future coordination enough to require a new roadmap revision. It records another concrete internal AppServerClient direct-owner migration and preserves the operator steering: future selections should prefer lawful concrete migration or removal slices over readiness-only gate work where evidence already makes the slice lawful. Milestone 003 and direction 010 remain in progress because public facade/exposure, Cabal exposure, package descriptor cleanup, docs/policy references, broader workflow specs, `test/Main.hs`, remaining test support surfaces, milestone completion, release approval, terminal completion, and public compatibility removal remain unapproved.

This update does not approve public `CodexWatcher.AppServerClient` facade removal/deprecation, Cabal exposure removal, public API cleanup, package descriptor cleanup, docs/policy cleanup, release approval, milestone completion, terminal completion, or public compatibility removal.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
