### Source Round
- Round id: `round-158`
- Merged commit: `245f4d8c2db8b8a7d0aedac994efe4ad5ca6d551`
- Evidence: `orchestrator/rounds/round-158/selection.md`,
  `orchestrator/rounds/round-158/plan.md`,
  `orchestrator/rounds/round-158/implementation-notes.md`,
  `orchestrator/rounds/round-158/review.md`,
  `orchestrator/rounds/round-158/review-record.json`,
  `orchestrator/rounds/round-158/merge.md`, and the merged squash commit
  `245f4d8c2db8b8a7d0aedac994efe4ad5ca6d551`. Reviewer evidence records
  passing `cabal build all`, `cabal test watcher-core-test`,
  `git diff --check`, `git diff --cached --check`, focused import scans, and
  scope checks.

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-001`
- Proposed revision: `rev-001`
- Files changed: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`, `orchestrator/roadmap-updates/round-158-roadmap-update.md`

### Rationale
Round 158 completed the
`round-158-observe-parser-core-ids-split-import-migration` slice under
`milestone-003-import-convergence-package-boundaries` /
`direction-011-core-ids-import-convergence` by moving only
`src/CodexWatcher/Cli/Parser/Observe.hs` off
`CodexWatcher.Core.Ids (CommitSha (..), PrNumber (..), TurnId (..))` to the
direct owner imports `CodexWatcher.Workflow.GitHub.Ids (CommitSha (..),
PrNumber (..))` and `CodexWatcher.Workflow.Agent.Ids (TurnId (..))`.

This is a status-only update in the active revision. The accepted round
changed one selected production import block only and preserved the observe
parser body, observe option surface, package descriptors, docs/policy, public
facade modules, runtime compatibility files, and direct owner modules. Review
evidence records no remaining `CodexWatcher.Core.Ids` import in
`src/CodexWatcher/Cli/Parser/Observe.hs`, direct owner imports present in that
file, `cabal build all`, `cabal test watcher-core-test`, `git diff --check`,
`git diff --cached --check`, focused import scans, and scope checks.

No new revision is proposed because round 158 does not change future
coordination meaning, milestone or direction meaning, sequencing, parallel
lanes, extraction scope, verification meaning, or retry policy. It records
accepted status evidence for one concrete production direct-owner import
migration and keeps milestone 003 and direction 011 in progress. Future
selections should continue to prefer lawful concrete migration/removal slices
over readiness-only gate work when the active roadmap permits it.

This update does not approve public facade deprecation/removal, Cabal exposure
cleanup, docs cleanup, package descriptor cleanup, broader
`CodexWatcher.Core.Ids` migration, runtime compatibility cleanup, milestone
completion, terminal completion, release approval, or public compatibility
removal.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
