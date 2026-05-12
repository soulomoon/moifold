### Checks Run
- Command: `sed -n '1,220p' orchestrator/roles/reviewer.md`
  Result: pass; loaded reviewer duties, boundaries, and required review artifact format.
- Command: `sed -n '1,260p' orchestrator/state.json`
  Result: pass; active round is `round-143`, stage is `review`, roadmap is `2026-05-11-00-highest-value-cleanup` `rev-001`, verification resolves to `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`.
- Command: `sed -n '1,240p' orchestrator/rounds/round-143/selection.md`
  Result: pass; selected scope is only the `test/AutomaticLoopRunnerSpec.hs` direct-owner import migration for `AppServerClientFailure (..)` and `AppServerEndpoint`.
- Command: `sed -n '1,260p' orchestrator/rounds/round-143/plan.md`
  Result: pass; plan requires one import-only test-file change, focused scans, broad facade scan, `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and `git diff --cached --check`.
- Command: `sed -n '1,260p' orchestrator/rounds/round-143/implementation-notes.md`
  Result: pass; implementation notes report the intended import-only change and no deprecation/removal approval.
- Command: `test -f orchestrator/project-contract.md && sed -n '1,260p' orchestrator/project-contract.md || true`
  Result: pass; project contract confirms compatibility facades remain available until exact reviewed removal gates and import convergence is evidence-producing cleanup only.
- Command: `sed -n '1,260p' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`
  Result: pass; baseline and task-specific verification requirements loaded.
- Command: `rg -n "CodexWatcher\\.AppServerClient|Workflow\\.Agent\\.Codex\\.(Client|Transport)|AppServerClientFailure|AppServerEndpoint" test/AutomaticLoopRunnerSpec.hs`
  Result: pass; selected file has direct imports from `CodexWatcher.Workflow.Agent.Codex.Client` and `CodexWatcher.Workflow.Agent.Codex.Transport`, and no `CodexWatcher.AppServerClient` import.
- Command: `rg -n "CodexWatcher\\.AppServerClient" src app test docs *.cabal agent-workflow-* || true`
  Result: pass; remaining facade users are out of scope and do not include `test/AutomaticLoopRunnerSpec.hs`.
- Command: `git diff -- test/AutomaticLoopRunnerSpec.hs`
  Result: pass; diff is only the planned import swap.
- Command: `git diff --name-only`
  Result: pass; tracked diff is `orchestrator/state.json` and `test/AutomaticLoopRunnerSpec.hs`.
- Command: `git diff --cached --name-only`
  Result: pass; no staged files.
- Command: `find orchestrator/rounds/round-143 -maxdepth 1 -type f -print | sort`
  Result: pass; round artifacts before review were `implementation-notes.md`, `plan.md`, and `selection.md`; no worker plan was written.
- Command: `git diff -- orchestrator/state.json`
  Result: pass; state records round-143 dispatch/review metadata and does not mark merge-ready or terminal completion.
- Command: `git diff --check`
  Result: pass; no whitespace errors.
- Command: `git diff --cached --check`
  Result: pass; no staged whitespace errors.
- Command: `cabal test watcher-core-test`
  Result: pass; watcher-core-test passed, including automatic-loop execute, dry-run, app-server transport retry, replay/decode fatal, event replay fatal, and unexpected-start fatal assertions.
- Command: `cabal build all`
  Result: pass; build reported `Up to date`.
- Command: `rg -n "^\\s*CodexWatcher\\.AppServerClient$|module CodexWatcher\\.AppServerClient" moifold.cabal src/CodexWatcher/AppServerClient.hs`
  Result: pass; `CodexWatcher.AppServerClient` remains exposed in `moifold.cabal` and present in `src/CodexWatcher/AppServerClient.hs`.
- Command: `git diff --stat`
  Result: pass; tracked implementation/state diff is limited to `orchestrator/state.json` and `test/AutomaticLoopRunnerSpec.hs`.
- Command: `git status --short`
  Result: pass; worktree contains modified `orchestrator/state.json`, modified `test/AutomaticLoopRunnerSpec.hs`, and untracked `orchestrator/rounds/round-143/` artifacts.
- Command: `test ! -e orchestrator/rounds/round-143/worker-plan.json && echo absent || echo present`
  Result: pass; `worker-plan.json` is absent as required by the plan.

### Plan Compliance
- Step 1, edit only `test/AutomaticLoopRunnerSpec.hs`: met for implementation code; the only tracked source/test diff is the selected test file, with expected orchestrator state and round artifacts.
- Step 2, replace the facade import with direct-owner imports: met; selected-file scan and diff show `AppServerClientFailure (..)` imported from `CodexWatcher.Workflow.Agent.Codex.Client` and `AppServerEndpoint` from `CodexWatcher.Workflow.Agent.Codex.Transport`.
- Step 3, leave test bodies, helpers, fixtures, assertions, and exports unchanged: met; the selected-file diff changes imports only.
- Step 4, confirm the target file no longer imports `CodexWatcher.AppServerClient`: met; selected-file scan has no facade import.
- Step 5, confirm no out-of-scope files changed: met; no production files, `test/Main.hs`, test support, package descriptors, docs, facade module, or direct-owner modules are changed.
- Step 6, record import-convergence-only notes and no deprecation/removal approval: met; implementation notes state this is not public facade deprecation/removal, Cabal exposure cleanup, package descriptor cleanup, milestone completion, release approval, or terminal completion.
- Verification, focused scans and diff/scope review: met; selected scan, broad scan, `git diff -- test/AutomaticLoopRunnerSpec.hs`, and `git diff --name-only` all support the planned scope.
- Verification, behavior and baseline checks: met; `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and `git diff --cached --check` all passed.
- Project contract and verification alignment: met; `CodexWatcher.AppServerClient` remains present/exposed, remaining facade users are recorded as out of scope, and this round does not claim deprecation, Cabal exposure cleanup, facade removal, milestone completion, release approval, or terminal roadmap completion.

### Decision
**APPROVED**

### Evidence
The integrated round result preserves automatic-loop runner behavior while moving only `test/AutomaticLoopRunnerSpec.hs` off the `CodexWatcher.AppServerClient` compatibility facade. The selected-file scan shows the direct-owner imports:

```haskell
import CodexWatcher.Workflow.Agent.Codex.Client (AppServerClientFailure (..))
import CodexWatcher.Workflow.Agent.Codex.Transport (AppServerEndpoint)
```

The broad `CodexWatcher.AppServerClient` scan still reports expected out-of-scope users in `moifold.cabal`, `src/CodexWatcher/AppServerClient.hs`, other tests, and docs, but not in `test/AutomaticLoopRunnerSpec.hs`. The facade remains exposed and present, so this import-convergence slice does not alter public compatibility surfaces.

`cabal test watcher-core-test` passed and included the relevant automatic-loop assertions for endpoint-backed execution, dry-run traffic avoidance, transient transport retry, and fatal decode/replay/invalid-start behavior. `cabal build all`, `git diff --check`, and `git diff --cached --check` also passed.
