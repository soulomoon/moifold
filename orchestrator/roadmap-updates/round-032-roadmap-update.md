### Source Round
- Round id: round-032
- Merged commit: 2f33153
- Evidence: `orchestrator/rounds/round-032/selection.md`,
  `orchestrator/rounds/round-032/plan.md`,
  `orchestrator/rounds/round-032/implementation-notes.md`,
  `orchestrator/rounds/round-032/review.md`,
  `orchestrator/rounds/round-032/review-record.json`,
  `orchestrator/rounds/round-032/merge.md`, and the squash commit `2f33153`.

### Roadmap Change
- Roadmap id: 2026-05-08-00-framework-kernel-migration
- Prior revision: rev-001
- Proposed revision: rev-001
- Files changed: `orchestrator/roadmaps/2026-05-08-00-framework-kernel-migration/rev-001/roadmap.md`

### Rationale
Round 032 completed `milestone-004-adapter-api-stabilization` direction
`direction-008-codex-agent-adapter-api` for extracted item
`item-032-codex-agent-adapter-api`. The approved and merged work stabilized
the Codex adapter API surface with the additive `agentTurnStartRef` helper,
focused app-server parser checks for malformed thread-start and turn-start
responses, typed `TurnRef` derivation and request-rendering coverage, and
stronger recursive boundary checks for `agent-workflow-codex`.

The review evidence records passing validation for `cabal build all`,
`cabal test watcher-core-test`, `git diff --check`, `git diff --cached --check`,
direct forbidden-token and forbidden-import scans over `agent-workflow-codex/src`,
and inspection of the thin `CodexWatcher.AppServerClient` compatibility facade.
The work kept app-server protocol and transport ownership in
`agent-workflow-codex` while leaving concrete moifold issue/PR lifecycle policy,
daemon/runtime ownership, healthcheck, repair, filesystem/process behavior, and
GitHub command policy outside that adapter package.

This update marks direction 008 complete. It does not complete milestone 004,
because `direction-009-github-adapter-api` remains pending, and it does not
change future milestone dependencies, parallel lanes, roadmap metadata, or
active revision activation. The next roadmap work remains the GitHub adapter API
stabilization slice before extraction readiness can begin.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
