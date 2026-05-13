### Source Round
- Round id: `round-159`
- Merged commit: `e15e76676e8cd33eeef06b33e9fd965b5e5ebcd3`
- Evidence: `orchestrator/rounds/round-159/selection.md`,
  `orchestrator/rounds/round-159/plan.md`,
  `orchestrator/rounds/round-159/implementation-notes.md`,
  `orchestrator/rounds/round-159/review.md`,
  `orchestrator/rounds/round-159/review-record.json`,
  `orchestrator/rounds/round-159/merge.md`, and the merged squash commit
  `e15e76676e8cd33eeef06b33e9fd965b5e5ebcd3`. Reviewer evidence records
  passing `cabal build all`, `cabal test watcher-core-test`,
  `git diff --check`, `git diff --cached --check`, focused import scans,
  scope checks, and facade availability checks.

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-001`
- Proposed revision: `rev-001`
- Files changed: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`, `orchestrator/roadmap-updates/round-159-roadmap-update.md`

### Rationale
Round 159 completed the
`round-159-runner-guard-command-core-ids-split-import-migration` slice under
`milestone-003-import-convergence-package-boundaries` /
`direction-011-core-ids-import-convergence` by moving only
`src/CodexWatcher/Cli/Command/RunnerGuard.hs` off
`CodexWatcher.Core.Ids (RepoName (..), ThreadId (..), TurnId (..))` to the
direct owner imports `CodexWatcher.Workflow.GitHub.Ids (RepoName (..))` and
`CodexWatcher.Workflow.Agent.Ids (ThreadId (..), TurnId (..))`.

This is a status-only update in the active revision. The accepted round
changed one selected production import block only and preserved runner-guard
command rendering, repair-thread reporting, function bodies, package
descriptors, tests, docs/policy, public facade modules, runtime compatibility
files, and direct owner modules. Review evidence records no remaining
`CodexWatcher.Core.Ids` import in
`src/CodexWatcher/Cli/Command/RunnerGuard.hs`, direct owner imports present in
that file, `CodexWatcher.Core.Ids` still present and exposed, `cabal build
all`, `cabal test watcher-core-test`, `git diff --check`,
`git diff --cached --check`, focused import scans, scope checks, and facade
availability checks.

No new revision is proposed because round 159 does not change future
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
