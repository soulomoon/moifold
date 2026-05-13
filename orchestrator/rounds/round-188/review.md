### Checks Run
- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`.
- Command: `cabal test watcher-core-test`
  Result: pass. `watcher-core-test` built and completed with `Test suite watcher-core-test: PASS`; `1 of 1 test suites (1 of 1 test cases) passed.`
- Command: `git diff --check`
  Result: pass with no whitespace errors.
- Command: `git diff --cached --check`
  Result: pass with no output. No files were staged, so the staged diff check was empty.
- Command: `rg -n "CodexWatcher.Core.Ids" test/WorkflowEventLogSpec.hs`
  Result: pass. The command exited 1 with no matches, which is the expected selected-file no-match result.
- Command: `rg -n "CodexWatcher.Core.Ids" src app test docs *.cabal cabal.project agent-workflow-core/agent-workflow-core.cabal agent-workflow-github/agent-workflow-github.cabal agent-workflow-codex/agent-workflow-codex.cabal examples/workflow-package-consumer/workflow-package-consumer.cabal examples/workflow-package-consumer/cabal.project`
  Result: pass for classification. Remaining users are test users (`test/WorkflowAgentSpec.hs`, `test/WorkflowExecutionSpec.hs`, `test/WorkflowIndexedSpec.hs`, `test/RuntimeSpec.hs`, `test/RuntimeCompatibilityFixtureSpec.hs`, `test/CliSpec.hs`, `test/Main.hs`, and policy evidence in `test/FacadeImportPolicySpec.hs`), docs references, `moifold.cabal`, and the public facade module definition `src/CodexWatcher/Core/Ids.hs`. No `app` users and no other production `src` users were found.
- Command: `git diff -- test/WorkflowEventLogSpec.hs`
  Result: pass. The diff removes `import CodexWatcher.Core.Ids` and adds direct imports from `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`; no assertions, fixtures, PASS labels, aggregate wiring, or event JSON expectations changed.
- Command: `git diff --name-status`
  Result: pass. The implementation/test surface changed only `test/WorkflowEventLogSpec.hs`; `orchestrator/state.json` contains control-plane metadata moving `round-188` into review.
- Command: `jq '{roadmap_id, roadmap_revision, roadmap_dir, stage, active_round_id, active_rounds}' orchestrator/state.json`
  Result: pass. State records roadmap id `2026-05-11-00-highest-value-cleanup`, revision `rev-002`, roadmap dir `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-002`, stage `review`, and active round `round-188`.

### Plan Compliance
- Remove `import CodexWatcher.Core.Ids` from `test/WorkflowEventLogSpec.hs`: met. Selected-file scan has no matches.
- Add direct owner imports for used ids: met. The file imports `CodexWatcher.Workflow.Agent.Ids (ThreadId (..), TurnId (..))` and `CodexWatcher.Workflow.GitHub.Ids (BranchName (..), CommitSha (..), IssueNumber (..), PrNumber (..), RepoName (..), ReviewThreadId (..))`.
- Preserve event-log assertions, fixture checks, PASS labels, aggregate wiring, event JSON expectations, and behavior: met. The selected-file diff is import-only, and `cabal test watcher-core-test` passed.
- Keep the round limited to the selected spec and avoid out-of-scope workflow specs, runtime/CLI tests, policy specs, source modules, docs, Cabal files, fixtures, and public facade exposure: met for implementation changes. The only code/test implementation diff is `test/WorkflowEventLogSpec.hs`; remaining `CodexWatcher.Core.Ids` users are classified as later test, policy/aggregator, docs, Cabal, or public facade work.
- Preserve roadmap and project-contract invariants: met. `CodexWatcher.Core.Ids` remains available and exposed; this round makes no deprecation, Cabal exposure removal, compatibility-file, event-schema, fixture, or public facade removal claim.

### Decision
**APPROVED**

### Evidence
The integrated selected-file diff is a narrow import migration: `CodexWatcher.Core.Ids` was removed from `test/WorkflowEventLogSpec.hs`, and direct id-owner imports were added for agent ids and GitHub ids. No behavior-bearing lines changed.

The required baseline and task-specific checks passed: `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, `git diff --cached --check`, and the selected-file `Core.Ids` scan.

The broad remaining-user scan supports milestone 004 evidence without expanding this round's scope. Remaining uses are in other tests, the policy/aggregator test, docs, `moifold.cabal`, and the public facade module itself; those are explicitly out of scope for `direction-011h-workflow-eventlog-spec-core-ids-import`.
