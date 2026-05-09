### Goal

Record current evidence for repair-failure `block-state.json` compatibility
behavior: repair-failure output shape, direct blocked writes, compatibility
projection writes, healthcheck readback, stale-block cleanup behavior, existing
fixture/test coverage, and blockers before any later cleanup, migration,
schema, timing, healthcheck, repair, projection, stale-cleanup, or removal
decision.

This is an evidence-only round for
`direction-018-block-state-repair-failure-fixture` under
`milestone-006-runtime-compatibility-follow-up-evidence`. It must preserve
runtime compatibility-file behavior and must not change filenames, schemas,
event JSON `type` fields, write timing, repair behavior, healthcheck behavior,
compatibility projection behavior, stale-block cleanup behavior, production
source, tests, fixtures, scripts, roadmap files, controller state, package
metadata, deprecation status, removal approval, publication, upload, or release
approval.

### Approach

Keep this as a sequential evidence-only round. Use
`orchestrator/project-contract.md` for stable compatibility invariants and the
active verification contract for baseline expectations. Do not write
`worker-plan.json`: this is one coupled compatibility surface, and the current
runner, effect interpreter, compatibility projection, healthcheck readback,
repair cleanup, restart cleanup, fixture gap, and blocker evidence overlap too
much for useful worker fan-out.

The implementer should create one round-local evidence artifact, expected as
`orchestrator/rounds/round-069/block-state-repair-failure-evidence.md`, plus
round-local implementation notes if the implementer normally records them. The
artifact should be source-backed and conservative. If a checked-in
repair-failure `block-state.json` fixture is still absent, record the exact
fixture gap and source-derived JSON shape; do not add fixture files or tests
unless a later reviewed plan explicitly authorizes non-round-local writes.

### Steps

1. Re-read the active round/control inputs before editing:
   `orchestrator/rounds/round-069/selection.md`,
   `orchestrator/project-contract.md`, and
   `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/verification.md`.
   Confirm the round remains evidence-only under
   `direction-018-block-state-repair-failure-fixture`.

2. Refresh prior evidence from rounds 053, 055, 057, 058, 065, 067, and 068,
   plus `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`.
   Treat the baseline as: `block-state.json` is currently classified `keep`;
   direct `RecordBlocked` writes, compatibility projection writes,
   healthcheck readback, snapshot/golden readback, successful-repair stale
   cleanup, and restart cleanup already exist; the missing checked-in
   repair-failure fixture and external operator/downstream inventory remain
   blockers.

3. Inspect `src/CodexWatcher/AutomaticLoop/Runner.hs`. Record that
   `recordInvalidReplayBlockState` writes
   `<stateDir>/block-state.json` only for
   `DaemonLoopDaemonFailure (DaemonReplayFailed replayFailure)`, creates the
   state directory first, writes `repairFailureBlockStateJson replayFailure`,
   and then the loop dies from the replay failure. Record this as
   repair-failure runner behavior, not normal blocked-state behavior.

4. Inspect `src/CodexWatcher/EventLogRepair.hs`. Record the current
   repair-failure JSON shape exactly:
   `blocked = true`, `blockedKind = "invalid_event_log"`, `reason`,
   `eventIndex`, `eventType`, and embedded `event`. Keep this distinct from
   the simple normal blocked shape. Do not propose changing field names,
   event serialization, event `type` fields, or failure classification.

5. Inspect `src/CodexWatcher/Runtime/BlockedState.hs`,
   `src/CodexWatcher/EffectInterpreter.hs`, and
   `src/CodexWatcher/Runtime/Compatibility.hs`. Record that normal direct
   `RecordBlocked` compilation and `compatibilityStateWrites` for
   `BlockedState` both write `block-state.json` using `blockedStateJson`, whose
   current shape is `blocked = true` and `reason`. Record that this shape is
   intentionally different from repair-failure block state.

6. Inspect healthcheck behavior in `src/CodexWatcher/Healthcheck.hs`,
   especially `summarizeLoadedItem`, `readStateFiles`, `stateFileSpecs`, and
   `sharedStateFiles`. Record that issue planning, issue implementation, and
   PR review healthcheck all read `blockedState` from `block-state.json`, and
   summaries surface `blocked` from `blockedState.blocked` and
   `blockedReason` from `blockedState.reason`. Record the compatibility
   consequence: repair-failure files have `blocked = true` and `reason`, so
   the current healthcheck path can surface the failure as blocked while
   retaining the extra repair-failure fields in raw `states`.

7. Inspect snapshot and golden replay readers in
   `src/CodexWatcher/Snapshot.hs` and `src/CodexWatcher/GoldenReplay.hs`.
   Record that PR review and issue implementation snapshots decode optional
   `block-state.json`, and golden replay/bootstrap treats any decoded
   `blocked = true` with optional `reason` as a blocked watcher state. Do not
   claim this proves repair-failure fixture coverage unless a checked-in
   repair-failure fixture exists.

8. Inspect successful-repair stale-block cleanup in
   `src/CodexWatcher/Cli/Command/Replay.hs`. Record the execute order:
   archive invalid log, write repaired `events.jsonl`, write
   `repair-state.json`, rewrite compatibility files from the repaired replay
   state, then `removeFileIfExists (options.repairCliStateDir </> "block-state.json")`.
   Keep this as successful repair cleanup evidence; do not move or change the
   stale-block cleanup behavior.

9. Inspect restart cleanup in `scripts/restart-watcher`. Record that
   `cleanup_state` removes `$state_dir/block-state.json` together with pid
   files, `runtime-owner.json`, `daemon-state.json`, and
   `stale-active-turn.json`. Treat this as operator-script cleanup evidence
   only; do not modify the script.

10. Run focused fixture and source inventories for `block-state.json`,
    `repairFailureBlockStateJson`, `recordInvalidReplayBlockState`,
    `blockedStateJson`, `RecordBlocked`, `compatibilityStateWrites`,
    `blockedState`, `removeFileIfExists`, `cleanup_state`, healthcheck, and
    golden replay across `src`, `app`, `test`, `scripts`, `docs`, `golden`,
    and relevant prior round artifacts. Separate production writers,
    production readers, tests, fixtures, scripts, docs/runbooks, and prior
    evidence artifacts.

11. Search checked-in fixtures explicitly. At minimum, run:
    `find golden -name 'block-state.json' -o -name '*block*' | sort`.
    Record the known normal blocked fixture
    `golden/pr-review/mlf2-pr6-blocked/block-state.json` and any blocked
    event-log fixture directories found. If no repair-failure
    `block-state.json` fixture exists, record that as the selected fixture
    gap and do not fill it in this planner-only/evidence-only scope.

12. Inspect existing tests in `test/Main.hs` and `test/HealthcheckSpec.hs`.
    Record current coverage narrowly: direct `RecordBlocked` planned-write
    shape, repair CLI source-order stale-block cleanup assertion, healthcheck
    state-file list/source behavior, golden replay/bootstrap blocked
    readback, and blocked transition effects. Do not describe these as
    repair-failure fixture coverage unless a test actually validates
    `repairFailureBlockStateJson` output from the runner path.

13. Create the round-local evidence artifact with sections for scope and
    non-goals, repair-failure runner write path, repair-failure JSON shape,
    normal direct blocked write shape, compatibility projection write shape,
    healthcheck readback, snapshot/golden readback, successful repair
    stale-block cleanup, restart cleanup, fixture inventory, existing test
    coverage, current classification, and blockers.

14. Keep blockers conservative. At minimum, retain missing checked-in
    repair-failure `block-state.json` fixture or runner round-trip coverage,
    missing external operator/downstream direct-reader inventory, no selected
    approval for filename/schema/event-type/write-timing/healthcheck/repair/
    projection/stale-cleanup behavior changes, and no migration,
    deprecation, removal, publication, upload, or release approval.

15. If implementation notes are written, include changed files, exact scans
    run, fixture-search results, any skipped baseline rationale, and a
    statement that no production behavior changed.

### Verification

Use focused readback commands first:

```sh
sed -n '1,220p' orchestrator/rounds/round-069/selection.md
sed -n '1,260p' orchestrator/project-contract.md
sed -n '1,320p' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/verification.md
sed -n '170,190p' src/CodexWatcher/AutomaticLoop/Runner.hs
sed -n '220,245p' src/CodexWatcher/EventLogRepair.hs
sed -n '1,40p' src/CodexWatcher/Runtime/BlockedState.hs
sed -n '168,180p' src/CodexWatcher/EffectInterpreter.hs
sed -n '145,155p' src/CodexWatcher/Runtime/Compatibility.hs
sed -n '200,285p' src/CodexWatcher/Healthcheck.hs
sed -n '220,252p' src/CodexWatcher/Snapshot.hs
sed -n '75,90p' src/CodexWatcher/GoldenReplay.hs
sed -n '52,64p' src/CodexWatcher/Cli/Command/Replay.hs
sed -n '215,230p' scripts/restart-watcher
```

Run focused scans and record results:

```sh
find golden -name 'block-state.json' -o -name '*block*' | sort
rg -n "block-state\\.json|repairFailureBlockStateJson|recordInvalidReplayBlockState|blockedStateJson|RecordBlocked|compatibilityStateWrites|blockedState|removeFileIfExists|cleanup_state" src app test scripts docs golden orchestrator/rounds/round-053 orchestrator/rounds/round-055 orchestrator/rounds/round-057 orchestrator/rounds/round-058 orchestrator/rounds/round-065 orchestrator/rounds/round-067 orchestrator/rounds/round-068
rg -n "stateFileSpecs|sharedStateFiles|readStateFiles|blockedState|blockedReason|repair-failure|invalid_event_log" src/CodexWatcher/Healthcheck.hs src/CodexWatcher/EventLogRepair.hs src/CodexWatcher/AutomaticLoop/Runner.hs test/Main.hs test/HealthcheckSpec.hs docs/agentic-workflow-framework/compatibility-deprecation-policy.md orchestrator/rounds/round-069
rg -n "block-state\\.json|keep|fixture|external operator|downstream|repair failure|repair-failure|stale-block|cleanup|removal|migration" docs/agentic-workflow-framework/compatibility-deprecation-policy.md orchestrator/rounds/round-053 orchestrator/rounds/round-055 orchestrator/rounds/round-057 orchestrator/rounds/round-058 orchestrator/rounds/round-065 orchestrator/rounds/round-067 orchestrator/rounds/round-068 orchestrator/rounds/round-069
```

Validate the artifact-only diff:

```sh
git status --short --branch
git diff --name-only
git diff --check
rg -n "[ \t]+$" orchestrator/rounds/round-069
```

If the diff remains limited to round-local orchestrator evidence artifacts,
the Cabal and package baselines may be skipped under the active verification
contract. If production source, tests, fixtures, scripts, docs, roadmap files,
package files, or controller state change, the implementer must stop and
either narrow the diff back to the selected evidence scope or run the full
baseline from `verification.md`:

```sh
cabal build all
cabal test watcher-core-test
scripts/validate-workflow-packages.sh
git diff --check
```
