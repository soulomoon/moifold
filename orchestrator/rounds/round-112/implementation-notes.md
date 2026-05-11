### Changes Made
- `test/RunnerGuardSpec.hs`: added endpoint-backed `startRunnerGuardRepairThread` coverage to the existing RunnerGuard aggregate. The new cases assert the repair launch sends `thread/start`, `thread/name/set`, and `turn/start` with request ids `1`, `2`, and `3`; carries the repair thread id, repair turn id, repair thread name, repair cwd, developer instructions, and repair prompt details; and preserves formatted failure text for launch, name-set, turn-start, and turn-start parse failures.
- `orchestrator/rounds/round-112/implementation-notes.md`: recorded the round implementation summary and validation evidence.

### Tests
- `test/RunnerGuardSpec.hs`: verifies successful repair launch sequencing and stable failure formatting through the real endpoint-backed app-server path while filtering only session setup traffic from request assertions.

### Notes
No production files, app-server client/transport/protocol modules, public API surfaces, Cabal metadata, roadmap files, controller state, or worker-plan artifacts were intentionally edited. The `thread/start` success fixture uses the current app-server result shape parsed by production code, `{"thread":{"id":"repair-thread"}}`.

Validation run:
- `printf 'RunnerGuardSpec.runnerGuardActiveTurnInspectionTests\n:quit\n' | cabal repl watcher-core-test` passed.
- `cabal test watcher-core-test` passed.
- `cabal build all` passed.
- `git diff --check` passed.
- `git diff --cached --check` passed.
- `test ! -e orchestrator/rounds/round-112/worker-plan.json` passed.
- Production RunnerGuard/AppServerClient/client/transport/protocol diff guard was empty.
