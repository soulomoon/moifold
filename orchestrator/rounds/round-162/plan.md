### Goal
Migrate only `src/CodexWatcher/Domain/IssuePlanning/Watcher.hs` off the combined `CodexWatcher.Core.Ids` compatibility facade by importing `IssueNumber` from `CodexWatcher.Workflow.GitHub.Ids` and `ThreadId`/`TurnId` from `CodexWatcher.Workflow.Agent.Ids`.

This round belongs to roadmap `2026-05-11-00-highest-value-cleanup`, revision `rev-001`, milestone `milestone-003-import-convergence-package-boundaries`, direction `direction-011-core-ids-import-convergence`, extracted item `round-162-issue-planning-watcher-core-ids-split-import-migration`.

### Approach
Keep the implementation as a behavior-preserving import migration. Do not touch any function bodies, exported names, event constructors, state-machine transitions, planning graph validation logic, issue-number rendering, `selectIssueImplementationStarts`, or error text.

Use the direct owner modules that already provide the same identifiers:

- `CodexWatcher.Workflow.GitHub.Ids (IssueNumber (..))`
- `CodexWatcher.Workflow.Agent.Ids (ThreadId, TurnId)`

Leave `CodexWatcher.Core.Ids` itself exposed and unchanged. Do not migrate other facade users, do not edit tests, package descriptors, docs, roadmap status, or compatibility policy in this round. Shared compatibility and package-boundary invariants remain governed by `orchestrator/project-contract.md`.

Worker fan-out is not justified: the selected work is a single-file import migration with no non-overlapping implementation ownership boundary.

### Steps
1. Edit `src/CodexWatcher/Domain/IssuePlanning/Watcher.hs` only.
2. Replace `import CodexWatcher.Core.Ids (IssueNumber (..), ThreadId, TurnId)` with:
   - `import CodexWatcher.Workflow.Agent.Ids (ThreadId, TurnId)`
   - `import CodexWatcher.Workflow.GitHub.Ids (IssueNumber (..))`
3. Preserve all other imports unless the formatter or compiler requires ordering-only cleanup.
4. Confirm no body-level diff exists in `src/CodexWatcher/Domain/IssuePlanning/Watcher.hs`; the diff should be import-only.
5. Do not create, delete, deprecate, or modify any compatibility facade, runtime compatibility file, Cabal exposed-module entry, roadmap file, state file, or test module.
6. Record implementation notes with the exact changed file, import-only scope, verification commands, and remaining `CodexWatcher.Core.Ids` users from the post-change scan.

### Verification
Run the baseline checks required for production-code cleanup in the active roadmap verification file:

- `cabal build all`
- `cabal test watcher-core-test`
- `git diff --check`
- `git diff --cached --check` if staging is involved

Run import-convergence checks and record their output in the implementation notes:

- `rg -n "CodexWatcher\\.Core\\.Ids" src/CodexWatcher/Domain/IssuePlanning/Watcher.hs` should produce no matches.
- `rg -n "import CodexWatcher\\.Core\\.Ids" src app test docs moifold.cabal cabal.project agent-workflow-core agent-workflow-codex agent-workflow-github examples` should list the remaining facade users and must not list `src/CodexWatcher/Domain/IssuePlanning/Watcher.hs`.

Review the diff and existing focused coverage expectations:

- `issuePlanningObserve` behavior remains covered by watcher-core tests for turn start/completion, retry, issue creation, graph update, blocked out-of-scope graphs, and scoped dependency closure.
- `selectIssueImplementationStarts` behavior remains covered by watcher-core tests for max-parallel selection and active issue skipping.
- Existing planning-graph validation and issue-number rendering error text must remain byte-for-byte unchanged.
