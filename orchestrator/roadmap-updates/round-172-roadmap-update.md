### Source Round
- Round id: `round-172`
- Merged commit: `cc412c1f02507e7a500fe2e232174cdde4a9e6e6`
- Evidence: `orchestrator/rounds/round-172/selection.md`, `orchestrator/rounds/round-172/plan.md`, `orchestrator/rounds/round-172/implementation-notes.md`, `orchestrator/rounds/round-172/review.md`, `orchestrator/rounds/round-172/review-record.json`, and `orchestrator/rounds/round-172/merge.md`. Reviewer evidence approved a one-file import-only migration in `src/CodexWatcher/RunnerGuard.hs` from `CodexWatcher.Core.Ids (RepoName (..), RequestId (..), ThreadId (..), TurnId (..))` to direct `CodexWatcher.Workflow.GitHub.Ids (RepoName (..))` and `CodexWatcher.Workflow.Agent.Ids (RequestId (..), ThreadId (..), TurnId (..))`, with runner-guard stale-turn checks, repair prompt rendering, app-server request sequencing, thread/turn parsing, event-log replay handling, JSON field names, package exposure, and public compatibility facade availability unchanged. Reviewer evidence passed `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, focused scans confirming `RunnerGuard.hs` no longer imports `Core.Ids`, and a remaining Core.Ids user scan confirming this is not completion or removal; `git diff --cached --check` was skipped because there were no staged changes.

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-001`
- Proposed revision: `rev-001`
- Files changed: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`

### Rationale
The merged round is status-only evidence for `milestone-003-import-convergence-package-boundaries` and `direction-011-core-ids-import-convergence`. It advances concrete import convergence by removing one production `CodexWatcher.Core.Ids` importer from runner-guard code, but it does not change future sequencing, milestone meaning, direction meaning, verification policy, retry policy, package descriptors, tests, docs, runtime behavior, public compatibility facades, public facade exposure, or removal gates.

The active roadmap therefore remains on `rev-001`: milestone 003 stays in progress and direction 011 stays ongoing. This update does not approve broader `Core.Ids` migration, public facade deprecation or removal, Cabal exposure cleanup, docs cleanup, package descriptor cleanup, runtime compatibility cleanup, release approval, milestone 003 completion, terminal completion, or public compatibility removal.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
