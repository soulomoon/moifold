### Goal

Record source-backed evidence for live `issue-snapshot.json` fixture coverage
and write timing in the issue-planning workflow, especially the contract that
execute-mode snapshot creation happens before planner turn start.

This is an evidence-only round for
`direction-019-live-issue-snapshot-fixture-timing` under
`milestone-006-runtime-compatibility-follow-up-evidence`. It must not change
filenames, schemas, event JSON `type` fields, planner turn behavior,
compatibility projection behavior, healthcheck behavior, repair behavior,
runtime cleanup/removal behavior, production source, tests, fixtures, scripts,
roadmap files, controller state, package metadata, deprecation status, removal
approval, publication, upload, or release approval.

### Approach

Keep the work sequential and round-local. Use
`orchestrator/project-contract.md` for stable compatibility invariants and the
active verification contract for baseline expectations. Do not write
`worker-plan.json`: this direction is a single tightly coupled runtime
compatibility surface whose writer path, timing tests, fixture gap,
healthcheck/repair non-use, prompt contract, and prior evidence should be read
together.

The implementer should create one round-local evidence artifact, expected as
`orchestrator/rounds/round-070/live-issue-snapshot-fixture-timing.md`, plus
round-local implementation notes if they normally record them. The artifact
should be descriptive and conservative. If a checked-in live
`issue-snapshot.json` fixture is still absent, record that as fixture-gap
evidence; do not add fixture files or tests unless a later reviewed plan
explicitly authorizes non-round-local writes.

### Steps

1. Re-read the round/control inputs before editing:
   `orchestrator/rounds/round-070/selection.md`,
   `orchestrator/project-contract.md`, and
   `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/verification.md`.
   Confirm the selected direction remains
   `direction-019-live-issue-snapshot-fixture-timing` and that this round is
   evidence-only.

2. Refresh the active roadmap context in
   `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/roadmap.md`.
   Treat the baseline as: directions 013 through 018 are complete, direction
   019 is the remaining milestone-006 evidence item, runtime compatibility
   follow-up rounds remain serial, and runtime compatibility-file removals are
   not allowed until milestone 008 after later external inventory and explicit
   reviewer approval.

3. Refresh prior evidence from rounds 053, 055, and 057, plus
   `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`.
   Carry forward the current conservative classification: live
   `issue-snapshot.json` is `defer`; round 053 and round 055 already record
   production before planner turn start, no checked-in live fixture, no
   healthcheck reader, and missing external/operator evidence.

4. Inspect `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`. Record the current
   execute-mode write path precisely:
   `runPlanningReady` calls `ensureIssuePlanningSnapshot` before
   `startPlannerTurn`; `ensureIssuePlanningSnapshot` calls
   `buildIssuePlanningSnapshot`, writes
   `issuePlanningSnapshotPath` only in `ExecuteActions`, and then returns the
   snapshot value; `issuePlanningSnapshotPath` resolves
   `runtimeStateDirFile ... "issue-snapshot.json"`.

5. In the same source file, record the current snapshot value shape and
   completion behavior:
   `buildIssuePlanningSnapshot` writes `repoFullName`, `scopeIssueNumbers`,
   and `issues`; unscoped planning writes an empty issue list plus the
   explanatory `note`; scoped planning fetches `gh issue view` JSON and
   sub-issues from `gh api ... /sub_issues`; `planningSnapshotScopeCompleted`
   may complete a closed scoped tree after the snapshot write and without
   starting a planner turn.

6. Inspect planner prompt surfaces that make the live snapshot an agent
   contract. Record `src/CodexWatcher/PromptTemplates.hs`, especially the
   instruction to read the current issue snapshot and the template reference
   to `{{issueSnapshotPath}}`. Also inspect
   `src/CodexWatcher/TurnOutput.hs` for the emitted `issueSnapshotPath` value
   pointing at `<stateDir>/issue-snapshot.json`.

7. Inspect focused timing coverage in `test/Main.hs`. Record
   `automaticDaemonLoopPlanningExecuteWritesIssueSnapshotBeforeStart` as the
   primary write-before-start test: it asserts one `FakeWriteJson` to
   `issue-snapshot.json`, verifies the snapshot write occurs before the
   `turn/start` app-server request, starts one planner thread, and emits
   `IssuePlanningTurnStarted`. Record
   `automaticDaemonLoopPlanningClosedScopeCompletesWithoutPlannerTurn` as the
   closed-scope companion: it asserts one snapshot write, emits
   `IssuePlanningScopeCompleted`, reaches `Complete`, and starts no planner
   thread or turn.

8. Search checked-in fixtures explicitly. At minimum, run
   `find golden -name 'issue-snapshot.json' -o -name '*snapshot*' | sort`.
   Separate checked-in PR review and issue implementation golden snapshot
   directories from live issue-planning `issue-snapshot.json`. If no checked-in
   live fixture exists, record that exact gap rather than inferring fixture
   coverage from timing tests.

9. Inspect healthcheck, repair, restart, and replay surfaces to prove non-use
   without changing behavior. Use focused searches over
   `src/CodexWatcher/Healthcheck.hs`, `src/CodexWatcher/Cli/Command/Replay.hs`,
   `src/CodexWatcher/EventLogRepair.hs`, `scripts/restart-watcher`,
   `src/CodexWatcher/Snapshot.hs`, `src/CodexWatcher/GoldenReplay.hs`, `test`,
   `docs`, and `golden`. Record whether live `issue-snapshot.json` is read,
   repaired, cleaned, replayed, or only referenced by planning prompt/write
   timing evidence. Do not convert absence into removal readiness.

10. Create the round-local evidence artifact with sections for scope and
    non-goals, live writer path, JSON shape and source commands, write timing
    contract, planner prompt/turn-output contract, closed-scope completion
    behavior, fixture inventory, current tests, healthcheck/repair/replay/
    restart readback, current classification, and blockers.

11. Keep blockers conservative. At minimum, retain missing checked-in old/live
    `issue-snapshot.json` fixture coverage, missing external operator or
    downstream direct-reader inventory, no selected approval for filename,
    schema, event-type, write-timing, planner-turn, compatibility-projection,
    healthcheck, repair, replay, or cleanup behavior changes, and no migration,
    deprecation, removal, publication, upload, or release approval.

12. If implementation notes are written, include changed files, exact scans
    run, fixture-search results, focused test names, any skipped baseline
    rationale, and a statement that no production behavior changed.

### Verification

Use focused readback commands first:

```sh
sed -n '1,220p' orchestrator/rounds/round-070/selection.md
sed -n '1,260p' orchestrator/project-contract.md
sed -n '1,320p' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/verification.md
rg -n "direction-019|milestone-006|issue-snapshot" orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/roadmap.md
sed -n '45,255p' src/CodexWatcher/Domain/IssuePlanning/Loop.hs
sed -n '280,325p' src/CodexWatcher/PromptTemplates.hs
sed -n '320,345p' src/CodexWatcher/TurnOutput.hs
sed -n '4790,4870p' test/Main.hs
sed -n '4930,5005p' test/Main.hs
```

Run focused scans and record results:

```sh
find golden -name 'issue-snapshot.json' -o -name '*snapshot*' | sort
rg -n "issue-snapshot\\.json|issueSnapshotPath|ensureIssuePlanningSnapshot|buildIssuePlanningSnapshot|planningSnapshotScopeCompleted|startPlannerTurn|automaticDaemonLoopPlanningExecuteWritesIssueSnapshotBeforeStart|automaticDaemonLoopPlanningClosedScopeCompletesWithoutPlannerTurn" src app test scripts docs golden orchestrator/rounds/round-053 orchestrator/rounds/round-055 orchestrator/rounds/round-057 orchestrator/rounds/round-070
rg -n "issue-snapshot\\.json|Healthcheck|healthcheck|repair|Repair|restart|Snapshot|GoldenReplay|replay|fixture|external operator|downstream|defer|removal|migration" src/CodexWatcher test scripts docs golden orchestrator/rounds/round-053 orchestrator/rounds/round-055 orchestrator/rounds/round-057 orchestrator/rounds/round-070
rg -n 'Live `issue-snapshot\.json`|issue-snapshot\.json|defer|fixture|healthcheck|external operator|downstream|write-timing|removal|migration' docs/agentic-workflow-framework/compatibility-deprecation-policy.md orchestrator/rounds/round-053 orchestrator/rounds/round-055 orchestrator/rounds/round-057 orchestrator/rounds/round-070
```

Validate the artifact-only diff:

```sh
git status --short --branch
git diff --name-only
git diff --check
rg -n "[ \t]+$" orchestrator/rounds/round-070
```

Baseline expectations from the active verification contract are
`cabal build all`, `cabal test watcher-core-test`,
`scripts/validate-workflow-packages.sh`, `git diff --check`, and
`git diff --cached --check` when staging is involved. If the implementation
diff remains limited to round-local orchestrator evidence artifacts, the Cabal
and package baselines may be skipped under the artifact-only allowance. If the
diff touches production source, tests, fixtures, scripts, docs outside the
selected evidence artifact, roadmap files, package files, or controller state,
the implementer must stop and either narrow the diff back to the selected
evidence scope or run the full baseline before review.
