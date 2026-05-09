### Changes Made
- `orchestrator/rounds/round-061/app-server-client-migration-readiness.md`: added evidence-only migration-readiness report for `CodexWatcher.AppServerClient`, including refreshed selected-facade import counts, broader reference classification, caller ownership grouping, replacement module exposure readback, behavior coverage readback, and blockers for later cleanup.
- `orchestrator/rounds/round-061/implementation-notes.md`: recorded this implementation summary and verification.

### Tests
- No production source, tests, Cabal descriptors, roadmap files, project contract, or state files were edited.
- Ran the plan's selected-facade import scan:
  `rg -n '^ *import +(qualified +)?CodexWatcher\.AppServerClient(\b| +as +| *$| *\()' src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github README.md docs *.cabal */*.cabal`
  Result: 28 selected-facade import files/import statements.
- Ran the plan's selected-facade count scan:
  `rg -l '^ *import +(qualified +)?CodexWatcher\.AppServerClient(\b| +as +| *$| *\()' src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github README.md docs *.cabal */*.cabal | wc -l`
  Result: `28`.
- Ran the plan's broader reference scan:
  `rg -n 'CodexWatcher\.AppServerClient|CodexWatcher\.Workflow\.Agent\.Codex\.(Client|Transport|Protocol)' README.md docs examples *.cabal */*.cabal agent-workflow-core agent-workflow-codex agent-workflow-github src test app`
  Result: observed current facade imports, package exposure, docs/policy references, replacement-module imports, and non-user test assertions; no selected-facade imports in standalone workflow package candidates or examples.
- Ran the plan's package exposure scan:
  `rg -n 'CodexWatcher\.AppServerClient|CodexWatcher\.Workflow\.Agent\.Codex\.(Client|Transport|Protocol)' moifold.cabal agent-workflow-codex/agent-workflow-codex.cabal`
  Result: `moifold.cabal` exposes `CodexWatcher.AppServerClient`; `agent-workflow-codex.cabal` exposes `CodexWatcher.Workflow.Agent.Codex.Client`, `CodexWatcher.Workflow.Agent.Codex.Protocol`, and `CodexWatcher.Workflow.Agent.Codex.Transport`.
- Ran `git diff --check`.
  Result: passed.
- Ran `git diff --name-only`.
  Result: no tracked-file diff output, because the round artifacts are
  currently untracked.
- Ran `git status --short`.
  Result: `?? orchestrator/rounds/round-061/`.
- Ran `git ls-files --others --exclude-standard orchestrator/rounds/round-061`.
  Result: `app-server-client-migration-readiness.md`,
  `implementation-notes.md`, and the pre-existing round inputs
  `plan.md` and `selection.md` are untracked in this worktree.
- Ran no-index whitespace checks for the two new untracked output artifacts:
  `git diff --no-index --check /dev/null orchestrator/rounds/round-061/app-server-client-migration-readiness.md`
  and
  `git diff --no-index --check /dev/null orchestrator/rounds/round-061/implementation-notes.md`.
  Result: passed.
- Cabal/package baselines were not run because the diff is limited to round-local orchestrator artifacts.

### Notes
Downstream/operator sources outside this checkout were unavailable, so the evidence records that gap as unavailable rather than as removal approval. The report does not approve migration, deprecation, facade narrowing, Cabal exposure changes, or removal.
