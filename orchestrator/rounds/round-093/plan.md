### Goal

Add focused checked-in fixture coverage and watcher-core assertions for the
current `repair-state.json` repair summary shape written by
`repair-invalid-state --execute`.

This round covers the next `direction-007-runtime-compatibility-fixtures`
blocker from the round-087 inventory: `repair-state.json` has a single repair
execute writer, no production Haskell reader, no healthcheck reader, and no
checked-in fixture. The implementation must preserve the current filename,
summary schema, execute write ordering, compatibility rewrite ordering, stale
`block-state.json` cleanup timing, explicit non-reader status, and explicit
non-healthcheck status. It must not change repair behavior, replay behavior,
healthcheck behavior, script behavior, writer timing, schema, migration,
deprecation, removal, roadmap files, or controller state.

### Approach

Use one serial implementation pass. Worker fan-out is not justified because
the selected fixture file, repair-summary assertions, source-order assertions,
non-reader/non-healthcheck assertions, and existing watcher-core fixture module
all touch one tightly coupled compatibility test surface.

Extend the existing runtime-compatibility fixture namespace with a repair-state
fixture, keeping it separate from full golden snapshot directories so it is
not mistaken for `loadNodeSnapshot` input:

- `golden/runtime-compatibility/repair-state/completion-without-implementation/repair-state.json`

Use the deterministic completion-without-implementation repair scenario already
covered in nearby event-log repair tests:

- `IssueImplementInitialized (IssueConfig (RepoName "soulomoon/mlf2") (IssueNumber 42) (BranchName "codex/issue-42")) (ThreadId "worker-thread")`
- `IssuePullRequestCreatedEvent (PrNumber 7)`
- `IssuePlanTurnStartedEvent (TurnId "turn-plan")`
- `IssuePlanCompletedEvent "Implement the issue in small verified steps." Nothing`
- `IssueImplementationCompletedEvent (PrNumber 7) Nothing`

The fixture should use a deterministic archive path such as
`/tmp/runtime-compatibility-fixtures/events.jsonl.invalid-fixture` and match the
current repair summary fields:

```json
{
  "repaired": true,
  "strategy": "dropped unsafe completion and re-entered implementation",
  "archivePath": "/tmp/runtime-compatibility-fixtures/events.jsonl.invalid-fixture",
  "failedEventIndex": 5,
  "failedEventType": "issue_implementation_completed",
  "failedReason": "event issue_implementation_completed is invalid in IssueImplement/PlanReady",
  "insertedEvents": ["watcher_recovered_invalid_state"],
  "droppedEvents": ["issue_implementation_completed"],
  "finalDomain": "IssueImplement",
  "finalPhase": "PlanReady"
}
```

Add assertions to `test/RuntimeCompatibilityFixtureSpec.hs`, which is already
listed in `moifold.cabal` and already called from `test/Main.hs`. Do not create
a new test module or change Cabal/Main wiring unless the implementation branch
has unexpectedly diverged from the observed round-090 through round-092 state.
The expected implementation paths are the new fixture file,
`test/RuntimeCompatibilityFixtureSpec.hs`, and the implementer's
`orchestrator/rounds/round-093/implementation-notes.md`.

### Steps

1. Reconfirm current scope and inputs before editing:
   - `git status --short --untracked-files=all`
   - `python3 -m json.tool orchestrator/state.json`
   - `sed -n '1,220p' orchestrator/rounds/round-093/selection.md`
   - `sed -n '1,260p' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`
   - `sed -n '1,240p' orchestrator/project-contract.md`
   - `sed -n '1,260p' orchestrator/rounds/round-087/compatibility-fixture-gap-inventory.md`
   - `sed -n '1,220p' orchestrator/rounds/round-065/repair-state-fixture-reader-policy.md`
2. Reconfirm the current repair writer, repair plan, non-reader, and
   non-healthcheck paths before editing:
   - `rg -n "repair-state\\.json|repairInvalidState|writeRepairSummary|writeCompatibilityFiles|removeFileIfExists|repairIssueImplementEventLog|stateFileSpecs" src app test docs scripts golden -g '!dist-newstyle/**'`
   - inspect `src/CodexWatcher/Cli/Command/Replay.hs` around
     `repairInvalidState`, `writeRepairSummary`, `writeCompatibilityFiles`,
     and `removeFileIfExists`;
   - inspect `src/CodexWatcher/EventLogRepair.hs` around
     `repairCompletionWithoutImplementationTurn`;
   - inspect `src/CodexWatcher/Healthcheck.hs` to confirm
     `stateFileSpecs` still excludes `repair-state.json`;
   - inspect `src/CodexWatcher/Snapshot.hs`, `src/CodexWatcher/Runtime`, and
     `src/CodexWatcher/AutomaticLoop` enough to confirm no production
     Haskell reader of `repair-state.json` exists in the current source.
3. Add the fixture file listed in the Approach section. Keep JSON formatting
   deterministic and keep the fixture path limited to
   `golden/runtime-compatibility/repair-state/...`.
4. Extend `runtimeCompatibilityFixtureTests` with a repair-state fixture group.
   Keep the existing planner/planning, daemon-state, and block-state tests
   intact.
5. In the repair-state fixture group, load the fixture as `Value` with
   `eitherDecodeStrict'` and assert exact equality with an expected summary
   value constructed from the deterministic repair plan and fixture archive
   path. Use `repairIssueImplementEventLog` to derive the plan; do not expose
   or mutate production writer internals just to make the test pass.
6. Assert the fixture keeps the current exact repair summary shape:
   - `repaired` is `true`;
   - `strategy` is the plan strategy;
   - `archivePath` is the deterministic fixture archive path;
   - `failedEventIndex`, `failedEventType`, and `failedReason` match
     `plan.repairFailure`;
   - `insertedEvents` is the list of `eventName` values for
     `plan.repairInsertedEvents`;
   - `droppedEvents` is the list of `eventName` values for
     `plan.repairDroppedEvents`;
   - `finalDomain` and `finalPhase` match `show (someDomain ...)` and
     `show (somePhase ...)` for `plan.repairReplayResult.replayState`;
   - the fixture does not contain repair-failure `block-state.json` fields
     such as `blocked`, `blockedKind`, `eventIndex`, `eventType`, or `event`.
7. Add a direct execute-shape assertion if it can be done without new package
   dependencies: write the deterministic invalid events to a throwaway
   `/tmp/moifold-repair-state-fixture-test/events.jsonl`, run
   `repairInvalidState` with `repairCliExecute = True`, decode the generated
   `repair-state.json`, normalize only its timestamped `archivePath` to the
   deterministic fixture archive path, and compare the normalized value to the
   fixture. Clean the throwaway directory before and after the test. If this
   proves too invasive for the fixture module, keep the source-order assertion
   from step 8 and record the reason in implementation notes.
8. Add or extend focused source-boundary assertions for the current execute
   order and field mapping:
   - `repairInvalidState` dry-run reports the repair plan before mutation and
     does not enter the execute write branch;
   - execute order remains archive invalid log, write repaired `events.jsonl`,
     write `repair-state.json`, rewrite compatibility files from repaired
     replay state, then remove stale `block-state.json`;
   - `writeRepairSummary` writes exactly `repair-state.json` and includes the
     fields listed in this plan;
   - `writeCompatibilityFiles` remains separate from `writeRepairSummary`.
9. Add or extend focused non-reader and non-healthcheck assertions:
   - `Healthcheck.hs` does not list `repair-state.json` in `stateFileSpecs` or
     `sharedStateFiles`;
   - `Snapshot.hs` does not read `repair-state.json`;
   - the focused source scan still finds production `repair-state.json` use
     only in the repair writer path, with docs/tests/policy mentions treated
     as evidence rather than runtime readers.
   These are behavior locks only; do not add a healthcheck reader or a
   production reader in this round.
10. Inspect the final diff and keep it inside the selected implementation
    surface. Do not edit `orchestrator/state.json`, roadmap files, production
    behavior, docs/policy files, healthcheck behavior, repair behavior, replay
    behavior, restart/script behavior, compatibility file names, Cabal
    exposure, public facades, or unrelated fixtures.

### Verification

Run the focused checks first:

- `find golden/runtime-compatibility/repair-state -type f | sort`
- `python3 -m json.tool golden/runtime-compatibility/repair-state/completion-without-implementation/repair-state.json`
- `rg -n "repair-state\\.json|RuntimeCompatibilityFixtureSpec|runtimeCompatibilityFixtureTests|repairInvalidState|writeRepairSummary|writeCompatibilityFiles|removeFileIfExists|repairIssueImplementEventLog|stateFileSpecs" golden test src app scripts docs -g '!dist-newstyle/**'`
- `cabal test watcher-core-test`
- `git diff --check`
- `git status --short --untracked-files=all`

Run the roadmap baseline because tests and fixtures are expected to change:

- `cabal build all`

If staging occurs, also run:

- `git diff --cached --check`

Reviewers should specifically confirm:

- the fixture file is checked in at the expected
  `golden/runtime-compatibility/repair-state/completion-without-implementation/repair-state.json`
  path;
- fixture tests would fail if the repair summary loses, renames, or changes
  any current summary field;
- fixture tests distinguish `repair-state.json` from repair-failure
  `block-state.json`;
- execute write ordering still writes `repair-state.json` before
  compatibility rewrite and removes stale `block-state.json` only afterward;
- healthcheck and snapshot remain non-readers of `repair-state.json`;
- no `runtime-owner.json`, checked-in snapshot, live `issue-snapshot.json`,
  healthcheck-contract, operator/downstream, production behavior, docs/policy,
  roadmap, controller-state, rename, deletion, migration, deprecation, or
  removal work escaped into this round.
