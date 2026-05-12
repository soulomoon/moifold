### Source Round
- Round id: `round-146`
- Merged commit: `399d574` (`Import AppServerTurn directly in WorkflowAgentSpec`)
- Evidence: `orchestrator/rounds/round-146/selection.md`, `orchestrator/rounds/round-146/plan.md`, `orchestrator/rounds/round-146/implementation-notes.md`, `orchestrator/rounds/round-146/review.md`, `orchestrator/rounds/round-146/review-record.json`, `orchestrator/rounds/round-146/merge.md`, and the merged squash commit `399d574`.

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-001`
- Proposed revision: `rev-001`
- Files changed: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`, `orchestrator/roadmap-updates/round-146-roadmap-update.md`

### Rationale
Round 146 completed the `round-146-workflow-agent-spec-appserverturn-direct-owner-migration` slice under `milestone-003-import-convergence-package-boundaries` / `direction-010-appserverclient-import-convergence` by migrating only `test/WorkflowAgentSpec.hs` away from the exact `CodexWatcher.AppServerClient (AppServerTurn (..))` compatibility-facade import.

The merged change is status-only for the active roadmap revision. Review evidence records that the selected test now imports `AppServerTurn (..)` from `CodexWatcher.Workflow.Agent.Codex.Client`; the workflow agent role, worker/reviewer turn-classifier, observation-kernel, app-server turn-read assertions, and `workflowAgentTests` remain reachable; the selected test diff is import-only; the broad `CodexWatcher.AppServerClient` scan no longer lists `test/WorkflowAgentSpec.hs`; remaining hits are expected out-of-scope public facade/exposure, policy scanner entries, other tests/helpers, and test-suite references; and `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and `git diff --cached --check` passed.

This update does not change future coordination enough to require a new roadmap revision. It records another concrete internal AppServerClient direct-owner migration and preserves the operator steering: future selections should prefer lawful concrete migration or removal slices over readiness-only gate work where accepted evidence makes the slice lawful. Milestone 003 and direction 010 remain in progress because public facade/exposure, Cabal exposure, package descriptor cleanup, docs/policy references, broader workflow specs, `test/Main.hs`, remaining test support surfaces, milestone completion, release approval, terminal completion, and public compatibility removal remain unapproved.

This update does not approve public `CodexWatcher.AppServerClient` facade removal/deprecation, Cabal exposure removal, public API cleanup, package descriptor cleanup, docs/policy cleanup, release approval, milestone completion, terminal completion, or public compatibility removal.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
