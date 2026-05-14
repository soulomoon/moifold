### Checks Run
- Command: `sed -n '1,260p' orchestrator/roles/reviewer.md`
  Result: pass; reviewer contract loaded and requires round diff review, all baseline/task checks, `review.md`, and approved `review-record.json`.
- Command: `sed -n '1,240p' orchestrator/rounds/round-192/selection.md`
  Result: pass; selected item is `direction-011i-cli-spec-core-ids-import` under roadmap `2026-05-11-00-highest-value-cleanup` revision `rev-002`.
- Command: `sed -n '1,260p' orchestrator/rounds/round-192/plan.md`
  Result: pass; plan limits implementation to replacing the `CodexWatcher.Core.Ids` import in `test/CliSpec.hs` with direct owner imports for `ThreadId`, `IssueNumber`, and `RepoName`.
- Command: `sed -n '1,260p' orchestrator/rounds/round-192/implementation-notes.md`
  Result: pass; implementer reports an import-only `test/CliSpec.hs` change and no parser or aggregate-wiring changes.
- Command: `sed -n '1,260p' orchestrator/project-contract.md`
  Result: pass; public compatibility facade availability and highest-value cleanup sequencing remain the active invariant.
- Command: `sed -n '1,260p' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-002/verification.md`
  Result: pass; required baselines and milestone-004 test/fixture `Core.Ids` import checks loaded.
- Command: `git diff --name-status`
  Result: pass; tracked diff contains `orchestrator/state.json` round metadata and `test/CliSpec.hs`.
- Command: `git diff -- test/CliSpec.hs`
  Result: pass; diff removes `CodexWatcher.Core.Ids (IssueNumber (..), RepoName (..), ThreadId (..))` and adds `CodexWatcher.Workflow.Agent.Ids (ThreadId (..))` plus `CodexWatcher.Workflow.GitHub.Ids (IssueNumber (..), RepoName (..))`.
- Command: `git diff --unified=0 -- test/CliSpec.hs`
  Result: pass; zero-context diff is import-only with two added direct-owner imports and one removed facade import.
- Command: `git diff -- test/Main.hs`
  Result: pass; no output, so aggregate wiring file is unchanged.
- Command: `rg -n "CodexWatcher\\.Core\\.Ids" test/CliSpec.hs`
  Result: pass; no matches. `rg` exited 1 as expected for an empty match set.
- Command: `rg -n "IssueNumber|RepoName|ThreadId|prop_cliParses|prop_cliRejects" test/CliSpec.hs test/Main.hs`
  Result: pass; `test/CliSpec.hs` still exports and defines the CLI properties, imports direct id owners, and uses `ThreadId`, `RepoName`, and `IssueNumber` constructors. `test/Main.hs` still wires `quickCheckResult prop_cliParsesHealthcheckAndRunLoop`, `prop_cliParsesAppServerProbe`, `prop_cliRejectsBadDomain`, and `prop_cliParsesGenericRunnerGuardDomains`.
- Command: `rg -n "CodexWatcher\\.Core\\.Ids" src app test docs moifold.cabal cabal.project agent-workflow-core agent-workflow-codex agent-workflow-github examples/workflow-package-consumer`
  Result: pass; `test/CliSpec.hs` is absent. Remaining users are classified below.
- Command: `rg -n "CodexWatcher\\.Core\\.Ids" src app agent-workflow-core agent-workflow-codex agent-workflow-github examples/workflow-package-consumer`
  Result: pass; only `src/CodexWatcher/Core/Ids.hs` matched, which is the public compatibility facade module itself. No `app`, standalone package candidate, or example consumer users matched.
- Command: `rg -n "CodexWatcher\\.Core\\.Ids" test`
  Result: pass; remaining test users are `test/RuntimeSpec.hs`, `test/RuntimeCompatibilityFixtureSpec.hs`, `test/FacadeImportPolicySpec.hs`, and `test/Main.hs`, all out of this selected CLI slice.
- Command: `rg -n "CodexWatcher\\.Core\\.Ids" docs moifold.cabal cabal.project`
  Result: pass; remaining docs/Cabal/public-surface references are `moifold.cabal` exposed module entry and docs policy/release text. `cabal.project` has no match.
- Command: `cabal build all`
  Result: pass; command completed successfully with `Up to date`.
- Command: `cabal test watcher-core-test`
  Result: pass; `Test suite watcher-core-test: PASS`, 1 of 1 test suites and 1 of 1 test cases passed.
- Command: `git diff --check`
  Result: pass; no whitespace errors.
- Command: `git diff --cached --check`
  Result: pass; no staged diff and no whitespace errors.
- Command: `git diff --cached --name-status`
  Result: pass; no output, confirming nothing is staged.

### Plan Compliance
- Step 1, remove the `CodexWatcher.Core.Ids` import from `test/CliSpec.hs`: met. `rg -n "CodexWatcher\\.Core\\.Ids" test/CliSpec.hs` has no matches.
- Step 2, add direct owner imports for `ThreadId`, `IssueNumber`, and `RepoName`: met. `test/CliSpec.hs` imports `ThreadId (..)` from `CodexWatcher.Workflow.Agent.Ids` and `IssueNumber (..), RepoName (..)` from `CodexWatcher.Workflow.GitHub.Ids`.
- Step 3, leave `parseCliCommand` assertions unchanged: met. The selected-file diff is import-only; no assertion, default, option-name, parser-error, or guard-domain code changed.
- Step 4, leave `test/Main.hs` aggregate wiring unchanged: met. `git diff -- test/Main.hs` is empty and the scan shows all four CLI properties remain wired through `quickCheckResult`.
- Step 5, do not create `worker-plan.json`: met. The round artifact directory contains `selection.md`, `plan.md`, and `implementation-notes.md` before this review; no `worker-plan.json` is present.
- Scope boundary, do not touch runtime specs, policy/aggregator, source modules, docs, Cabal, public facade removal, runtime compatibility cleanup, fixture data, or milestone completion: met for implementation diff. The only implementation file diff is `test/CliSpec.hs`; `orchestrator/state.json` carries active round/review metadata.

### Decision
**APPROVED**

### Evidence
The integrated implementation change is exactly the selected import-owner migration in `test/CliSpec.hs`: one `CodexWatcher.Core.Ids` import was removed, and direct owner imports for `ThreadId`, `IssueNumber`, and `RepoName` were added. No CLI parser expectations, defaults, option names, parser rejection behavior, guard-domain assertions, or `test/Main.hs` aggregate wiring changed.

The selected-file facade scan is clean. The broad remaining-user scan no longer includes `test/CliSpec.hs`. Remaining `CodexWatcher.Core.Ids` references are classified as:

- Runtime tests: `test/RuntimeSpec.hs`, `test/RuntimeCompatibilityFixtureSpec.hs`.
- Policy/aggregator candidates: `test/FacadeImportPolicySpec.hs`, `test/Main.hs`.
- Docs/Cabal/public facade: `docs/agentic-workflow-framework/*`, `moifold.cabal`, and `src/CodexWatcher/Core/Ids.hs`.
- Production/app/package users: none beyond the public facade module itself; no `app`, `agent-workflow-*`, or example consumer matches.

Baseline verification passed: `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, and `git diff --cached --check` all completed successfully.
