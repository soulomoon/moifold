### Checks Run
- Command: `python3 -m json.tool orchestrator/state.json`
  Result: pass. State JSON parses and records active roadmap lineage
  `2026-05-11-00-highest-value-cleanup` / `rev-001`, `controller_stage:
  update-roadmap`, no active rounds, source round `round-159`, source commit
  `e15e76676e8cd33eeef06b33e9fd965b5e5ebcd3`, prior revision `rev-001`,
  proposed revision `rev-001`, and roadmap-update status `review`.
- Command: `ls -1 orchestrator/state.json orchestrator/project-contract.md orchestrator/active-roadmap-bundle.md orchestrator/roles/reviewer.md orchestrator/roadmap-updates/round-159-roadmap-update.md orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md orchestrator/rounds/round-159/selection.md orchestrator/rounds/round-159/plan.md orchestrator/rounds/round-159/implementation-notes.md orchestrator/rounds/round-159/review.md orchestrator/rounds/round-159/review-record.json orchestrator/rounds/round-159/merge.md`
  Result: pass. Required state, contract, role, roadmap-update, active roadmap,
  verification, and round-159 artifacts exist.
- Command: `ls -1 orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/retry-subloop.md orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/roadmap-history.md`
  Result: pass. Active bundle required files and family history exist.
- Command: `python3 -m json.tool orchestrator/rounds/round-159/review-record.json`
  Result: pass. Round review record parses and records approved lineage for
  milestone `milestone-003-import-convergence-package-boundaries`, direction
  `direction-011-core-ids-import-convergence`, and extracted item
  `round-159-runner-guard-command-core-ids-split-import-migration`.
- Command: `git status --short --branch`
  Result: pass. Worktree is on
  `orchestrator/roadmap-update-round-159-highest-value-cleanup`; tracked
  changes before this review artifact were only `orchestrator/state.json` and
  the active `rev-001/roadmap.md`, with untracked
  `orchestrator/roadmap-updates/round-159-roadmap-update.md`.
- Command: `git diff --name-status`
  Result: pass. Tracked roadmap-update diff changes only
  `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`
  and `orchestrator/state.json`.
- Command: `git ls-files --others --exclude-standard`
  Result: pass. Untracked artifact before this review was only
  `orchestrator/roadmap-updates/round-159-roadmap-update.md`.
- Command: `git diff --name-only -- src app test docs moifold.cabal agent-workflow-core agent-workflow-codex agent-workflow-github`
  Result: pass with no output. The roadmap-update worktree has no production,
  test, docs, package descriptor, or package-candidate diff.
- Command: `git diff --check`
  Result: pass with no output.
- Command: `git diff --cached --check`
  Result: pass with no output.
- Command: `find orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup -maxdepth 2 -type d -print | sort`
  Result: pass. Only the family directory and `rev-001` exist; no new revision
  directory was created.
- Command: `find orchestrator/roadmap-updates -maxdepth 1 -type f -name '*round-159*' -print | sort`
  Result: pass. Only the round-159 update artifact existed before this review.
- Command: `rg -n '^### [0-9]+\\. \\[(pending|in-progress|completed|done)\\]' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`
  Result: pass. Milestone headings remain parseable; milestone 003 is
  `### 3. [in-progress] Import Convergence And Package-Boundary Cleanup`.
- Command: ``rg -n '^### 3\\. \\[in-progress\\] Import Convergence And Package-Boundary Cleanup|Milestone id: `milestone-003-import-convergence-package-boundaries`|Direction id: `direction-011-core-ids-import-convergence`|round-159-runner-guard-command-core-ids-split-import-migration|broader Core\\.Ids migration|public facade deprecation/removal|milestone completion|terminal completion|public compatibility removal' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md``
  Result: pass. The active roadmap records milestone 003 and direction 011 as
  live, records the round-159 one-file production migration, and repeats the
  non-approval boundaries for broader Core.Ids migration, public facade
  deprecation/removal, milestone completion, terminal completion, and public
  compatibility removal.
- Command: `git show --name-status --format=%H%n%P%n%s e15e76676e8cd33eeef06b33e9fd965b5e5ebcd3`
  Result: pass. Source commit exists, has parent
  `ec5aefdcebd6f12d04f095597a8f3549c5e29419`, subject `Round 159: Migrate
  RunnerGuard CLI command ID imports`, adds round artifacts, updates state, and
  modifies only one production file:
  `src/CodexWatcher/Cli/Command/RunnerGuard.hs`.
- Command: `git show --format= --unified=20 e15e76676e8cd33eeef06b33e9fd965b5e5ebcd3 -- src/CodexWatcher/Cli/Command/RunnerGuard.hs`
  Result: pass. The production source diff removes only
  `CodexWatcher.Core.Ids (RepoName (..), ThreadId (..), TurnId (..))` and adds
  direct owner imports from `CodexWatcher.Workflow.Agent.Ids` and
  `CodexWatcher.Workflow.GitHub.Ids`; no function bodies changed.
- Command: `rg -n '^import[[:space:]]+CodexWatcher\\.Core\\.Ids' src/CodexWatcher/Cli/Command/RunnerGuard.hs`
  Result: pass for absence. No matches; command exited 1 as expected.
- Command: `rg -n '^import[[:space:]]+CodexWatcher\\.Workflow\\.(Agent|GitHub)\\.Ids' src/CodexWatcher/Cli/Command/RunnerGuard.hs`
  Result: pass. Current file imports
  `CodexWatcher.Workflow.Agent.Ids (ThreadId (..), TurnId (..))` and
  `CodexWatcher.Workflow.GitHub.Ids (RepoName (..))`.
- Command: `rg -n '^module CodexWatcher\\.Core\\.Ids|CodexWatcher\\.Core\\.Ids' src/CodexWatcher/Core/Ids.hs moifold.cabal`
  Result: pass. `CodexWatcher.Core.Ids` remains present and exposed.

### Roadmap Compliance
- The update is valid as a status-only in-place update to active revision
  `rev-001`. It records accepted evidence for the merged round-159 source
  commit and does not change future coordination meaning, sequencing, parallel
  lanes, verification meaning, retry policy, milestone meaning, or direction
  meaning.
- The update records only the approved one-file production import migration in
  `src/CodexWatcher/Cli/Command/RunnerGuard.hs`: `RepoName` moved to
  `CodexWatcher.Workflow.GitHub.Ids`, and `ThreadId` / `TurnId` moved to
  `CodexWatcher.Workflow.Agent.Ids`.
- Milestone 003 remains `[in-progress]`, and direction 011 remains in progress.
  The update does not mark milestone 003, the roadmap, or the controller as
  complete.
- No new roadmap revision directory was created. State metadata also keeps
  `prior_roadmap_revision` and `proposed_roadmap_revision` at `rev-001`.
- The update explicitly does not approve broader `CodexWatcher.Core.Ids`
  migration, public facade deprecation/removal, Cabal exposure cleanup, docs
  cleanup, package descriptor cleanup, runtime compatibility cleanup, release
  approval, milestone completion, terminal completion, or public compatibility
  removal.

### Decision
**APPROVED**
