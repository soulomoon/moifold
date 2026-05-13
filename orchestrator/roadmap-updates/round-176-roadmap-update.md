### Source Round
- Round id: `round-176`
- Merged commit: `b66f03c6c8947a99dd7119d9d7ae6a977c253a89`
- Evidence: reviewer approved the import-only migration of `src/CodexWatcher/StateMachine.hs`; `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, the focused selected-file scan, and the broad remaining-user scan passed; cached diff check was skipped because there were no staged changes.

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-001`
- Proposed revision: `rev-001`
- Files changed: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`; `orchestrator/roadmap-updates/round-176-roadmap-update.md`

### Rationale
This is a status-only update for `milestone-003-import-convergence-package-boundaries` and `direction-011-core-ids-import-convergence`. Round 176 records one additional production direct-owner import migration: only `src/CodexWatcher/StateMachine.hs` moved from the `CodexWatcher.Core.Ids` compatibility facade to `CodexWatcher.Workflow.GitHub.Ids` for `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, and `ReviewThreadId`, and to `CodexWatcher.Workflow.Agent.Ids` for `ThreadId`. State-machine events, decisions, validation, branch-attempt parsing/rendering, PR mismatch text, review-thread resolution, exports, constructors, package exposure, and public compatibility facade availability stayed unchanged. Milestone 003 remains in progress and direction 011 remains ongoing; this update does not claim broader `Core.Ids` migration, public deprecation/removal, Cabal exposure removal, runtime compatibility cleanup, release approval, milestone completion, or terminal completion.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: same `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`
