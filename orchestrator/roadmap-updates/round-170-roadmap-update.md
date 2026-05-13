### Source Round
- Round id: `round-170`
- Merged commit: `cbf9cf6ff074d601f35a8c66ba94a3e611041e4c`
- Evidence: `orchestrator/rounds/round-170/selection.md`, `orchestrator/rounds/round-170/plan.md`, `orchestrator/rounds/round-170/implementation-notes.md`, `orchestrator/rounds/round-170/review.md`, `orchestrator/rounds/round-170/review-record.json`, and `orchestrator/rounds/round-170/merge.md`. Reviewer evidence approved a one-file import-only migration in `src/CodexWatcher/Domain/IssueImplement/Watcher.hs` from `CodexWatcher.Core.Ids (BranchName, CommitSha, PrNumber, ThreadId, TurnId)` to direct `CodexWatcher.Workflow.GitHub.Ids (BranchName, CommitSha, PrNumber)` and `CodexWatcher.Workflow.Agent.Ids (ThreadId, TurnId)`, with issue-implementation observation constructors, event construction, state-machine decisions, error text, declarations, function bodies, package descriptors, compatibility files, public facade modules, and public `Core.Ids` facade exposure unchanged, and validation passing `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, `git diff --cached --check`, focused import scans, remaining Core.Ids user scan, and package exposure checks.

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-001`
- Proposed revision: `rev-001`
- Files changed: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`

### Rationale
The merged round is status-only evidence for `milestone-003-import-convergence-package-boundaries` and `direction-011-core-ids-import-convergence`. It advances concrete import convergence by removing one production `CodexWatcher.Core.Ids` importer from issue-implementation watcher code, but it does not change future sequencing, milestone meaning, direction meaning, verification policy, retry policy, package descriptors, tests, docs, runtime behavior, public compatibility facades, public facade exposure, or removal gates.

The active roadmap therefore remains on `rev-001`: milestone 003 and direction 011 stay in progress, and the explicit non-approval boundaries remain intact. This update does not approve broader `Core.Ids` migration, public facade deprecation or removal, Cabal exposure cleanup, docs cleanup, package descriptor cleanup, runtime compatibility cleanup, release approval, milestone completion, terminal completion, or public compatibility removal.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
