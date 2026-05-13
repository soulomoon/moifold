### Source Round
- Round id: `round-157`
- Merged commit: `ad82d27a13acc5aa70e8c68ad6965e48d65b49b2`
- Evidence: `orchestrator/rounds/round-157/selection.md`,
  `orchestrator/rounds/round-157/implementation-notes.md`,
  `orchestrator/rounds/round-157/review.md`, and
  `orchestrator/rounds/round-157/merge.md`. Reviewer evidence records passing
  `cabal test watcher-core-test`, `cabal build all`, `git diff --check`,
  `git diff --cached --check`, focused import scans, zero-context diff scope,
  and no staged files.

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-001`
- Proposed revision: `rev-001`
- Files changed:
  `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`
  and `orchestrator/roadmap-updates/round-157-roadmap-update.md`.

### Rationale
Round 157 completed one more lawful `direction-011-core-ids-import-convergence`
slice under in-progress milestone 003. The merged change moved only
`test/RunnerGuardSpec.hs` from the `CodexWatcher.Core.Ids` compatibility
facade to direct owner imports: `RepoName` from
`CodexWatcher.Workflow.GitHub.Ids` and `RequestId`, `ThreadId`, `TurnId`,
`unThreadId`, and `unTurnId` from `CodexWatcher.Workflow.Agent.Ids`.

The active roadmap coordination meaning does not change: milestone 003 remains
in progress, direction 011 remains in progress, and future work should continue
to prefer concrete lawful migration/removal slices over readiness-only gate
work when the active roadmap permits it. The status pointer records only this
approved migration and its validation. It does not approve public facade
deprecation or removal, Cabal exposure cleanup, docs cleanup, package
descriptor cleanup, broader Core.Ids migration, runtime compatibility cleanup,
milestone completion, terminal completion, release approval, or public
compatibility removal.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: not applicable
