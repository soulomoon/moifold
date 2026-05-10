### Goal

Add focused checked-in fixture coverage and watcher-core assertions for the
current live `issue-snapshot.json` issue-planning snapshot surface.

This round covers the next `direction-007-runtime-compatibility-fixtures`
blocker from the round-087 inventory: live `issue-snapshot.json` is written in
execute mode before planner turn start, rendered into the planner prompt as
the current issue snapshot path, and currently has no healthcheck, repair,
replay, restart-script, or golden snapshot direct-reader role. The
implementation must preserve the current filename, current top-level snapshot
shape, current scoped issue/sub-issue shape, write-before-planner-turn timing,
planner prompt path rendering, and explicit non-reader boundaries. It must not
change planner prompt semantics, planner-turn behavior, healthcheck behavior,
repair behavior, replay behavior, restart behavior, runtime compatibility file
names, schema, migration, deprecation, removal, roadmap files, or controller
state.

### Approach

Use one serial implementation pass. Worker fan-out is not justified because
the selected fixture, writer/timing assertion, prompt path assertion, and
non-reader source-boundary assertions protect one tightly coupled compatibility
surface in the existing watcher-core runtime-compatibility fixture module.

Extend the existing runtime-compatibility fixture namespace with one live
issue-snapshot fixture, keeping it separate from full golden snapshot
directories so it is not mistaken for `loadNodeSnapshot` replay/bootstrap
input:

- `golden/runtime-compatibility/issue-snapshot/scoped-open-with-closed-subissue/issue-snapshot.json`

Use a deterministic scoped issue snapshot that reflects the current writer
contract from `buildIssuePlanningSnapshot`: top-level `repoFullName`,
`scopeIssueNumbers`, and `issues`; each scoped issue keeps the JSON returned by
`gh issue view` plus writer-added `parentIssueNumber` and `subIssues`; sub-issue
entries keep the current `gh api .../sub_issues --jq` shape.

The fixture should use this logical shape:

```json
{
  "repoFullName": "soulomoon/mlf2",
  "scopeIssueNumbers": [12],
  "issues": [
    {
      "number": 12,
      "title": "Root issue",
      "state": "OPEN",
      "closed": false,
      "body": "Root body",
      "url": "https://github.com/soulomoon/mlf2/issues/12",
      "labels": [],
      "assignees": [],
      "createdAt": "2026-01-01T00:00:00Z",
      "updatedAt": "2026-01-02T00:00:00Z",
      "parentIssueNumber": null,
      "subIssues": [
        {
          "number": 26,
          "title": "Sub issue",
          "state": "CLOSED",
          "closed": true,
          "body": "Sub body",
          "url": "https://github.com/soulomoon/mlf2/issues/26",
          "parentIssueNumber": 12
        }
      ]
    }
  ]
}
```

Add assertions to `test/RuntimeCompatibilityFixtureSpec.hs`, which is already
listed in `moifold.cabal` and already called from `test/Main.hs`. Do not create
a new test module or change Cabal/Main wiring unless the implementation branch
has unexpectedly diverged from the observed round-090 through round-094 state.
The expected implementation paths are the new fixture file,
`test/RuntimeCompatibilityFixtureSpec.hs`, and the implementer's
`orchestrator/rounds/round-095/implementation-notes.md`.

### Steps

1. Reconfirm current scope and inputs before editing:
   - `git status --short --untracked-files=all`
   - `python3 -m json.tool orchestrator/state.json`
   - `sed -n '1,220p' orchestrator/rounds/round-095/selection.md`
   - `sed -n '1,280p' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`
   - `sed -n '1,240p' orchestrator/project-contract.md`
   - `sed -n '1,170p' orchestrator/rounds/round-087/compatibility-fixture-gap-inventory.md`
   - `sed -n '1,220p' orchestrator/rounds/round-094/plan.md`
2. Reconfirm the current live issue-snapshot writer, prompt path, prompt text,
   and non-reader boundaries before editing:
   - `rg -n "issue-snapshot\\.json|issuePlanningSnapshotPath|issueSnapshotPath|buildIssuePlanningSnapshot|ensureIssuePlanningSnapshot|planningIssueFactsFromSnapshot|stateFileSpecs|repairInvalidState|read_runtime_owner_pid" src app test docs scripts golden -g '!dist-newstyle/**'`
   - inspect `src/CodexWatcher/Domain/IssuePlanning/Loop.hs` around
     `runPlanningReady`, `ensureIssuePlanningSnapshot`,
     `issuePlanningSnapshotPath`, `buildIssuePlanningSnapshot`,
     `fetchScopedIssueSnapshot`, `fetchIssueJson`, and
     `fetchSubIssuesJson`;
   - inspect `src/CodexWatcher/PromptTemplates.hs` and
     `src/CodexWatcher/TurnOutput.hs` enough to confirm the planner prompt
     still renders `issueSnapshotPath` as `stateDir </> "issue-snapshot.json"`
     and instructs the planner to read it;
   - inspect `src/CodexWatcher/Healthcheck.hs`,
     `src/CodexWatcher/Cli/Command/Replay.hs`,
     `src/CodexWatcher/Snapshot.hs`, and `scripts/restart-watcher` to confirm
     they remain non-readers of live `issue-snapshot.json`.
3. Add the fixture file listed in the Approach section. Keep JSON formatting
   deterministic and keep the fixture path limited to
   `golden/runtime-compatibility/issue-snapshot/...`.
4. Extend `runtimeCompatibilityFixtureTests` with an issue-snapshot fixture
   group. Keep the existing planner/planning, daemon-state, block-state,
   repair-state, and runtime-owner tests intact.
5. In the issue-snapshot fixture group, load the fixture as `Value` with
   `eitherDecodeStrict'` and assert exact equality with an in-test
   deterministic `fixtureIssueSnapshotValue`. Assert the current shape
   directly:
   - top-level object contains `repoFullName`, `scopeIssueNumbers`, and
     `issues`;
   - top-level object does not contain runtime-state fields such as `status`,
     `ready_issues`, `blocked_issues`, `dependencies`, `lease`, `blocked`, or
     `repaired`;
   - the root issue keeps `number`, `title`, `state`, `closed`, `body`, `url`,
     `labels`, `assignees`, `createdAt`, `updatedAt`, `parentIssueNumber`,
     and `subIssues`;
   - `parentIssueNumber` is `null` for the scoped root issue;
   - `subIssues` is an array containing the deterministic closed child issue;
   - the child issue keeps `number`, `title`, `state`, `closed`, `body`, `url`,
     and `parentIssueNumber`.
6. Add a fixture-backed parser assertion using
   `planningIssueFactsFromSnapshot`: the fixture should produce an open root
   fact for issue `12` with sub-issue `26`, and a closed child fact for issue
   `26` with parent issue `12`. This locks the current snapshot shape as
   usable by canonical planning without adding a new live runtime reader.
7. Add a direct execute-writer assertion without changing production exports:
   use `runAutomaticDaemonLoopOnceWithEvents`, `fakeActionExecutorWith`, and a
   local deterministic JSON `CommandReport` helper in
   `test/RuntimeCompatibilityFixtureSpec.hs` if needed. Feed the same root
   issue and sub-issue command results used by the fixture, run a ready
   issue-planning loop in `ExecuteActions`, and assert:
   - exactly one write occurs at
     `runtimeStateDirFile runtimeConfig.effectRuntimeStateDir "issue-snapshot.json"`;
   - the written value equals the checked-in fixture value;
   - the snapshot write occurs before the planner `turn/start` app-server
     request;
   - the loop still starts one planner thread and one planner turn for the
     open scoped issue case.
   Preserve the existing `test/Main.hs` snapshot timing and closed-scope tests;
   do not weaken or delete them.
8. Add or extend focused source-boundary assertions for prompt consumption and
   non-reader behavior:
   - `runPlanningReady` in execute mode still calls
     `ensureIssuePlanningSnapshot` before `startPlannerTurn`;
   - `issuePlanningSnapshotPath` still uses `runtimeStateDirFile ...`
     `"issue-snapshot.json"`;
   - `buildIssuePlanningSnapshot` still writes top-level `repoFullName`,
     `scopeIssueNumbers`, and `issues`;
   - `fetchScopedIssueSnapshot` still adds `parentIssueNumber` and
     `subIssues`;
   - the planner developer instructions still render
     `issueSnapshotPath` from `stateDir </> "issue-snapshot.json"`;
   - the planner prompt still tells the planner to read the current issue
     snapshot;
   - `Healthcheck.hs`, `Cli/Command/Replay.hs`, `Snapshot.hs`, and
     `scripts/restart-watcher` still do not reference `issue-snapshot.json`.
9. Inspect the final diff and keep it inside the selected implementation
   surface. Do not edit `orchestrator/state.json`, roadmap files, production
   behavior, docs/policy files, healthcheck behavior, repair behavior, replay
   behavior, restart/script behavior, compatibility file names, Cabal
   exposure, public facades, unrelated fixtures, or runtime compatibility
   cleanup classifications.

### Verification

Run the focused checks first:

- `find golden/runtime-compatibility/issue-snapshot -type f | sort`
- `python3 -m json.tool golden/runtime-compatibility/issue-snapshot/scoped-open-with-closed-subissue/issue-snapshot.json`
- `rg -n "issue-snapshot\\.json|issuePlanningSnapshotPath|issueSnapshotPath|buildIssuePlanningSnapshot|ensureIssuePlanningSnapshot|planningIssueFactsFromSnapshot|RuntimeCompatibilityFixtureSpec|runtimeCompatibilityFixtureTests|runAutomaticDaemonLoopOnceWithEvents" golden test src app docs scripts -g '!dist-newstyle/**'`
- `cabal test watcher-core-test`
- `git diff --check`
- `git status --short --untracked-files=all`

Run the roadmap baseline because tests and fixtures are expected to change:

- `cabal build all`

If staging occurs, also run:

- `git diff --cached --check`

Reviewers should specifically confirm:

- the fixture file is checked in at the expected
  `golden/runtime-compatibility/issue-snapshot/scoped-open-with-closed-subissue/issue-snapshot.json`
  path;
- fixture tests would fail if the live issue snapshot loses or renames
  `repoFullName`, `scopeIssueNumbers`, `issues`, `parentIssueNumber`, or
  `subIssues`;
- fixture tests would fail if scoped root issue fields or sub-issue fields stop
  matching the current GitHub command output contract;
- `planningIssueFactsFromSnapshot` still accepts the checked-in fixture and
  derives the expected open-root/closed-child facts;
- execute-mode planning writes the checked-in fixture value to
  `issue-snapshot.json` before starting the planner turn;
- planner thread instructions still render and mention the
  `issue-snapshot.json` path;
- healthcheck, repair, replay/snapshot loading, and restart-script paths remain
  non-readers of live `issue-snapshot.json`;
- no checked-in snapshot cleanup, healthcheck behavior change, repair behavior
  change, replay behavior change, restart behavior change, docs/policy
  expansion, roadmap edit, controller-state edit, rename, deletion, migration,
  deprecation, or removal work escaped into this round.

### Worker Fan-Out

No worker fan-out is used. The round is serial and does not write
`worker-plan.json`.
