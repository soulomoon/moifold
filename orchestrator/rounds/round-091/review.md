### Checks Run
- Command: `python3 -m json.tool orchestrator/state.json`
  Result: pass. State JSON is valid and records active `round-091` in `review` for roadmap `2026-05-11-00-highest-value-cleanup`, revision `rev-001`, direction `direction-007-runtime-compatibility-fixtures`, extraction `round-091-daemon-state-compatibility-fixtures`.
- Command: `git status --short --untracked-files=all`
  Result: pass. Changed implementation paths are `test/RuntimeCompatibilityFixtureSpec.hs` and the two expected `golden/runtime-compatibility/daemon-state/.../daemon-state.json` fixture files. The status also contains controller/round artifacts for active round coordination and this review.
- Command: `find golden/runtime-compatibility/daemon-state -type f | sort`
  Result: pass. Exactly the expected selected daemon fixture files are present: `planning-active/daemon-state.json` and `stopped/daemon-state.json`.
- Command: `python3 -m json.tool golden/runtime-compatibility/daemon-state/planning-active/daemon-state.json`
  Result: pass. Fixture is valid JSON and has the expected active daemon shape with `activeTurnId`, `activeTurnPurpose`, and `activeThreadId`.
- Command: `python3 -m json.tool golden/runtime-compatibility/daemon-state/stopped/daemon-state.json`
  Result: pass. Fixture is valid JSON and has the expected stopped daemon shape with null active fields and `stopReason`.
- Command: `rg -n "daemon-state\\.json|RuntimeCompatibilityFixtureSpec|runtimeCompatibilityFixtureTests|activeDaemonJson|stoppedDaemonJson|NodeIssueDaemonState|writeCompatibilityFiles|cleanup_state" golden test src scripts -g '!dist-newstyle/**'`
  Result: pass. The scan shows the two fixture paths, new watcher-core daemon fixture assertions, current active/stopped daemon producers, snapshot reader type, repair rewrite path, and restart cleanup path.
- Command: `sed -n '56,118p' src/CodexWatcher/Runtime/Compatibility.hs`
  Result: pass. Current compatibility projection still writes `daemon-state.json` for planning active states using `activeDaemonJson "plan"` and keeps existing idle daemon writes for other states.
- Command: `sed -n '150,170p' src/CodexWatcher/Runtime/Compatibility.hs`
  Result: pass. `StoppedState` still writes `daemon-state.json` through `stoppedDaemonJson`.
- Command: `sed -n '252,270p' src/CodexWatcher/Runtime/Compatibility.hs`
  Result: pass. `activeDaemonJson` and `stoppedDaemonJson` still define the exact active and stopped shapes used by the fixtures.
- Command: `sed -n '170,185p' src/CodexWatcher/Snapshot.hs`
  Result: pass. `NodeIssueDaemonState` still reads active turn id, purpose, and collaboration mode while ignoring unknown daemon-state fields such as `stopReason`.
- Command: `sed -n '236,245p' src/CodexWatcher/Snapshot.hs`
  Result: pass. Issue-implementation snapshot loading still reads optional `daemon-state.json`.
- Command: `sed -n '246,282p' src/CodexWatcher/Healthcheck.hs`
  Result: pass. Issue planning and issue implementation healthcheck state specs still share `("daemonState", "daemon-state.json")`.
- Command: `sed -n '48,104p' src/CodexWatcher/Cli/Command/Replay.hs`
  Result: pass. Repair replay execution still rewrites compatibility files with `writeCompatibilityFiles`.
- Command: `sed -n '216,226p' scripts/restart-watcher`
  Result: pass. Restart cleanup still removes `"$state_dir/daemon-state.json"`.
- Command: `git diff --check`
  Result: pass. No whitespace errors.
- Command: `git diff --cached --check`
  Result: pass. No staged diff was present.
- Command: `cabal test watcher-core-test`
  Result: pass. The suite passed, including the new runtime compatibility daemon fixture assertions for JSON decoding, snapshot-reader tolerance, active/stopped exact shapes, non-interchangeability, compatibility projection writes, and daemon-state source-boundary checks.
- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`.

### Plan Compliance
- Step 1, reconfirm current scope and inputs: met. Reviewed state, selection, plan, project contract, active roadmap verification, and current worktree status.
- Step 2, reconfirm daemon producer and reader paths: met. Source inspection confirms current producer names, stopped-state write behavior, snapshot reader tolerance, healthcheck shared-state mapping, repair rewrite path, and restart cleanup path.
- Step 3, add the two daemon fixture files: met. The files are checked in under `golden/runtime-compatibility/daemon-state/planning-active/daemon-state.json` and `golden/runtime-compatibility/daemon-state/stopped/daemon-state.json`.
- Step 4, extend `runtimeCompatibilityFixtureTests` with daemon-state coverage: met. `test/RuntimeCompatibilityFixtureSpec.hs` adds daemon fixture shape, compatibility projection, and source-boundary checks without removing existing planner/planning checks.
- Step 5, load both fixtures as `Value` and assert exact equality: met. The new tests decode both fixtures and compare them to exact expected active and stopped daemon JSON values.
- Step 6, decode both fixtures as `NodeIssueDaemonState`: met. The active fixture decodes with `Just "daemon-turn"` and `Just "plan"`; the stopped fixture decodes successfully with no active turn id or purpose, without requiring `stopReason` consumption.
- Step 7, assert representative `compatibilityStateWrites` daemon outputs: met. The new tests verify `PlanningTurnActive` writes the active daemon fixture, typed `StoppedState` writes the stopped daemon fixture, and the two writes are not interchangeable.
- Step 8, lock current daemon-state compatibility interactions: met. The new source-boundary test checks healthcheck shared state coverage, snapshot optional read, repair compatibility rewrite, and restart cleanup preservation.
- Step 9, inspect final diff and keep scope narrow: met. Implementation changes are limited to the selected daemon fixtures and `test/RuntimeCompatibilityFixtureSpec.hs`; no production behavior, healthcheck behavior, snapshot behavior, repair behavior, restart behavior, Cabal exposure, roadmap file, docs/policy file, compatibility filename, rename, deletion, migration, deprecation, removal, or unrelated fixture surface was changed. `orchestrator/state.json` reflects active round coordination rather than implementation behavior.

### Decision
**APPROVED**

### Evidence
The integrated round adds the selected active and stopped `daemon-state.json` fixtures and turns the daemon compatibility contract into watcher-core assertions. The fixtures match the current producer shapes from `activeDaemonJson` and `stoppedDaemonJson`, and the tests prove snapshot reader tolerance without changing `Snapshot.hs`.

The tests would fail if active and stopped daemon shapes were collapsed, swapped, renamed, or treated as equivalent: exact JSON equality is asserted for both fixtures, `activeThreadId` and `stopReason` are checked as shape discriminators, and representative `PlanningTurnActive` and `StoppedState` compatibility writes must produce distinct values at `daemon-state.json`.

The project-contract and roadmap boundaries remain intact. This approval is fixture/test evidence for the selected `daemon-state.json` active and stopped compatibility slice only; it does not approve deprecation, migration, rename, deletion, healthcheck reader behavior change, repair behavior change, restart behavior change, broader fixture batches, facade removal, Cabal exposure removal, release approval, or terminal roadmap completion.
