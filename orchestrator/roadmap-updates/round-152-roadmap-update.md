### Source Round
- Round id: `round-152`
- Merged commit: `8c5c7f5`
- Evidence: `orchestrator/rounds/round-152/selection.md`, `orchestrator/rounds/round-152/plan.md`, `orchestrator/rounds/round-152/implementation-notes.md`, `orchestrator/rounds/round-152/review.md`, `orchestrator/rounds/round-152/review-record.json`, `orchestrator/rounds/round-152/merge.md`, and the merged squash commit `8c5c7f5`.

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-001`
- Proposed revision: `rev-001`
- Files changed: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`, `orchestrator/roadmap-updates/round-152-roadmap-update.md`

### Rationale
Round 152 completed the `round-152-appserver-probe-spec-agent-id-direct-owner-migration` slice under `milestone-003-import-convergence-package-boundaries` / `direction-011-core-ids-import-convergence` by moving `test/AppServerProbeSpec.hs` off `CodexWatcher.Core.Ids (ThreadId (..), unThreadId)` to the direct owner import `CodexWatcher.Workflow.Agent.Ids (ThreadId (..), unThreadId)`.

This is a status-only update in the active revision. The accepted round changed one selected test import only and preserved app-server probe command behavior, test bodies, helper code, request rendering, production files, package descriptors, docs/policy, public facade modules, and direct owner modules. Review evidence records the one-line selected-file diff, no remaining `CodexWatcher.Core.Ids` import in `test/AppServerProbeSpec.hs`, continued `CodexWatcher.Core.Ids` definition and Cabal exposure, remaining users outside the selected file, `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, and `git diff --cached --check`.

No new revision is proposed because round 152 does not change future coordination meaning, milestone or direction meaning, sequencing, parallel lanes, extraction scope, verification meaning, or retry policy. It records accepted status evidence for one concrete direct-owner import migration and keeps milestone 003 in progress. Future selections should continue to prefer lawful concrete migration/removal slices over readiness-only gate work when the active roadmap permits it.

This update does not approve public facade deprecation/removal, Cabal exposure cleanup, docs cleanup, package descriptor cleanup, broader `CodexWatcher.Core.Ids` migration, runtime compatibility cleanup, milestone completion, terminal completion, release approval, or public compatibility removal.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
