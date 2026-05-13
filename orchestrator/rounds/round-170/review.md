### Checks Run
- Command: `git diff -- src/CodexWatcher/Domain/IssueImplement/Watcher.hs orchestrator/rounds/round-170/plan.md orchestrator/rounds/round-170/implementation-notes.md`
  Result: pass; the only tracked production diff is an import-only change in `src/CodexWatcher/Domain/IssueImplement/Watcher.hs`, replacing the `CodexWatcher.Core.Ids` import with direct owner imports from `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`. The round plan and implementation notes are new round artifacts and have no tracked base diff.
- Command: `rg -n "CodexWatcher\.Core\.Ids" src/CodexWatcher/Domain/IssueImplement/Watcher.hs`
  Result: pass; exit 1 with no matches, as expected.
- Command: `rg -n "CodexWatcher\.Workflow\.(GitHub|Agent)\.Ids" src/CodexWatcher/Domain/IssueImplement/Watcher.hs`
  Result: pass; found `CodexWatcher.Workflow.Agent.Ids (ThreadId, TurnId)` and `CodexWatcher.Workflow.GitHub.Ids (BranchName, CommitSha, PrNumber)`.
- Command: `cabal build all`
  Result: pass; command exited 0 and reported `Up to date`.
- Command: `cabal test watcher-core-test`
  Result: pass; command exited 0, `Test suite watcher-core-test: PASS`, `1 of 1 test suites (1 of 1 test cases) passed.`
- Command: `git diff --check`
  Result: pass; command exited 0 with no whitespace errors.
- Command: `git diff --cached --check`
  Result: pass; command exited 0 with no staged whitespace errors.
- Command: `rg -n "CodexWatcher\.Core\.Ids" src app test --glob '*.hs'`
  Result: pass; remaining `Core.Ids` users are outside the selected `IssueImplement.Watcher` slice and include expected production and test surfaces such as healthcheck, CLI, state machine, event log, runtime compatibility, PR review, issue planning, issue implementation loop, and tests.
- Command: `rg -n "CodexWatcher\.(Core\.Ids|Workflow\.(GitHub|Agent)\.Ids)" -g '*.cabal'`
  Result: pass; package exposure remains intact: `moifold.cabal` exposes `CodexWatcher.Core.Ids`, `agent-workflow-github/agent-workflow-github.cabal` exposes `CodexWatcher.Workflow.GitHub.Ids`, and `agent-workflow-codex/agent-workflow-codex.cabal` exposes `CodexWatcher.Workflow.Agent.Ids`.

### Plan Compliance
- Confirm the existing `Core.Ids` import listed `BranchName`, `CommitSha`, `PrNumber`, `ThreadId`, and `TurnId`: met; the diff removes exactly that import from `Watcher.hs`.
- Replace the facade import with direct owner imports: met; GitHub-owned identifiers now import from `CodexWatcher.Workflow.GitHub.Ids`, and agent-owned identifiers now import from `CodexWatcher.Workflow.Agent.Ids`.
- Leave declarations and function bodies unchanged: met; the production diff changes imports only.
- Confirm no remaining `CodexWatcher.Core.Ids` import in the edited file: met; focused `rg` returned no matches with exit 1.
- Confirm the only production code change is the import-owner migration: met; `git diff -- src/CodexWatcher/Domain/IssueImplement/Watcher.hs ...` shows only the import hunk in production code.

### Decision
**APPROVED**

### Evidence
The integrated round result matches the selected extraction for roadmap `2026-05-11-00-highest-value-cleanup` revision `rev-001`, milestone `milestone-003-import-convergence-package-boundaries`, direction `direction-011-core-ids-import-convergence`, extracted item `round-170-issue-implement-watcher-core-ids-split-import-migration`.

The production change is import-only in `src/CodexWatcher/Domain/IssueImplement/Watcher.hs`. It removes this module's dependency on the `CodexWatcher.Core.Ids` compatibility facade and imports the same identifier types from their direct owner modules. No observation constructors, event construction, state-machine decisions, error text, package descriptors, compatibility files, or public facade modules changed.

Baseline checks passed: `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, and `git diff --cached --check`. The compatibility facade remains exposed in `moifold.cabal`, and the direct owner modules remain exposed in their package descriptors, so this round does not imply deprecation, Cabal exposure removal, or public compatibility facade removal.
