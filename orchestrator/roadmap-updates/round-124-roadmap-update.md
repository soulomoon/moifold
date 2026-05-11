### Source Round
- Round id: `round-124`
- Merged commit: `fc2700a` (`Move PR-review launch off AppServerClient facade`)
- Evidence: `orchestrator/rounds/round-124/selection.md`, `orchestrator/rounds/round-124/plan.md`, `orchestrator/rounds/round-124/implementation-notes.md`, `orchestrator/rounds/round-124/review.md`, `orchestrator/rounds/round-124/review-record.json`, `orchestrator/rounds/round-124/merge.md`, and the merged squash commit at current `HEAD`.

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-001`
- Proposed revision: `rev-001`
- Files changed: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`, `orchestrator/roadmap-updates/round-124-roadmap-update.md`

### Rationale
Round 124 was accepted and merged as an import-only slice under `milestone-003-import-convergence-package-boundaries` / `direction-010-appserverclient-import-convergence`. It moved only `src/CodexWatcher/Domain/PrReview/LaunchCli.hs` from the public `CodexWatcher.AppServerClient` facade to direct owner imports from `CodexWatcher.Workflow.Agent.Codex.Client` and `CodexWatcher.Workflow.Agent.Codex.Transport`.

This changes roadmap status by recording `LaunchCli.hs` as migrated off the `CodexWatcher.AppServerClient` facade at merged commit `fc2700a`. The reviewed evidence records no code-body or behavior changes, no request-id or launch-plan persistence changes, no failure-formatting changes, and no package descriptor, public facade, direct owner module, protocol, runtime compatibility, docs, app, IssueFanout, test-policy, or test-support changes. Verification included target import scans, `git diff --unified=0` showing only import-line changes, `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, no worker plan, and state/review-record JSON checks.

This does not change sequencing enough to require a new roadmap revision: milestone 003 and direction 010 both remain in progress, and the next work still belongs to the existing import-convergence lane. Remaining `CodexWatcher.AppServerClient` users include `src/CodexWatcher/Cli/Command/IssueFanout.hs` plus test-policy and test-support imports. Round 124 does not approve IssueFanout migration, test-policy/support import migration, facade deprecation/removal, Cabal exposure cleanup, public API cleanup, docs cleanup, package descriptor cleanup, protocol/runtime/owner changes, milestone completion, release/publication, terminal completion, or public compatibility removal.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
