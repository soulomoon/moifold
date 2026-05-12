### Changes Made
- `test/WorkflowDocsMigrationSpec.hs`: replaced the `CodexWatcher.AppServerClient` compatibility-facade import with the direct owner import `CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn (..))`.

### Tests
- `test/WorkflowDocsMigrationSpec.hs`: no test bodies or helpers changed; `workflowDocsMigrationAgentRoleClassifiesCompleteOutput` still constructs `AppServerTurn`, and `workflowDocsMigrationTests` still includes that assertion.
- `rg -n "CodexWatcher\\.AppServerClient|AppServerTurn" test/WorkflowDocsMigrationSpec.hs`: before showed `23:import CodexWatcher.AppServerClient` and `978:        AppServerTurn`; after showed `23:import CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn (..))` and `978:        AppServerTurn`.
- Selected-file guard for `^import CodexWatcher\\.AppServerClient\\b`: passed; selected file no longer imports `CodexWatcher.AppServerClient`.
- `rg -n "^import CodexWatcher\\.Workflow\\.Agent\\.Codex\\.Client \\(AppServerTurn \\(\\.\\.\\)\\)" test/WorkflowDocsMigrationSpec.hs`: passed at line 23.
- `rg -n "workflowDocsMigrationAgentRoleClassifiesCompleteOutput|workflowDocsMigrationTests|AppServerTurn" test/WorkflowDocsMigrationSpec.hs`: confirmed exported test entry, preserved test list, direct import, and `AppServerTurn` usage.
- Broad remaining-facade inventory: `rg -n "CodexWatcher\\.AppServerClient" src app test docs agent-workflow-core agent-workflow-codex agent-workflow-github examples *.cabal cabal.project 2>/dev/null || true` still reports out-of-scope users in `moifold.cabal`, `src/CodexWatcher/AppServerClient.hs`, `test/BoundaryPolicySpec.hs`, `test/Main.hs`, `test/TestSupport/Workflow.hs`, `test/WorkflowAgentSpec.hs`, `test/WorkflowEventLogSpec.hs`, `test/WorkflowExecutionSpec.hs`, `test/WorkflowIndexedSpec.hs`, and docs policy/release/readiness files.
- `git diff -- test/WorkflowDocsMigrationSpec.hs`: one-line import replacement only.
- `git diff --name-only`: showed pre-existing `orchestrator/state.json` plus this round's changed `test/WorkflowDocsMigrationSpec.hs`; the new implementation notes are untracked and visible in `git status --short`, not in `git diff --name-only`.
- `cabal test watcher-core-test`: passed.
- `cabal build all`: passed.
- Optional focused GHCi check from the plan: skipped as redundant after `watcher-core-test` compiled and ran the changed spec and `cabal build all` passed.

### Notes
- Non-goals preserved: no public facade deprecation/removal, Cabal exposure cleanup, docs cleanup, package descriptor cleanup, milestone completion, release approval, terminal completion, or public compatibility removal.
- No production files, direct owner modules, package descriptors, docs/policy files, public facade exports, helper modules, or other test files were changed by this implementation.
