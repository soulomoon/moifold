### Checks Run
- Command: `git status --short --branch`
  Result: pass. Branch is `orchestrator/round-070-live-issue-snapshot-fixture-timing`; only `?? orchestrator/rounds/round-070/` is reported.
- Command: `git diff --name-only`
  Result: pass. No tracked diff is reported. Because the round files are untracked, this was paired with `git ls-files --others --exclude-standard`.
- Command: `git ls-files --others --exclude-standard`
  Result: pass. Untracked paths are limited to `orchestrator/rounds/round-070/implementation-notes.md`, `orchestrator/rounds/round-070/live-issue-snapshot-fixture-timing.md`, `orchestrator/rounds/round-070/plan.md`, and `orchestrator/rounds/round-070/selection.md` before reviewer artifacts.
- Command: `find orchestrator/rounds/round-070 -maxdepth 1 -type f | sort`
  Result: pass. Round-local files before reviewer artifacts are `implementation-notes.md`, `live-issue-snapshot-fixture-timing.md`, `plan.md`, and `selection.md`.
- Command: `git diff --check`
  Result: pass. No whitespace errors.
- Command: `git diff --cached --check`
  Result: pass. No staged diff; no whitespace errors.
- Command: `rg -n "[ \t]+$" orchestrator/rounds/round-070`
  Result: pass. No trailing whitespace matches; `rg` exited 1 because there were no matches.
- Command: `sed -n '1,220p' orchestrator/rounds/round-070/selection.md`
  Result: pass. Selection is `direction-019-live-issue-snapshot-fixture-timing` under milestone `milestone-006-runtime-compatibility-follow-up-evidence`, roadmap `2026-05-09-01-compatibility-surface-cleanup` `rev-002`, and out of scope excludes filename/schema/event/planner/projection/healthcheck/repair/runtime cleanup changes.
- Command: `sed -n '1,260p' orchestrator/project-contract.md`
  Result: pass. Contract preserves event schema, golden/fixture, prompt schema, write timing, compatibility facade, healthcheck, repair, and cleanup sequencing invariants unless explicitly migrated.
- Command: `sed -n '1,340p' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/verification.md`
  Result: pass. Baselines and artifact-only allowance were read. Cabal and package baselines were skipped because the integrated diff is limited to round-local orchestrator evidence artifacts and does not touch production source, tests, fixtures, scripts, docs outside the round, roadmap files, package files, or controller state.
- Command: `test -r orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/roadmap.md && test -r orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/verification.md && test -r orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/retry-subloop.md && test -r orchestrator/rounds/round-059/plan.md && test ! -e orchestrator/rounds/round-059/worker-plan.json`
  Result: pass. Rev-002 artifacts and round-059 plan are present; no round-059 worker-plan is present.
- Command: `rg -n "2026-05-09-01-compatibility-surface-cleanup|rev-002|strategy-backlog|roadmap_revision|milestone-00[1-7]|removal|reviewer approval" orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/roadmap.md orchestrator/state.json`
  Result: pass. Roadmap id/revision/style and activation metadata match `rev-002`; milestones 005-007 remain evidence/inventory gates before milestone-008 removals; removals require explicit reviewer approval.
- Command: `rg -n "direction-019|milestone-006|issue-snapshot" orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/roadmap.md`
  Result: pass. Direction 019 is the live `issue-snapshot.json` fixture/write-timing evidence item in milestone 006.
- Command: `sed -n '45,255p' src/CodexWatcher/Domain/IssuePlanning/Loop.hs`
  Result: pass. `runPlanningReady` writes the execute-mode snapshot through `ensureIssuePlanningSnapshot` before `startPlannerTurn`; closed scoped snapshots can complete through `ObservedPlanningScopeCompleted`.
- Command: `sed -n '255,430p' src/CodexWatcher/Domain/IssuePlanning/Loop.hs`
  Result: pass. `buildIssuePlanningSnapshot` emits `repoFullName`, `scopeIssueNumbers`, `issues`, and the unscoped `note`; scoped snapshots fetch issue and sub-issue JSON and normalize non-array sub-issues to an empty array.
- Command: `sed -n '280,345p' src/CodexWatcher/PromptTemplates.hs`
  Result: pass. The issue-planning thread developer prompt says to read the issue snapshot from `{{issueSnapshotPath}}`.
- Command: `sed -n '320,345p' src/CodexWatcher/TurnOutput.hs`
  Result: pass. `issueSnapshotPath` renders as `stateDir </> "issue-snapshot.json"`.
- Command: `sed -n '4790,4870p' test/Main.hs`
  Result: pass. `automaticDaemonLoopPlanningExecuteWritesIssueSnapshotBeforeStart` asserts one `FakeWriteJson`, snapshot write before `turn/start`, one planner thread, one planner turn, and `IssuePlanningTurnStarted`.
- Command: `sed -n '4930,5005p' test/Main.hs`
  Result: pass. `automaticDaemonLoopPlanningClosedScopeCompletesWithoutPlannerTurn` asserts one snapshot write, `IssuePlanningScopeCompleted`, `Complete`, and no planner thread or turn start.
- Command: `find golden -name 'issue-snapshot.json' -o -name '*snapshot*' | sort`
  Result: pass. No checked-in `golden/**/issue-snapshot.json` file and no `golden/**` `*snapshot*` path were found.
- Command: `find golden -maxdepth 3 -type d | sort`
  Result: pass. Existing golden directories are event-log, issue-implement, issue-planning event-log, and PR-review fixtures; none is a live issue-planning `issue-snapshot.json` fixture.
- Command: `rg -n "issue-snapshot\\.json|issueSnapshotPath|ensureIssuePlanningSnapshot|buildIssuePlanningSnapshot|planningSnapshotScopeCompleted|startPlannerTurn|automaticDaemonLoopPlanningExecuteWritesIssueSnapshotBeforeStart|automaticDaemonLoopPlanningClosedScopeCompletesWithoutPlannerTurn" src app test scripts docs golden orchestrator/rounds/round-053 orchestrator/rounds/round-055 orchestrator/rounds/round-057 orchestrator/rounds/round-070`
  Result: pass. Positive hits match the live writer path, prompt/turn-output path, timing tests, prior evidence, and the new round artifact.
- Command: `rg -n "issue-snapshot\\.json|issueSnapshotPath" src/CodexWatcher/Healthcheck.hs src/CodexWatcher/Cli/Command/Replay.hs src/CodexWatcher/EventLogRepair.hs scripts/restart-watcher src/CodexWatcher/Snapshot.hs src/CodexWatcher/GoldenReplay.hs test docs golden`
  Result: pass. Hits are limited to tests and docs/policy evidence; no healthcheck, repair, restart, snapshot-loader, or replay implementation reads live `issue-snapshot.json`.
- Command: `rg -n "snapshot|Snapshot|issue-snapshot\\.json|issueSnapshotPath|repair|Repair|replay|healthcheck|Healthcheck|restart" src/CodexWatcher/Healthcheck.hs src/CodexWatcher/Cli/Command/Replay.hs src/CodexWatcher/EventLogRepair.hs scripts/restart-watcher src/CodexWatcher/Snapshot.hs src/CodexWatcher/GoldenReplay.hs`
  Result: pass. Healthcheck, repair, replay, restart, `Snapshot`, and `GoldenReplay` surfaces operate on event logs, repair state, runtime-owner/restart command handling, and node PR-review/issue-implementation snapshots; no live issue snapshot reader is present.
- Command: `rg -n 'Live `issue-snapshot\.json`|issue-snapshot\.json|defer|fixture|healthcheck|external operator|downstream|write-timing|removal|migration' docs/agentic-workflow-framework/compatibility-deprecation-policy.md orchestrator/rounds/round-053 orchestrator/rounds/round-055 orchestrator/rounds/round-057 orchestrator/rounds/round-070`
  Result: pass. Current policy and prior rounds classify live `issue-snapshot.json` as `defer`, with missing old/live fixture coverage, external/downstream inventory, and explicit write-timing migration evidence.

### Plan Compliance
- Step 1, re-read control inputs and evidence-only selection: met. Selection, project contract, and verification contract were read; selected direction remains `direction-019-live-issue-snapshot-fixture-timing`.
- Step 2, refresh active roadmap context: met. Roadmap readback confirms `rev-002`, strategy-backlog, milestone 006 runtime follow-up evidence, and removals gated until milestone 008 after external inventory and reviewer approval.
- Step 3, refresh prior evidence and policy classification: met. The artifact carries forward rounds 053/055/057 and policy evidence: live `issue-snapshot.json` remains `defer`, no checked-in live fixture, no healthcheck reader, and missing external/downstream evidence.
- Step 4, inspect live writer path: met. The artifact accurately records `runPlanningReady` -> `ensureIssuePlanningSnapshot` -> `buildIssuePlanningSnapshot`, execute-only write, and `runtimeStateDirFile ... "issue-snapshot.json"`.
- Step 5, record snapshot value shape and scoped/unscoped behavior: met. The artifact records `repoFullName`, `scopeIssueNumbers`, `issues`, unscoped `note`, scoped `gh issue view`, scoped `gh api ... /sub_issues`, and closed-scope completion after snapshot write.
- Step 6, inspect prompt and turn-output contract: met. The artifact records the developer prompt `{{issueSnapshotPath}}` instruction and `TurnOutput.hs` path rendering to `<stateDir>/issue-snapshot.json`.
- Step 7, inspect focused timing tests: met. The artifact records both timing tests and their core assertions.
- Step 8, search checked-in fixtures: met. `find golden -name 'issue-snapshot.json' -o -name '*snapshot*' | sort` returned no paths; the artifact separates existing golden directories from absent live issue-planning snapshot fixture coverage.
- Step 9, inspect healthcheck, repair, restart, and replay non-use: met. Focused scans support no live `issue-snapshot.json` reader in those surfaces, and the artifact correctly treats absence as non-use evidence only.
- Step 10, create round-local evidence artifact with required sections: met. `live-issue-snapshot-fixture-timing.md` includes scope/non-goals, writer path, JSON shape, write timing, prompt/turn output, closed-scope behavior, fixture inventory, tests, non-use readback, classification, blockers, and conclusion.
- Step 11, keep blockers conservative: met. The artifact preserves missing fixture coverage, missing external/downstream direct-reader inventory, and no selected approval for filename, schema, event-type, write-timing, planner-turn, projection, healthcheck, repair, replay, cleanup, removal, migration, publication, upload, or release.
- Step 12, implementation notes: met. `implementation-notes.md` lists changed files, scans, fixture-search result, focused tests, skipped baseline rationale, and no production behavior change.

### Decision
**APPROVED**

### Evidence
The integrated round result is artifact-only and stays within `orchestrator/rounds/round-070`. No production source, tests, fixtures, scripts, docs outside the selected round, roadmap files, package files, or controller state were changed. Under the active verification contract's artifact-only allowance, `cabal build all`, `cabal test watcher-core-test`, and `scripts/validate-workflow-packages.sh` were not applicable and were skipped with this explicit rationale.

The new evidence is source-backed. `Loop.hs` shows execute mode creates the snapshot before planner turn start, while dry-run starts the planner directly. The snapshot value shape and scoped/unscoped behavior in `buildIssuePlanningSnapshot` match the artifact. `PromptTemplates.hs` and `TurnOutput.hs` confirm the planner prompt/turn-output contract points at `<stateDir>/issue-snapshot.json`. `test/Main.hs` contains focused tests for write-before-start and closed-scope completion without starting a planner thread or turn.

Fixture and non-use claims are also source-backed. The golden fixture search found no live `issue-snapshot.json` fixture. Focused scans found no healthcheck, repair, restart, snapshot-loader, or replay implementation reading the live issue snapshot. The artifact correctly keeps this as conservative `defer` evidence and does not authorize schema, filename, event type, timing, planner-turn, projection, healthcheck, repair, replay, cleanup, deprecation, removal, publication, upload, or release changes.
