### Source Round
- Round id: `round-126`
- Merged commit: `d881412`
- Evidence: `orchestrator/rounds/round-126/selection.md`, `orchestrator/rounds/round-126/plan.md`, `orchestrator/rounds/round-126/implementation-notes.md`, `orchestrator/rounds/round-126/review.md`, `orchestrator/rounds/round-126/review-record.json`, `orchestrator/rounds/round-126/merge.md`, merged squash commit `d881412`, and live post-merge `CodexWatcher.AppServerClient` scans.

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-001`
- Proposed revision: `rev-001`
- Files changed: `orchestrator/roadmap-updates/round-126-roadmap-update.md`, `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`

### Rationale
Round 126 completed the IssueFanout import-convergence slice under milestone `milestone-003-import-convergence-package-boundaries`, direction `direction-010-appserverclient-import-convergence`, by moving only `src/CodexWatcher/Cli/Command/IssueFanout.hs` from the public `CodexWatcher.AppServerClient` facade to direct owner imports from `CodexWatcher.Workflow.Agent.Codex.Client` and `CodexWatcher.Workflow.Agent.Codex.Transport`.

The merged change is status-only for the roadmap: it records that the final known production source `CodexWatcher.AppServerClient` import from the direction-010 queue has converged at commit `d881412`. Round evidence shows the implementation diff was import-only, preserved the round-125 app-server-backed IssueFanout behavior gate, and passed focused IssueFanout coverage, `cabal test watcher-core-test`, `cabal build all`, diff checks, and import guards.

Live scans after round 126 show no remaining production source imports of `CodexWatcher.AppServerClient`. Remaining hits are the public facade module and Cabal exposure, tests and test-support imports, and docs/policy references. These remaining hits are outside the round-126 import-only scope and keep milestone 003 and direction 010 in progress until the roadmap's public facade, Cabal/API, test-policy/support, docs, downstream, release/publication, and compatibility-removal gates are explicitly satisfied by later reviewed work.

This update does not approve test-policy or test-support migration, public facade deprecation or removal, Cabal/API cleanup, docs cleanup, package descriptor cleanup, protocol/runtime/owner changes, milestone completion, release approval, terminal completion, or public compatibility removal.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
