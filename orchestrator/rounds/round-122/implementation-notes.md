### Changes Made
- `src/CodexWatcher/AutomaticLoop/Runner.hs`: replaced the public `CodexWatcher.AppServerClient` facade import with the direct owner import from `CodexWatcher.Workflow.Agent.Codex.Transport` for exactly `AppServerEndpoint`, `appServerInterpreterFromEndpoint`, and `defaultAppServerClientOptions`.
- `orchestrator/rounds/round-122/implementation-notes.md`: recorded round-122 implementation and validation evidence.

### Tests
- `test/AutomaticLoopRunnerSpec.hs`: `printf ':set -Wno-type-defaults\nAutomaticLoopRunnerSpec.automaticLoopRunnerTests\n:quit\n' | cabal repl watcher-core-test` passed. The focused gate covered execute-mode endpoint traffic, dry-run no-traffic behavior, and retry/fatal classification.
- `watcher-core-test`: `cabal test watcher-core-test` passed.
- Package baseline: `cabal build all` passed.
- Whitespace guards: `git diff --check` and `git diff --cached --check` passed.
- Import scans: the facade import scan found no `CodexWatcher.AppServerClient` import in `src/CodexWatcher/AutomaticLoop/Runner.hs`; the direct owner import scan found `CodexWatcher.Workflow.Agent.Codex.Transport`; the symbol scan found only the three planned imported symbols and their existing use sites.
- Path guards: the forbidden-path guard passed, and `test ! -e orchestrator/rounds/round-122/worker-plan.json` passed.

### Notes
This round was import-only. No code bodies, signatures, tests, package metadata, docs, fixtures, protocol/client owner modules, direct owner modules, runtime compatibility files, public API/facade exposure, PR-review launch, issue fanout, roadmap files, roadmap-update artifacts, or worker fan-out artifacts were changed.

The planner's suspected direct owner path was verified before editing: the actual owner module is `agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs`, and it already exports all three required symbols. That owner module was not edited.

The changed-path guard showed a pre-existing tracked control-plane change in `orchestrator/state.json` plus this round's `src/CodexWatcher/AutomaticLoop/Runner.hs` edit. The untracked-path guard showed the round artifact files `orchestrator/rounds/round-122/plan.md` and `orchestrator/rounds/round-122/selection.md` before implementation notes were written. I did not modify or revert those pre-existing control-plane artifacts.
