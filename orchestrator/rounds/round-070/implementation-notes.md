### Changes Made

- `orchestrator/rounds/round-070/live-issue-snapshot-fixture-timing.md`: added the source-backed evidence artifact for live `issue-snapshot.json` writer timing, prompt contract, fixture inventory, healthcheck/repair/restart/replay non-use, current `defer` classification, and conservative blockers.
- `orchestrator/rounds/round-070/implementation-notes.md`: recorded the artifact-only implementation notes for reviewer readback.

### Tests

- No production tests were added or changed. This round is evidence-only and the diff is limited to round-local orchestrator artifacts.
- Existing focused tests recorded as evidence:
  - `test/Main.hs`: `automaticDaemonLoopPlanningExecuteWritesIssueSnapshotBeforeStart` protects execute-mode snapshot write before planner turn start.
  - `test/Main.hs`: `automaticDaemonLoopPlanningClosedScopeCompletesWithoutPlannerTurn` protects closed-scope completion after snapshot write without planner thread or turn start.

### Readbacks And Scans

Focused source readbacks:

```sh
sed -n '1,220p' orchestrator/rounds/round-070/selection.md
sed -n '1,260p' orchestrator/project-contract.md
sed -n '1,320p' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/verification.md
rg -n "direction-019|milestone-006|issue-snapshot" orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/roadmap.md
sed -n '45,255p' src/CodexWatcher/Domain/IssuePlanning/Loop.hs
sed -n '255,430p' src/CodexWatcher/Domain/IssuePlanning/Loop.hs
sed -n '280,325p' src/CodexWatcher/PromptTemplates.hs
sed -n '320,345p' src/CodexWatcher/TurnOutput.hs
sed -n '4790,4870p' test/Main.hs
sed -n '4930,5005p' test/Main.hs
```

Focused fixture and non-use scans:

```sh
find golden -name 'issue-snapshot.json' -o -name '*snapshot*' | sort
find golden -maxdepth 3 -type d | sort | rg -n "snapshot|issue|pr-review|issue-implement"
rg -n "issue-snapshot\\.json|issueSnapshotPath|ensureIssuePlanningSnapshot|buildIssuePlanningSnapshot|planningSnapshotScopeCompleted|startPlannerTurn|automaticDaemonLoopPlanningExecuteWritesIssueSnapshotBeforeStart|automaticDaemonLoopPlanningClosedScopeCompletesWithoutPlannerTurn" src app test scripts docs golden orchestrator/rounds/round-053 orchestrator/rounds/round-055 orchestrator/rounds/round-057 orchestrator/rounds/round-070
rg -n "issue-snapshot\\.json|issueSnapshotPath" src/CodexWatcher/Healthcheck.hs src/CodexWatcher/Cli/Command/Replay.hs src/CodexWatcher/EventLogRepair.hs scripts/restart-watcher src/CodexWatcher/Snapshot.hs src/CodexWatcher/GoldenReplay.hs test docs golden
rg -n "snapshot|Snapshot|issue-snapshot\\.json|issueSnapshotPath|repair|Repair|replay|healthcheck|Healthcheck|restart" src/CodexWatcher/Healthcheck.hs src/CodexWatcher/Cli/Command/Replay.hs src/CodexWatcher/EventLogRepair.hs scripts/restart-watcher src/CodexWatcher/Snapshot.hs src/CodexWatcher/GoldenReplay.hs
rg -n 'Live `issue-snapshot\.json`|issue-snapshot\.json|defer|fixture|healthcheck|external operator|downstream|write-timing|removal|migration' docs/agentic-workflow-framework/compatibility-deprecation-policy.md orchestrator/rounds/round-053 orchestrator/rounds/round-055 orchestrator/rounds/round-057 orchestrator/rounds/round-070
```

Fixture search result: no checked-in `golden/**/issue-snapshot.json` file and no `golden/**` path matching `*snapshot*` were found. Related checked-in golden directories are PR-review, issue-implementation, and event-log fixtures, not live issue-planning snapshot files.

### Notes

No production source, tests, fixtures, scripts, docs, roadmap files, package files, controller state, or runtime behavior were changed.

The Cabal and package baselines were intentionally skipped under the active verification contract's artifact-only allowance because the diff remains limited to round-local orchestrator evidence artifacts. Validation still includes `git status --short --branch`, `git diff --name-only`, `git diff --check`, and a no-trailing-whitespace scan over `orchestrator/rounds/round-070`.
