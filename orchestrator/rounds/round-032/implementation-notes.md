### Changes Made
- `agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Types.hs`: added `agentTurnStartRef`, an additive typed adapter helper for deriving a `TurnRef` from an `AgentTurnStart`.
- `test/AppServerSpec.hs`: added malformed thread-start and turn-start response checks for app-server client parsing.
- `test/Main.hs`: registered the new app-server parser checks, extended the Codex adapter lifecycle test to cover `agentTurnStartRef` and typed thread-read request rendering, and hardened the recursive `workflowCodexCabalSublibraryKeepsPackageBoundary` scan against moifold lifecycle imports, lifecycle ownership text, concrete `WatcherEvent` / `SomeWatcherState` tokens, and unapproved adapter dependencies.

### Tests
- `test/AppServerSpec.hs`: verifies valid nested start response parsing still works and malformed thread/turn start responses fail as decode failures.
- `test/Main.hs`: verifies typed Codex thread/turn request parity, `TurnRef` derivation, read/interrupt request rendering, retry/side-effect metadata, PR-review classifier mapping, observation planning, compatibility facade thinness, and recursive package-boundary ownership checks.

### Validation
- `cabal test watcher-core-test`: PASS.
- `cabal build all`: PASS.
- `git diff --check`: PASS.
- `git diff --no-index --check /dev/null orchestrator/rounds/round-032/implementation-notes.md`: PASS; no whitespace diagnostics for the new untracked notes file.
- `git diff --cached --check`: not run; no files were staged during this round.

### Notes
Production API code changed only by the additive `agentTurnStartRef` helper in `agent-workflow-codex`. The rest of the stabilization was test and recursive source-scan hardening. Reviewed the Codex adapter modules, `moifold.cabal`, the `src/CodexWatcher/AppServerClient.hs` compatibility facade, and the main integration callers named in the plan; no moifold issue/PR lifecycle policy was moved into `agent-workflow-codex`.
