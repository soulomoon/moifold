### Changes Made
- moifold.cabal: removed the root internal `library agent-workflow-core`, `library agent-workflow-codex`, and `library agent-workflow-github` component stanzas; switched the main `library` and `watcher-core-test` dependencies to standalone `agent-workflow-* >=0.1 && <0.2` package dependencies.
- test/Main.hs: updated package-boundary assertions so they verify standalone package descriptors and root moifold consumer wiring instead of parsing the removed internal sublibraries.
- orchestrator/rounds/round-042/implementation-notes.md: recorded implementation scope and validation evidence for round-042.

### Tests
- test/Main.hs: verifies `moifold.cabal` has no internal workflow sublibrary stanzas or `moifold:agent-workflow-*` dependencies, and that both the main library and `watcher-core-test` consume the standalone workflow packages with the approved bounds.
- test/Main.hs: keeps existing source ownership scans and standalone descriptor checks for `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`.

### Notes
Validation run from the round worktree:

- `cabal build agent-workflow-core:lib:agent-workflow-core`: passed.
- `cabal build agent-workflow-codex:lib:agent-workflow-codex`: passed.
- `cabal build agent-workflow-github:lib:agent-workflow-github`: passed.
- `cabal build moifold:lib:moifold`: passed.
- `cabal build moifold:exe:moifold`: passed.
- `cabal build all`: passed.
- `cabal test watcher-core-test`: passed.
- `rg -n "moifold:agent-workflow-(core|codex|github)|^library agent-workflow-(core|codex|github)" moifold.cabal cabal.project agent-workflow-core/agent-workflow-core.cabal agent-workflow-codex/agent-workflow-codex.cabal agent-workflow-github/agent-workflow-github.cabal`: no matches, expected exit 1.
- `rg -n "agent-workflow-(core|codex|github) >=0.1 && <0.2" moifold.cabal agent-workflow-codex/agent-workflow-codex.cabal`: showed standalone bounds in `moifold.cabal` and the existing Codex-to-core bound in `agent-workflow-codex.cabal`.
- `rg -n "CodexWatcher\\.(AppServerClient|ActionExecutor|ChildDaemon|Daemon|DaemonLoop|Domain\\.|EventLogRepair|Healthcheck|Runtime\\.|StateMachine|Workflow\\.Moifold\\.)" agent-workflow-core/src agent-workflow-codex/src agent-workflow-github/src`: no matches, expected exit 1.
- `git diff --check`: passed.
- `git diff --cached --check`: not applicable; no files were staged.

`cabal.project` was not changed because the existing local package entries were sufficient. No source modules, compatibility facades, event schemas, runtime ownership behavior, healthcheck/repair behavior, roadmap files, or controller state were edited for this round.
