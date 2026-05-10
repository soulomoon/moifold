### Changes Made
- `golden/runtime-compatibility/daemon-state/planning-active/daemon-state.json`: added the current active issue-planning daemon compatibility shape with deterministic fixture turn and thread ids.
- `golden/runtime-compatibility/daemon-state/stopped/daemon-state.json`: added the current stopped daemon compatibility shape with null active fields and a deterministic stop reason.
- `test/RuntimeCompatibilityFixtureSpec.hs`: added daemon-state fixture assertions for exact JSON shape, snapshot-reader tolerance, active/stopped non-interchangeability, `compatibilityStateWrites` output for representative active and stopped states, and source-boundary checks for current healthcheck, snapshot, repair, and restart interactions.

### Tests
- `test/RuntimeCompatibilityFixtureSpec.hs`: verifies the new active and stopped daemon fixtures decode as JSON, decode through `NodeIssueDaemonState`, match current producer shapes, remain distinct, and are emitted by representative compatibility state writes.
- `test/RuntimeCompatibilityFixtureSpec.hs`: verifies source-boundary strings still preserve daemon-state healthcheck shared-state coverage, optional snapshot reads, repair compatibility rewrite, and restart cleanup.
- `find golden/runtime-compatibility/daemon-state -type f | sort`: passed.
- `python3 -m json.tool golden/runtime-compatibility/daemon-state/planning-active/daemon-state.json`: passed.
- `python3 -m json.tool golden/runtime-compatibility/daemon-state/stopped/daemon-state.json`: passed.
- `rg -n "daemon-state\\.json|RuntimeCompatibilityFixtureSpec|runtimeCompatibilityFixtureTests|activeDaemonJson|stoppedDaemonJson|NodeIssueDaemonState|writeCompatibilityFiles|cleanup_state" golden test src scripts -g '!dist-newstyle/**'`: passed.
- `cabal test watcher-core-test`: passed.
- `cabal build all`: passed.
- `git diff --check`: passed.

### Notes
No production code, healthcheck behavior, snapshot behavior, repair behavior, restart behavior, Cabal exposure, roadmap files, or controller state were edited. Existing pre-round control-plane changes to `orchestrator/state.json`, `orchestrator/rounds/round-091/plan.md`, and `orchestrator/rounds/round-091/selection.md` were left intact.
