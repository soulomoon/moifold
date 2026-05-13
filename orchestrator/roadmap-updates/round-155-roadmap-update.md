### Source Round
- Round id: `round-155`
- Merged commit: `1b711e1a00945b47257e2306b1bf16f4779a6afc`
- Evidence: `orchestrator/rounds/round-155/selection.md`, `orchestrator/rounds/round-155/plan.md`, `orchestrator/rounds/round-155/implementation-notes.md`, `orchestrator/rounds/round-155/review.md`, `orchestrator/rounds/round-155/review-record.json`, `orchestrator/rounds/round-155/merge.md`, and the merged squash commit `1b711e1a00945b47257e2306b1bf16f4779a6afc`.

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-001`
- Proposed revision: `rev-001`
- Files changed: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`, `orchestrator/roadmap-updates/round-155-roadmap-update.md`

### Rationale
Round 155 completed the `round-155-observe-command-spec-core-ids-split-import-migration` slice under `milestone-003-import-convergence-package-boundaries` / `direction-011-core-ids-import-convergence` by moving `test/ObserveCommandSpec.hs` off `CodexWatcher.Core.Ids (RepoName (..), ThreadId (..), TurnId (..), unThreadId)` to direct owner imports: `CodexWatcher.Workflow.GitHub.Ids (RepoName (..))` and `CodexWatcher.Workflow.Agent.Ids (ThreadId (..), TurnId (..), unThreadId)`.

This is a status-only update in the active revision. The accepted round changed one selected test import only and preserved observe-command dry-run, configured-endpoint, planner-thread, event-log, and app-server execution coverage, production files, package descriptors, docs/policy, public facade modules, and direct owner modules. Review evidence records the selected-file import replacement, no remaining `CodexWatcher.Core.Ids` import in `test/ObserveCommandSpec.hs`, continued selected public facade exposure and remaining `CodexWatcher.Core.Ids` users outside the selected file, `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, `git diff --cached --check`, focused import scans, and scope checks.

No new revision is proposed because round 155 does not change future coordination meaning, milestone or direction meaning, sequencing, parallel lanes, extraction scope, verification meaning, or retry policy. It records accepted status evidence for one concrete split-import direct-owner migration and keeps milestone 003 and direction 011 in progress. Future selections should continue to prefer lawful concrete migration/removal slices over readiness-only gate work when the active roadmap permits it.

This update does not approve public facade deprecation/removal, Cabal exposure cleanup, docs cleanup, package descriptor cleanup, broader `CodexWatcher.Core.Ids` migration, runtime compatibility cleanup, milestone completion, terminal completion, release approval, or public compatibility removal.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
