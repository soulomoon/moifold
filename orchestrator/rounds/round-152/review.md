### Checks Run
- Command: `cabal build all`
  Result: pass; Cabal reported `Up to date`.
- Command: `cabal test watcher-core-test`
  Result: pass; `watcher-core-test` built and ran successfully, including the app-server probe initialize, existing-thread smoke, smoke-turn, and failure-formatting coverage. Final summary: `Test suite watcher-core-test: PASS`; `1 of 1 test suites (1 of 1 test cases) passed.`
- Command: `git diff --check`
  Result: pass; no whitespace or diff hygiene errors.
- Command: `git diff --cached --check`
  Result: pass; no staged diff hygiene errors. This was run even though `git diff --cached --quiet` showed no staged changes.
- Command: `rg -n 'CodexWatcher\.Core\.Ids' test/AppServerProbeSpec.hs`
  Result: pass; no matches, so `test/AppServerProbeSpec.hs` no longer imports `CodexWatcher.Core.Ids`.
- Command: `rg -nF 'import CodexWatcher.Workflow.Agent.Ids (ThreadId (..), unThreadId)' test/AppServerProbeSpec.hs`
  Result: pass; line 12 imports `CodexWatcher.Workflow.Agent.Ids (ThreadId (..), unThreadId)`.
- Command: `git diff --unified=0 -- test/AppServerProbeSpec.hs`
  Result: pass; the selected test file has exactly one code delta, replacing the `CodexWatcher.Core.Ids` import with the direct `CodexWatcher.Workflow.Agent.Ids` import.
- Command: `git status --porcelain=v1 && git diff --name-status && git diff --cached --name-status && git ls-files --others --exclude-standard`
  Result: pass; changed paths are `orchestrator/state.json`, `test/AppServerProbeSpec.hs`, and untracked round artifacts under `orchestrator/rounds/round-152/`. There are no staged paths.
- Command: `rg -n "CodexWatcher\.Core\.Ids" moifold.cabal src/CodexWatcher/Core/Ids.hs`
  Result: pass; `src/CodexWatcher/Core/Ids.hs` still defines `CodexWatcher.Core.Ids`, and `moifold.cabal` still exposes it.
- Command: `rg -n "CodexWatcher\.Core\.Ids" src app test docs *.cabal agent-workflow-* 2>/dev/null`
  Result: pass; remaining `CodexWatcher.Core.Ids` users exist outside the selected file, including production and test call sites, so this round did not imply deprecation or removal approval.
- Command: `rg -n "CodexWatcher\.AppServerClient|CodexWatcher\.Core\.Ids|CodexWatcher\.Workflow\.EventLog|CodexWatcher\.Workflow\.Permission" moifold.cabal agent-workflow-*/*.cabal`
  Result: pass; the public compatibility modules remain exposed in `moifold.cabal`, with direct core package modules exposed in their package descriptors.

### Plan Compliance
- Replace only the `test/AppServerProbeSpec.hs` `CodexWatcher.Core.Ids` import with the direct `CodexWatcher.Workflow.Agent.Ids (ThreadId (..), unThreadId)` import: met; focused import scan and zero-context diff confirm the one-line import-owner change.
- Leave the `CodexWatcher.Workflow.Agent.Codex.Transport` `AppServerEndpoint` import unchanged: met; the focused diff contains no change to that import.
- Do not change test bodies, helper functions, expected request methods, request ids, rendered thread ids, success output checks, or failure checks: met; `git diff --unified=0 -- test/AppServerProbeSpec.hs` shows only the import replacement, and `watcher-core-test` passed the existing app-server probe coverage.
- Do not edit other implementation files, package descriptors, docs, compatibility facades, or public removal/deprecation surfaces: met; changed-path evidence is limited to controller state, round artifacts, and the selected test file.
- Record that `CodexWatcher.Core.Ids` remains available and that this is preferred-import convergence only: met; `implementation-notes.md` records that boundary, and scans confirm `CodexWatcher.Core.Ids` remains defined and exposed.
- Preserve roadmap lineage `2026-05-11-00-highest-value-cleanup` / `rev-001`: met; `selection.md` and `orchestrator/state.json` both record the active roadmap id, revision, directory, milestone, direction, and extracted item for round 152.

### Decision
**APPROVED**

### Evidence
The integrated round result matches the selected one-file import convergence slice. `test/AppServerProbeSpec.hs` no longer imports `CodexWatcher.Core.Ids`; it now imports `CodexWatcher.Workflow.Agent.Ids (ThreadId (..), unThreadId)`. The test file diff contains no assertion, helper, command-rendering, request-id, success-output, or failure-path changes.

The public compatibility boundary remains intact: `CodexWatcher.Core.Ids` is still defined in `src/CodexWatcher/Core/Ids.hs`, still exposed by `moifold.cabal`, and still used by other in-scope production and test files. `CodexWatcher.AppServerClient`, `CodexWatcher.Workflow.EventLog`, and `CodexWatcher.Workflow.Permission` also remain exposed. No docs, package descriptors, compatibility facades, runtime compatibility files, or public removal/deprecation surfaces changed.

Baseline verification passed: `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, and `git diff --cached --check`.
