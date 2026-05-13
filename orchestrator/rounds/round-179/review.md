### Checks Run
- Command: `cabal build all`
  Result: pass; Cabal reported `Up to date`.
- Command: `cabal test watcher-core-test`
  Result: pass; the `watcher-core-test` suite completed successfully with `1 of 1 test suites (1 of 1 test cases) passed`. Log path: `dist-newstyle/build/aarch64-osx/ghc-9.12.2/moifold-0.1.0.0/t/watcher-core-test/test/moifold-0.1.0.0-watcher-core-test.log`.
- Command: `git diff --check`
  Result: pass; no whitespace errors reported.
- Command: `if git diff --cached --quiet; then printf 'NO_STAGED_CHANGES\n'; else git diff --cached --check; fi`
  Result: skipped staged diff check because there are no staged changes.
- Command: `rg -n "CodexWatcher\\.Core\\.Ids" src/CodexWatcher/Cli/Parser/Common.hs || true`
  Result: pass; no matches, so the selected file no longer imports or mentions `CodexWatcher.Core.Ids`.
- Command: `rg -n "CodexWatcher\\.Workflow\\.Agent\\.Ids" src/CodexWatcher/Cli/Parser/Common.hs`
  Result: pass; line 50 imports `ThreadId (..)` and `TurnId (..)` from `CodexWatcher.Workflow.Agent.Ids`.
- Command: `rg -n "CodexWatcher\\.Workflow\\.GitHub\\.Ids" src/CodexWatcher/Cli/Parser/Common.hs`
  Result: pass; line 51 imports `IssueNumber (..)`, `RepoName (..)`, and `ReviewThreadId (..)` from `CodexWatcher.Workflow.GitHub.Ids`.
- Command: `rg -n "import CodexWatcher\\.Core\\.Ids" src app test docs *.cabal agent-workflow-* 2>/dev/null || true`
  Result: pass for scope classification; remaining users are outside `src/CodexWatcher/Cli/Parser/Common.hs` and are listed under Evidence.
- Command: `rg -n "CliSpec|parseCliCommand|testGroup|defaultMain|TASTY|hspec|spec" test/Main.hs test/CliSpec.hs`
  Result: no reliable focused selector was discovered for only `CliSpec` because `watcher-core-test` uses a custom `test/Main.hs` runner; behavior evidence is the full `watcher-core-test` run plus the import-only diff.

### Plan Compliance
- Confirm only selected id usages in `Common.hs`: met. The old import supplied `IssueNumber`, `RepoName`, `ReviewThreadId`, `ThreadId`, and `TurnId`; the new imports supply the same constructors/types from direct owner modules.
- Replace the `CodexWatcher.Core.Ids` import with direct owner imports: met. `Common.hs` now imports agent ids from `CodexWatcher.Workflow.Agent.Ids` and GitHub ids from `CodexWatcher.Workflow.GitHub.Ids`.
- Make no other implementation edits to `Common.hs`: met. `git diff -- src/CodexWatcher/Cli/Parser/Common.hs` is import-only.
- Do not edit CLI types, fanout code, tests, fixtures, Cabal, docs, runtime compatibility files, or the public facade: met for implementation scope. The only implementation file diff is `src/CodexWatcher/Cli/Parser/Common.hs`; `src/CodexWatcher/Core/Ids.hs` remains an exposed compatibility facade.
- Preserve roadmap boundaries: met. This review treats the change as production import convergence only, not public deprecation, facade removal, Cabal cleanup, docs cleanup, runtime compatibility cleanup, milestone completion, release approval, or terminal completion.

### Decision
**APPROVED**

### Evidence
The implementation diff in `src/CodexWatcher/Cli/Parser/Common.hs` removes:

```haskell
import CodexWatcher.Core.Ids
  ( IssueNumber (..)
  , RepoName (..)
  , ReviewThreadId (..)
  , ThreadId (..)
  , TurnId (..)
  )
```

and adds:

```haskell
import CodexWatcher.Workflow.Agent.Ids (ThreadId (..), TurnId (..))
import CodexWatcher.Workflow.GitHub.Ids (IssueNumber (..), RepoName (..), ReviewThreadId (..))
```

No parser definitions, exports, option strings, defaults, error text, command rendering, dry-run text, child args, manifests, tests, docs, Cabal files, runtime compatibility files, or public facade files were changed by the implementation diff.

Focused CLI parser behavior evidence: `test/CliSpec.hs` exercises `parseCliCommand` for app-server probe thread ids, healthcheck repo parsing, run-loop repo/thread/scope issue parsing, guard parser behavior, bad domain rejection, and generic runner guard domains. No reliable narrower selector was available, so the full `cabal test watcher-core-test` pass plus the import-only diff is the behavior evidence for this round.

Broad remaining-user scan classification:

- Remaining production users: `src/CodexWatcher/EventLog/Types.hs`, `src/CodexWatcher/Runtime/Compatibility.hs`, `src/CodexWatcher/Healthcheck.hs`, `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`, `src/CodexWatcher/Domain/IssueImplement/Loop.hs`, `src/CodexWatcher/Cli/Types.hs`, and `src/CodexWatcher/Cli/Command/IssueFanout.hs`.
- Remaining tests/fixtures users: `test/FacadeImportPolicySpec.hs`, `test/WorkflowEventLogSpec.hs`, `test/RuntimeSpec.hs`, `test/CliSpec.hs`, `test/Main.hs`, `test/WorkflowIndexedSpec.hs`, `test/WorkflowExecutionSpec.hs`, `test/WorkflowAgentSpec.hs`, `test/TestSupport/Workflow.hs`, and `test/RuntimeCompatibilityFixtureSpec.hs`.
- Remaining docs/Cabal/package-candidate users from the requested import scan: none.
- Public facade: `src/CodexWatcher/Core/Ids.hs` remains intentionally available and re-exports `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`; this round does not approve facade removal or Cabal exposure cleanup.
