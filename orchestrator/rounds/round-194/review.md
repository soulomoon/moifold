### Checks Run
- Command: `sed -n '1,220p' orchestrator/roles/reviewer.md`
  Result: pass; loaded reviewer contract requiring baseline checks, plan/diff review, and review artifacts only.
- Command: `sed -n '1,260p' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-002/verification.md`
  Result: pass; active verification requires `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, `git diff --cached --check`, selected-file import scans, broad remaining-user classification, and preservation of runtime compatibility fixture behavior.
- Command: `sed -n '1,240p' orchestrator/project-contract.md`
  Result: pass; confirmed compatibility facades, runtime compatibility files, fixture shapes, healthcheck reader boundaries, and package exposure remain protected unless explicitly selected.
- Command: `sed -n '1,220p' orchestrator/rounds/round-194/selection.md`
  Result: pass; selection is `direction-011i-runtime-compatibility-fixture-core-ids-import` under roadmap `2026-05-11-00-highest-value-cleanup`, revision `rev-002`, milestone `milestone-004-core-ids-test-and-fixture-import-burndown`.
- Command: `sed -n '1,260p' orchestrator/rounds/round-194/plan.md`
  Result: pass; plan limits the round to replacing the `CodexWatcher.Core.Ids` import in `test/RuntimeCompatibilityFixtureSpec.hs` with direct owner imports.
- Command: `sed -n '1,260p' orchestrator/rounds/round-194/implementation-notes.md`
  Result: pass; implementation notes report only the selected import migration and no behavior changes.
- Command: `git diff -- test/RuntimeCompatibilityFixtureSpec.hs`
  Result: pass; diff removes `CodexWatcher.Core.Ids` and adds `CodexWatcher.Workflow.Agent.Ids (ThreadId (..), TurnId (..))` plus `CodexWatcher.Workflow.GitHub.Ids (BranchName (..), IssueNumber (..), PrNumber (..), RepoName (..))`.
- Command: `git diff --stat && git diff --name-only`
  Result: pass; tracked diff contains `test/RuntimeCompatibilityFixtureSpec.hs` and pre-existing orchestrator state metadata, with no tracked fixture, source, docs, Cabal, or aggregate wiring changes.
- Command: `rg -n "CodexWatcher\\.Core\\.Ids|CodexWatcher\\.Workflow\\.(Agent|GitHub)\\.Ids" test/RuntimeCompatibilityFixtureSpec.hs`
  Result: pass; selected file contains only the direct owner imports at lines 40 and 41.
- Command: `rg -n "CodexWatcher\\.Core\\.Ids" test/RuntimeCompatibilityFixtureSpec.hs; printf 'exit=%s\n' $?`
  Result: pass; no selected-file matches, `rg` exit `1`.
- Command: `rg -n "CodexWatcher\\.Core\\.Ids" src app test agent-workflow-core agent-workflow-codex agent-workflow-github moifold.cabal orchestrator/rounds/round-194 orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-002`
  Result: pass; remaining live code/package users are `test/FacadeImportPolicySpec.hs`, `test/Main.hs`, `src/CodexWatcher/Core/Ids.hs`, and `moifold.cabal`, matching out-of-scope policy/aggregator/public-facade exposure surfaces. Roadmap and round docs also mention the facade as coordination text.
- Command: `git diff --exit-code -- test/Main.hs test/FacadeImportPolicySpec.hs moifold.cabal src/CodexWatcher/Core/Ids.hs; printf 'exit=%s\n' $?`
  Result: pass; exit `0`, aggregate wiring, policy spec, Cabal exposure, and public facade module are unchanged.
- Command: `git diff --check`
  Result: pass; no whitespace errors.
- Command: `git diff --cached --check`
  Result: pass; no staged whitespace errors.
- Command: `git diff --cached --name-only`
  Result: pass; no staged files.
- Command: `cabal build all`
  Result: pass; reported `Up to date`.
- Command: `cabal test watcher-core-test`
  Result: pass; `1 of 1 test suites (1 of 1 test cases) passed.` Runtime compatibility fixture PASS labels remained active, including fixture shape, repair-state, healthcheck reader boundary, daemon-state, block-state, runtime-owner, issue-snapshot, and planning graph assertions.

### Plan Compliance
- Remove the `CodexWatcher.Core.Ids` import from `test/RuntimeCompatibilityFixtureSpec.hs`: met; selected-file scan has no matches and diff shows the import removed.
- Add direct owner imports for `ThreadId` and `TurnId`: met; file imports `CodexWatcher.Workflow.Agent.Ids (ThreadId (..), TurnId (..))`.
- Add direct owner imports for `BranchName`, `IssueNumber`, `PrNumber`, and `RepoName`: met; file imports `CodexWatcher.Workflow.GitHub.Ids (BranchName (..), IssueNumber (..), PrNumber (..), RepoName (..))`.
- Keep fixture JSON, fixture paths, runtime compatibility writes, repair behavior, healthcheck reader boundary assertions, daemon-state assertions, planning graph assertions, PASS labels, helpers, export list, and test aggregate wiring unchanged: met; selected-file diff is import-only, aggregate/policy/public-surface diff check exits `0`, and `watcher-core-test` passes the runtime compatibility assertions.
- Do not edit `test/FacadeImportPolicySpec.hs`, `test/Main.hs`, source modules, docs, Cabal, public facade removal/deprecation, fixture JSON, or milestone completion: met for implementation scope; diff checks show those files/surfaces unchanged by this round, and remaining `Core.Ids` users are only out-of-scope policy/aggregator/public-exposure surfaces plus coordination docs.

### Decision
**APPROVED**

### Evidence
The round implements the selected import-only migration in `test/RuntimeCompatibilityFixtureSpec.hs` without weakening runtime compatibility coverage. The selected file no longer imports `CodexWatcher.Core.Ids`; it imports the required constructors from `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`. The broad remaining-user scan leaves `test/FacadeImportPolicySpec.hs`, `test/Main.hs`, `src/CodexWatcher/Core/Ids.hs`, and `moifold.cabal` untouched as explicitly out of scope. Baseline verification passed: `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, and `git diff --cached --check`.
