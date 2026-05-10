### Goal

Record and test the current compatibility contract for `planner-state.json`
and `planning-state.json` as distinct runtime state surfaces.

This round should make the existing behavior explicit: compatibility projection
writes `planner-state.json` as the issue-planning summary/status surface,
compatibility projection and direct `RecordPlanningGraph` write
`planning-state.json` as the planning graph surface, and healthcheck currently
reads `planner-state.json` for issue planning while not reading
`planning-state.json`.

The round must not rename, delete, migrate, deprecate, or remove either file;
must not change healthcheck reader behavior; must not change repair behavior;
must not edit roadmap or controller state; and must not start a broad runtime
fixture campaign.

### Approach

Use one serial implementation pass. Worker fan-out is not justified: the
contract spans one tightly coupled pair of files, one healthcheck reader
boundary, and likely overlapping tests/docs.

Treat `orchestrator/project-contract.md`,
`orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`,
`orchestrator/rounds/round-088/selection.md`, and
`orchestrator/rounds/round-087/compatibility-fixture-gap-inventory.md` as the
authoritative planning inputs.

Keep the implementation focused on tests plus the smallest matching policy/doc
artifact update. The tests should lock current semantics rather than change
runtime behavior:

- `src/CodexWatcher/Runtime/Compatibility.hs` writes `planner-state.json` for
  `PlanningReady`, `PlanningTurnActive`, `PlanningWaitingForReadyIssues`, and
  planning completion; it writes `planning-state.json` only with the
  `PlanningWaitingForReadyIssues` planning graph.
- `src/CodexWatcher/EffectInterpreter.hs` writes `planning-state.json` for
  direct `RecordPlanningGraph`.
- `src/CodexWatcher/Healthcheck.hs` reads `planner-state.json` for
  `SIssuePlanning` and does not include `planning-state.json` in
  `stateFileSpecs`.
- Existing docs/policy mostly name `planning-state.json`; this round may add a
  narrow policy note that distinguishes it from `planner-state.json`, but must
  not classify either surface as removable.

Do not add checked-in fixture files unless the implementer finds an existing
small fixture pattern that can be limited strictly to these two names and their
current shapes. If fixtures are added, they must be only
`planner-state.json`/`planning-state.json` contract fixtures and not a broader
runtime-state fixture batch.

### Steps

1. Reconfirm current scope and inputs:
   - `git status --short --untracked-files=all`
   - `sed -n '1,220p' orchestrator/state.json`
   - `sed -n '1,220p' orchestrator/project-contract.md`
   - `sed -n '1,240p' orchestrator/rounds/round-088/selection.md`
   - `sed -n '1,260p' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`
   - `sed -n '1,260p' orchestrator/rounds/round-087/compatibility-fixture-gap-inventory.md`
2. Reconfirm the current code paths before editing:
   - `rg -n "planner-state\\.json|planning-state\\.json|PlanningWaitingForReadyIssues|RecordPlanningGraph|stateFileSpecs|plannerState" src test docs -g '!dist-newstyle/**'`
   - `sed -n '56,75p' src/CodexWatcher/Runtime/Compatibility.hs`
   - `sed -n '167,176p' src/CodexWatcher/Runtime/Compatibility.hs`
   - `sed -n '170,178p' src/CodexWatcher/EffectInterpreter.hs`
   - `sed -n '246,263p' src/CodexWatcher/Healthcheck.hs`
3. Add focused tests for the compatibility projection contract. Use existing
   compatibility-write test locations and helpers rather than creating a new
   test framework. The tests should assert:
   - `PlanningWaitingForReadyIssues` emits both files.
   - `planner-state.json` contains the planner summary/status shape and does
     not equal the planning graph JSON.
   - `planning-state.json` contains exactly the `PlanningGraph` JSON.
   - other relevant planner states that already write `planner-state.json`
     continue not to write `planning-state.json`.
4. Add or strengthen a focused direct-effect test for `RecordPlanningGraph` if
   the existing assertion is not explicit enough for the contract. It should
   assert that direct graph recording writes only `planning-state.json` with
   the graph payload and does not imply a `planner-state.json` summary write.
5. Add a focused healthcheck contract test or source-policy assertion matching
   current repo patterns. It should assert that issue-planning healthcheck
   state includes `planner-state.json` under the `plannerState` key and does
   not read or surface `planning-state.json`. This must be a behavior lock, not
   a behavior change.
6. Add the smallest matching docs/policy update if needed, preferably in the
   existing compatibility policy surface that already classifies
   `planning-state.json`. The text should state that `planner-state.json` and
   `planning-state.json` are distinct compatibility surfaces, that healthcheck
   currently reads only `planner-state.json`, and that fixtures/downstream
   evidence remain blockers before any future migration, reader change, rename,
   deletion, deprecation, or removal.
7. If a tiny checked-in fixture pair is added, keep it limited to the two
   selected file names and current JSON shapes. Do not add daemon, block,
   repair, runtime-owner, checked-in snapshot, or live `issue-snapshot.json`
   fixtures in this round.
8. Confirm no out-of-scope files changed. The expected implementation paths are
   focused tests, optionally one focused docs/policy file, and any strictly
   selected fixture files if justified by step 7. Do not edit
   `orchestrator/state.json`, roadmap files, healthcheck behavior, repair
   behavior, production import structure, package descriptors, or unrelated
   runtime compatibility files.
9. Do not create
   `orchestrator/rounds/round-088/worker-plan.json`. If the implementer finds
   genuinely independent ownership boundaries, stop and return to planning
   instead of writing worker instructions.

### Verification

Run focused validation first:

- `rg -n "planner-state\\.json|planning-state\\.json|PlanningWaitingForReadyIssues|RecordPlanningGraph|stateFileSpecs|plannerState" src test docs -g '!dist-newstyle/**'`
- `cabal test watcher-core-test`
- `git diff --check`
- `git status --short --untracked-files=all`

Reviewers should specifically confirm:

- Tests fail if `planner-state.json` and `planning-state.json` are collapsed,
  renamed, swapped, or treated as equivalent.
- Tests fail if healthcheck starts reading `planning-state.json` for issue
  planning without an explicit future behavior-change selection.
- `RecordPlanningGraph` remains the direct writer for
  `planning-state.json`.
- Compatibility projection still writes `planner-state.json` as summary/status
  state and `planning-state.json` as graph state for
  `PlanningWaitingForReadyIssues`.
- Any docs/policy text records blockers only and does not imply removal,
  deprecation, schema migration, reader change, repair change, or fixture
  campaign approval.
- No roadmap, controller state, package descriptor, healthcheck behavior,
  repair behavior, file deletion, or file rename change appears in the diff.

If the changed paths are artifact-only or docs-only for an implementation
revision, the implementer may justify skipping package tests only with
changed-path evidence. If tests are edited, `cabal test watcher-core-test` is
required.

### Worker Fan-Out

No worker fan-out is used. The round is serial and does not write
`worker-plan.json`.
