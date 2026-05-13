### Checks Run
- Command: `python3 -m json.tool orchestrator/state.json >/dev/null`
  Result: pass; state JSON is parseable.
- Command: `git diff -- src/CodexWatcher/RunnerGuard.hs`
  Result: pass; diff only removes `import CodexWatcher.Core.Ids (RepoName (..), RequestId (..), ThreadId (..), TurnId (..))` and adds `CodexWatcher.Workflow.Agent.Ids (RequestId (..), ThreadId (..), TurnId (..))` plus `CodexWatcher.Workflow.GitHub.Ids (RepoName (..))`.
- Command: `rg -n '^import CodexWatcher\.Core\.Ids' src/CodexWatcher/RunnerGuard.hs`
  Result: pass; no matches, so `RunnerGuard.hs` no longer imports the facade.
- Command: `rg -n 'CodexWatcher\.Core\.Ids' src app test *.cabal docs packages 2>/dev/null || true`
  Result: pass; remaining users are outside this round, including `moifold.cabal`, `src/CodexWatcher/Core/Ids.hs`, `src/CodexWatcher/EffectInterpreter.hs`, `src/CodexWatcher/Effects.hs`, `src/CodexWatcher/Healthcheck.hs`, event-log/runtime/state-machine/CLI/domain modules, tests, and docs. This is not completion or removal.
- Command: `cabal build all`
  Result: pass; Cabal reported `Up to date`.
- Command: `cabal test watcher-core-test`
  Result: pass; `Test suite watcher-core-test: PASS`; `1 of 1 test suites (1 of 1 test cases) passed`.
- Command: `git diff --check`
  Result: pass; no whitespace or patch hygiene errors.
- Command: `if git diff --cached --quiet; then echo 'SKIP: no staged changes'; else git diff --cached --check; fi`
  Result: skipped; no staged changes.

### Plan Compliance
- State lineage: met. `orchestrator/state.json` records roadmap `2026-05-11-00-highest-value-cleanup`, revision `rev-001`, milestone `milestone-003-import-convergence-package-boundaries`, direction `direction-011-core-ids-import-convergence`, extracted item `round-172-runner-guard-core-ids-split-import-migration`, stage `review`, `worker_mode: none`, and `merge_ready: false`.
- Import-only RunnerGuard migration: met. `src/CodexWatcher/RunnerGuard.hs` changed only the ID import section from the `CodexWatcher.Core.Ids` facade to direct owner imports for `RequestId`, `ThreadId`, `TurnId`, and `RepoName`.
- Behavior preservation boundaries: met. The diff shows no function body, JSON field, app-server sequencing, parser, replay, prompt, Cabal, docs, test, fixture, runtime compatibility file, roadmap file, public facade module, or public facade exposure changes.
- Remaining facade users: met. The repo scan still finds `CodexWatcher.Core.Ids` users across production modules, tests, docs, the Cabal exposed module, and the facade module itself; these are outside this round and remain for later reviewed work.
- Baseline verification: met. `cabal build all`, `cabal test watcher-core-test`, and `git diff --check` passed; cached diff check was correctly skipped because nothing is staged.

### Decision
**APPROVED**

### Evidence
The integrated round result matches the selected extraction and plan. The only implementation diff is:

```diff
-import CodexWatcher.Core.Ids (RepoName (..), RequestId (..), ThreadId (..), TurnId (..))
+import CodexWatcher.Workflow.Agent.Ids (RequestId (..), ThreadId (..), TurnId (..))
+import CodexWatcher.Workflow.GitHub.Ids (RepoName (..))
```

The focused `RunnerGuard.hs` facade-import scan returned no matches. The broader `CodexWatcher.Core.Ids` scan still reports remaining facade users in `src`, `test`, `docs`, and `moifold.cabal`, proving this round is not deprecation, completion, or removal. The required build, focused test suite, and diff hygiene checks all passed.
