### Goal

Consolidate the current healthcheck runtime-state read and non-read contract
for the selected compatibility surfaces without changing healthcheck behavior.

This round should make one focused watcher-core evidence point that records the
current healthcheck mapping for `daemon-state.json`, `planner-state.json`,
`block-state.json`, and `runtime-owner.json`, plus the explicit healthcheck
non-reader boundaries for `planning-state.json`, `repair-state.json`, and live
`issue-snapshot.json`.

The round must not rename, delete, migrate, or reinterpret any runtime
compatibility file. It must not change production healthcheck behavior, repair
behavior, replay behavior, restart behavior, fixture shapes, roadmap files, or
controller state.

### Approach

Keep this as a sequential source-policy test slice. Worker fan-out is not
justified because the selected evidence is one tightly coupled healthcheck
contract over one production source file and the existing watcher-core runtime
compatibility fixture spec already owns adjacent state-file boundary checks.
Do not create `worker-plan.json`.

Add one consolidated assertion in `test/RuntimeCompatibilityFixtureSpec.hs`,
near the existing `healthcheckPlannerReaderBoundaryTest`,
`daemonStateSourceBoundaryTest`, `blockStateSourceBoundaryTest`,
`repairStateSourceBoundaryTest`, `runtimeOwnerSourceBoundaryTest`, and
`issueSnapshotSourceBoundaryTest`. The new assertion should read
`src/CodexWatcher/Healthcheck.hs` and lock the current contract in one place:

- `SIssuePlanning` uses `sharedStateFiles` with
  `("plannerState", "planner-state.json")`, so it reads
  `daemon-state.json`, `planner-state.json`, `block-state.json`, and
  `runtime-owner.json`.
- `SIssueImplement` uses `sharedStateFiles` with
  `("issueState", "issue-state.json")`, so the selected shared runtime-state
  reads remain `daemon-state.json`, `block-state.json`, and
  `runtime-owner.json`.
- `SPrReview` keeps the current PR-review state-file list, including
  `("blockedState", "block-state.json")` and
  `("runtimeOwner", "runtime-owner.json")`.
- `sharedStateFiles` keeps `("daemonState", "daemon-state.json")`,
  `("blockedState", "block-state.json")`, and
  `("runtimeOwner", "runtime-owner.json")`.
- Healthcheck source still does not mention `planning-state.json`,
  `repair-state.json`, or `issue-snapshot.json`.
- Healthcheck remains read-only for these files: it may read through the
  existing optional JSON path, but the test should continue to reject mutation
  helpers such as `writeJsonValue`.
- The current runtime-owner summary lookup remains
  `lookupStateText ["runtimeOwner", "owner"]`, and this round must not switch
  healthcheck to the lease-shaped
  `lookupStateText ["runtimeOwner", "lease", "runtime"]` path.

Do not remove the existing per-surface boundary tests. They remain useful
fixture-slice evidence from rounds 090-095; this round adds the consolidated
healthcheck contract evidence that direction 008 still lacks.

### Steps

1. Reconfirm the active round scope and current source contract before editing:
   `python3 -m json.tool orchestrator/state.json`,
   `sed -n '1,220p' orchestrator/rounds/round-096/selection.md`,
   `sed -n '1,260p' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`,
   `sed -n '240,285p' src/CodexWatcher/Healthcheck.hs`, and
   `rg -n "stateFileSpecs|sharedStateFiles|planner-state\\.json|planning-state\\.json|repair-state\\.json|issue-snapshot\\.json|runtimeOwner'|runtime-owner\\.json|block-state\\.json|daemon-state\\.json" src/CodexWatcher/Healthcheck.hs test/RuntimeCompatibilityFixtureSpec.hs test/BoundaryPolicySpec.hs`.
2. In `test/RuntimeCompatibilityFixtureSpec.hs`, add a new test function such
   as `healthcheckRuntimeStateReadNonReadContractTest :: IO Bool`.
3. Add the new test function to `runtimeCompatibilityFixtureTests` so it is
   reached by `watcher-core-test`.
4. Implement the assertion as a source-policy check against
   `src/CodexWatcher/Healthcheck.hs`, using the existing local assertion style
   and helpers such as `assert`, `sequenceAnd`, `Text.isInfixOf`, and
   `textNeedlesInOrder` where that makes ordering clearer.
5. Keep the test strict enough to fail if healthcheck starts reading
   `planning-state.json`, `repair-state.json`, or live `issue-snapshot.json`,
   or if the selected read mappings for `daemonState`, `plannerState`,
   `blockedState`, or `runtimeOwner` disappear.
6. Keep the diff out of production source, fixtures, docs, Cabal metadata,
   roadmap files, `orchestrator/state.json`, repair/replay/restart paths, and
   runtime compatibility cleanup classifications. The expected implementation
   code change is limited to `test/RuntimeCompatibilityFixtureSpec.hs`, plus
   the implementer's normal round notes.
7. In the implementation notes, record that this is current healthcheck
   contract evidence only. Do not claim fixture-batch completion, migration,
   deprecation, removal, healthcheck behavior approval, release approval, or
   milestone completion.

### Verification

Run the focused inspection first:

- `rg -n "healthcheckRuntimeStateReadNonReadContractTest|stateFileSpecs|sharedStateFiles|planner-state\\.json|planning-state\\.json|repair-state\\.json|issue-snapshot\\.json|runtimeOwner'|runtime-owner\\.json|block-state\\.json|daemon-state\\.json" test/RuntimeCompatibilityFixtureSpec.hs src/CodexWatcher/Healthcheck.hs`
- `cabal test watcher-core-test`
- `git diff --check`
- `git status --short --untracked-files=all`

Because this implementation is expected to change watcher-core test code, also
run the active roadmap baseline:

- `cabal build all`

If staging occurs, also run:

- `git diff --cached --check`

Reviewers should confirm that the final diff adds focused contract evidence
only, does not modify `src/CodexWatcher/Healthcheck.hs`, does not create
`worker-plan.json`, and does not touch roadmap/controller state except for the
role-owned round artifacts produced by the orchestrator loop.
