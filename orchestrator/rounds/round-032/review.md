### Checks Run
- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`.
- Command: `cabal test watcher-core-test`
  Result: pass. The `watcher-core-test` suite completed successfully: `1 of 1 test suites (1 of 1 test cases) passed`.
- Command: `git diff --check`
  Result: pass. No whitespace diagnostics.
- Command: `git diff --cached --check`
  Result: pass. No staged whitespace diagnostics.
- Command: `rg -n "CodexWatcher\\.(AppServerClient|ActionExecutor|ChildDaemon|Daemon|DaemonLoop|Domain\\.|Effects|EventLog|EventLogRepair|GhGit|Healthcheck|Runtime\\.|StateMachine|Workflow\\.GitHub|Workflow\\.Moifold\\.)|issue-state\\.json|daemon-state\\.json|planning-state\\.json|pr-url|block-state|repair-state|runtime-owner|\\bWatcherEvent\\b|\\bSomeWatcherState\\b" agent-workflow-codex/src`
  Result: pass. `rg` exited with no matches, confirming the direct source-token boundary scan.
- Command: `rg -n "^import .*CodexWatcher\\.(AppServerClient|ActionExecutor|ChildDaemon|Daemon|DaemonLoop|Domain|Effects|EventLog|EventLogRepair|GhGit|Healthcheck|Runtime|StateMachine|Workflow\\.GitHub|Workflow\\.Moifold|Workflow\\.Types)" agent-workflow-codex/src`
  Result: pass. `rg` exited with no matches, confirming no direct forbidden lifecycle imports in the Codex adapter package.

### Plan Compliance
- Step 1, inspect Codex adapter API modules: met. The round adds only the typed `agentTurnStartRef` helper in `CodexWatcher.Workflow.Agent.Types`; existing protocol/client/transport modules continue to own app-server request rendering, parsing, fallback, system-error detection, and transport sessions.
- Step 2, inspect main-library compatibility and integration callers: met. `src/CodexWatcher/AppServerClient.hs` remains a two-module reexport facade for `CodexWatcher.Workflow.Agent.Codex.Client` and `.Transport`; no moifold lifecycle policy moved into the adapter package.
- Step 3, keep the Codex sublibrary dependency surface narrow: met. `library agent-workflow-codex` exposes the adapter/protocol modules and depends only on `aeson`, `base`, `bytestring`, `text`, `websockets`, and `moifold:agent-workflow-core`.
- Step 4, add focused adapter tests for touched surfaces: met. `test/AppServerSpec.hs` now rejects malformed thread-start and turn-start payloads, while `test/Main.hs` covers typed `TurnRef` derivation and typed thread-read request rendering.
- Step 5, preserve classifier evidence and structured-output requirements: met. The diff does not weaken classifier code or tests; `watcher-core-test` reran the PR-review classifier and observation assertions registered in `test/Main.hs`.
- Step 6, harden recursive Codex package-boundary scans: met. `workflowCodexCabalSublibraryKeepsPackageBoundary` now checks recursive imports, lifecycle ownership text, concrete watcher event/state tokens, and unapproved dependencies.
- Step 7, preserve compatibility facade thinness: met. `src/CodexWatcher/AppServerClient.hs` remains only reexports plus imports of the Codex client and transport modules.
- Step 8, record implementation notes: met. `orchestrator/rounds/round-032/implementation-notes.md` records the production helper, parser/classifier/boundary test coverage, and validation status.

### Decision
**APPROVED**

### Evidence
The integrated diff is scoped to `agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Types.hs`, `test/AppServerSpec.hs`, `test/Main.hs`, and controller state/artifacts. The production API change is additive: `agentTurnStartRef` derives a typed `TurnRef` from an `AgentTurnStart`.

The app-server protocol/client parsing requirements are covered by valid nested start parsing plus malformed thread-start and turn-start rejection. The typed `TurnRef` and agent role helper behavior is covered by the Codex lifecycle test, including `agentTurnStartRef`, typed thread-read request rendering, interrupt rendering, cached start behavior, thread-read parsing, missing-turn handling, and malformed turn-start rejection.

Classifier and observation evidence remains intact: the round did not weaken structured-output requirements, and the full `watcher-core-test` suite passed with the existing PR-review classifier and observation law assertions. Compatibility facade thinness is preserved by direct inspection of `src/CodexWatcher/AppServerClient.hs`.

Recursive boundary evidence is both encoded in `workflowCodexCabalSublibraryKeepsPackageBoundary` and checked directly with `rg`: no moifold issue/PR lifecycle imports, GitHub policy modules, daemon/runtime ownership text, compatibility-file tokens, `WatcherEvent`, or `SomeWatcherState` appear under `agent-workflow-codex/src`.
