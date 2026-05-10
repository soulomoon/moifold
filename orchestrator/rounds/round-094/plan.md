### Goal

Add focused checked-in fixture coverage and watcher-core assertions for the
current `runtime-owner.json` lease shape.

This round covers the next `direction-007-runtime-compatibility-fixtures`
blocker from the round-087 inventory: `runtime-owner.json` has a current
lease-shaped producer, runtime-owner readers, healthcheck visibility, and
restart-script pid/cleanup assumptions, but no checked-in runtime-owner
compatibility fixture. The implementation must preserve the current filename,
top-level `lease` schema, runtime-owner parser behavior, healthcheck
`runtimeOwner` state-file mapping, current healthcheck summary field path,
restart-script `"pid"` extraction assumption, and cleanup behavior. It must
not change runtime-owner production, healthcheck behavior, script behavior,
repair behavior, runtime behavior, schema, migration, deprecation, removal,
roadmap files, or controller state.

### Approach

Use one serial implementation pass. Worker fan-out is not justified because
the selected fixture, runtime-owner reader assertions, healthcheck/source
boundary assertions, restart-script source boundary assertions, and existing
watcher-core fixture module all protect one tightly coupled compatibility
surface.

Extend the existing runtime-compatibility fixture namespace with one
runtime-owner fixture, keeping it separate from full golden snapshot
directories so it is not mistaken for snapshot replay input:

- `golden/runtime-compatibility/runtime-owner/current-lease/runtime-owner.json`

Use a deterministic lease whose JSON exactly matches
`runtimeLeaseJson fixtureRuntimeLease`:

```json
{
  "lease": {
    "runtime": "haskell",
    "pid": "123456",
    "hostname": "runtime-fixture-host",
    "claimedAt": "2026-01-01T00:00:00Z",
    "expiresAt": "2026-01-01T01:00:00Z",
    "eventLogHeadHash": "fixture-head"
  }
}
```

Add assertions to `test/RuntimeCompatibilityFixtureSpec.hs`, which is already
listed in `moifold.cabal` and already called from `test/Main.hs`. Do not create
a new test module or change Cabal/Main wiring unless the implementation branch
has unexpectedly diverged from the observed round-090 through round-093 state.
The expected implementation paths are the new fixture file,
`test/RuntimeCompatibilityFixtureSpec.hs`, and the implementer's
`orchestrator/rounds/round-094/implementation-notes.md`.

### Steps

1. Reconfirm current scope and inputs before editing:
   - `git status --short --untracked-files=all`
   - `python3 -m json.tool orchestrator/state.json`
   - `sed -n '1,220p' orchestrator/rounds/round-094/selection.md`
   - `sed -n '1,280p' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`
   - `sed -n '1,240p' orchestrator/project-contract.md`
   - `sed -n '1,170p' orchestrator/rounds/round-087/compatibility-fixture-gap-inventory.md`
   - `sed -n '1,140p' orchestrator/rounds/round-089/plan.md`
2. Reconfirm the current runtime-owner producer, readers, healthcheck mapping,
   and restart-script assumptions before editing:
   - `rg -n "runtime-owner\\.json|runtimeOwner|runtimeLeaseJson|readRuntimeOwner|readRuntimeOwnerMarker|writeRuntimeLease|read_runtime_owner_pid|stateFileSpecs" src app test docs scripts golden -g '!dist-newstyle/**'`
   - inspect `src/CodexWatcher/Runtime/Owner/Store.hs` around
     `runtimeLeaseJson`, `writeRuntimeLease`, `readRuntimeOwner`, and
     `readRuntimeOwnerMarker`;
   - inspect `src/CodexWatcher/Runtime/Owner/Cli.hs`,
     `src/CodexWatcher/AutomaticLoop/Runner.hs`,
     `src/CodexWatcher/Domain/PrReview/LaunchCli.hs`, and
     `src/CodexWatcher/Cli/Command/Observe.hs` enough to confirm the current
     runtime-owner reader/writer paths;
   - inspect `src/CodexWatcher/Healthcheck.hs` to confirm
     `("runtimeOwner", "runtime-owner.json")` remains present for issue
     planning, issue implementation, and PR review, and that the summary
     lookup still uses `["runtimeOwner", "owner"]`;
   - inspect `scripts/restart-watcher` around `read_runtime_owner_pid`,
     `pid_from_owner`, and `cleanup_state`.
3. Add the fixture file listed in the Approach section. Keep JSON formatting
   deterministic and keep the fixture path limited to
   `golden/runtime-compatibility/runtime-owner/...`.
4. Extend `runtimeCompatibilityFixtureTests` with a runtime-owner fixture
   group. Keep the existing planner/planning, daemon-state, block-state, and
   repair-state tests intact.
5. In the runtime-owner fixture group, load the fixture as `Value` with
   `eitherDecodeStrict'` and assert exact equality with
   `runtimeLeaseJson fixtureRuntimeLease`. Define `fixtureRuntimeLease` in the
   test module with deterministic owner, pid, hostname, claimed/expires times,
   and event-log head hash matching the fixture JSON.
6. Assert the fixture keeps the current exact lease shape:
   - top-level object contains `lease`;
   - top-level object does not contain `owner`, `runtime`, `pid`, `hostname`,
     `claimedAt`, `expiresAt`, or `eventLogHeadHash`;
   - nested `lease.runtime` is `"haskell"`;
   - nested `lease.pid` is `"123456"`;
   - nested `lease.hostname` is `"runtime-fixture-host"`;
   - nested `lease.claimedAt` and `lease.expiresAt` match the deterministic
     fixture times;
   - nested `lease.eventLogHeadHash` is `"fixture-head"`.
7. Add a fixture-backed reader assertion without changing production parser
   internals: write the checked-in fixture value to a throwaway
   `/tmp/moifold-runtime-owner-fixture-test/runtime-owner.json`, then assert
   `readRuntimeOwnerMarker` returns `Right (Just (RuntimeOwnerLeased lease))`
   with the deterministic lease fields and `readRuntimeOwner` returns
   `Right (Just HaskellRuntime)`. Clean the throwaway directory before and
   after the test.
8. Preserve the existing legacy-shape rejection coverage from `test/Main.hs`.
   Do not add an old-shape fixture in this round unless the implementer finds
   that the current checked-in fixture cannot protect the parser boundary
   without it; if that happens, record the reason in implementation notes and
   keep any extra fixture under the runtime-owner namespace only.
9. Add or extend focused source-boundary assertions for the current
   healthcheck and restart-script contracts:
   - `Healthcheck.hs` still maps `runtime-owner.json` through
     `("runtimeOwner", "runtime-owner.json")` for the relevant domain state
     specs;
   - the healthcheck summary owner lookup remains
     `config.runtimeOwner <|> lookupStateText ["runtimeOwner", "owner"] states`;
   - healthcheck does not switch this round to
     `lookupStateText ["runtimeOwner", "lease", "runtime"]`;
   - `scripts/restart-watcher` still reads
     `$state_dir/runtime-owner.json`, extracts the first string `"pid"` value,
     assigns `pid_from_owner=$(read_runtime_owner_pid)`, stops that pid, and
     removes `$state_dir/runtime-owner.json` during cleanup.
10. Inspect the final diff and keep it inside the selected implementation
    surface. Do not edit `orchestrator/state.json`, roadmap files, production
    behavior, docs/policy files unless strictly needed for implementation
    notes, healthcheck behavior, script behavior, repair behavior, runtime
    owner producer code, compatibility file names, Cabal exposure, public
    facades, or unrelated fixtures.

### Verification

Run the focused checks first:

- `find golden/runtime-compatibility/runtime-owner -type f | sort`
- `python3 -m json.tool golden/runtime-compatibility/runtime-owner/current-lease/runtime-owner.json`
- `rg -n "runtime-owner\\.json|runtimeOwner|runtimeLeaseJson|readRuntimeOwnerMarker|readRuntimeOwner|read_runtime_owner_pid|RuntimeCompatibilityFixtureSpec|runtimeCompatibilityFixtureTests|stateFileSpecs" golden test src app scripts docs -g '!dist-newstyle/**'`
- `cabal test watcher-core-test`
- `git diff --check`
- `git status --short --untracked-files=all`

Run the roadmap baseline because tests and fixtures are expected to change:

- `cabal build all`

If staging occurs, also run:

- `git diff --cached --check`

Reviewers should specifically confirm:

- the fixture file is checked in at the expected
  `golden/runtime-compatibility/runtime-owner/current-lease/runtime-owner.json`
  path;
- fixture tests would fail if the current runtime-owner JSON stops using a
  top-level `lease`, gains top-level owner/runtime/pid fields, or loses any
  nested lease field;
- `readRuntimeOwnerMarker` and `readRuntimeOwner` accept the checked-in fixture
  as the current lease shape;
- healthcheck still reads the same `runtime-owner.json` state files and keeps
  the current `["runtimeOwner", "owner"]` summary path rather than silently
  switching to the nested lease path;
- `scripts/restart-watcher` still parses the first `"pid"` string from
  `runtime-owner.json`, stops it, and removes the file during cleanup;
- no checked-in snapshot, live `issue-snapshot.json`, healthcheck behavior
  change, script behavior change, repair behavior change, runtime behavior
  change, docs/policy expansion, roadmap edit, controller-state edit, rename,
  deletion, migration, deprecation, or removal work escaped into this round.
