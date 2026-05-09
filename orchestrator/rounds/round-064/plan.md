### Goal

Record source-backed evidence for the current `planning-state.json`
compatibility projection so later cleanup, migration, schema, timing, or
removal rounds know exactly which gates remain blocked.

This round must preserve the project-contract compatibility promises for
runtime compatibility files. It must not change the filename, schema, event
`type` fields, write timing, healthcheck behavior, repair behavior, or
compatibility projection behavior.

### Approach

Keep the round serial and evidence-only. The implementation should add a
round-local evidence artifact for `planning-state.json`, then update the
existing compatibility policy only if needed to point to the new evidence and
spell out the current non-healthcheck policy. Do not add a checked-in fixture
unless the implementer can prove an existing fixture location and old/current
shape contract without changing production behavior; otherwise record the
fixture gap as a blocker.

The evidence should distinguish the two current producer paths:

- direct `RecordPlanningGraph` compilation to
  `<stateDir>/planning-state.json` in `src/CodexWatcher/EffectInterpreter.hs`;
- compatibility projection from `PlanningWaitingForReadyIssues` in
  `src/CodexWatcher/Runtime/Compatibility.hs`, including daemon/fanout paths
  that write compatibility output after replay/projection.

It should also read back the current healthcheck state-file list in
`src/CodexWatcher/Healthcheck.hs`: issue-planning healthcheck reads
`planner-state.json` and shared `daemon-state.json`, `block-state.json`, and
`runtime-owner.json`, but not `planning-state.json`. Treat that as an explicit
current non-healthcheck policy for this write-only projection, not as approval
to remove or redesign anything.

No worker fan-out is justified. This is one compatibility surface with tightly
coupled source, test, docs, and prior-round evidence, and parallel workers
would mostly duplicate scans.

### Steps

1. Reconfirm the round boundaries from `orchestrator/rounds/round-064/selection.md`,
   `orchestrator/project-contract.md`, and the active verification contract.
   Keep all changes limited to evidence/policy documentation and the selected
   round artifacts; do not edit production code, tests, schemas, fixtures, or
   controller state.

2. Create a round-local evidence artifact, for example
   `orchestrator/rounds/round-064/planning-state-fixture-policy.md`, with the
   following sections:
   - scope and explicit non-goals;
   - producer readback;
   - healthcheck state-file readback and current non-healthcheck policy;
   - existing fixture/test coverage;
   - blockers before later cleanup, migration, schema, timing, or removal.

3. In the producer readback section, cite the current source paths and behavior:
   - `EffectInterpreter.compileEffectPlan` compiles `RecordPlanningGraph` to a
     `PlannedWriteJson` at `runtimeStateDirFile ... "planning-state.json"`;
   - `Runtime.Compatibility.compatibilityStateWrites` emits
     `planning-state.json` only for `PlanningWaitingForReadyIssues`;
   - `AutomaticLoop.IssuePlanningFanout` writes compatibility projection output
     after appending projected events for ready-issue maintenance paths.
   Record that the file value is the `PlanningGraph` JSON, and do not propose a
   schema or timing change.

4. In the healthcheck section, cite `Healthcheck.stateFileSpecs` and
   `sharedStateFiles`. Record that issue-planning healthcheck currently reads
   `planner-state.json`, `daemon-state.json`, `block-state.json`, and
   `runtime-owner.json`, and that no healthcheck state-file spec reads
   `planning-state.json`. State the policy explicitly: this round preserves the
   current non-healthcheck status because the file is a write-only compatibility
   projection, and any future healthcheck surfacing would need its own selected
   behavior-change round.

5. In the fixture/test coverage section, rerun the fixture search and record
   the result. If no checked-in `planning-state.json` exists, say so directly.
   Then cite the existing protecting tests instead of inventing fixture
   coverage:
   - `prop_effectInterpreterRecordPlanningGraphWritesState` for direct planned
     writes;
   - automatic daemon graph-update coverage that asserts
     `planning-state.json` writes;
   - canonical planning graph coverage that asserts normalized graph writes;
   - indexed issue-planning daemon parity that asserts compatibility writes
     include the planning graph.

6. In the blockers section, preserve the conservative `defer` classification.
   Name the blockers before any later deprecation, migration, cleanup, timing,
   schema, or removal decision:
   - no checked-in old/current `planning-state.json` state-file fixture;
   - no external operator/downstream direct-reader inventory;
   - no reviewed behavior-change selection for healthcheck surfacing;
   - no migration/removal approval in the active roadmap milestone.

7. Update `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`
   only if the new round evidence needs to be referenced from the durable
   policy. If updated, keep the `planning-state.json` classification as
   `defer`, cite round 064 as additional evidence, and avoid wording that
   implies deprecation, migration, removal, release approval, or package
   publication.

8. Write implementation notes that list the exact files changed, the scans
   run, and the current result. The notes should state that no production
   source, tests, fixtures, schemas, roadmap files, controller state, or runtime
   behavior changed.

### Verification

Required readback/scans:

```sh
find . -name 'planning-state.json' -print
rg -n "planning-state\\.json|RecordPlanningGraph|PlanningWaitingForReadyIssues|compatibilityStateWrites|stateFileSpecs|sharedStateFiles" src/CodexWatcher/EffectInterpreter.hs src/CodexWatcher/Runtime/Compatibility.hs src/CodexWatcher/AutomaticLoop/IssuePlanningFanout.hs src/CodexWatcher/Healthcheck.hs test/Main.hs docs/agentic-workflow-framework/compatibility-deprecation-policy.md orchestrator/rounds/round-064
rg -n "planning-state\\.json|defer|non-healthcheck|healthcheck|fixture|external operator|downstream|removal|migration" docs/agentic-workflow-framework/compatibility-deprecation-policy.md orchestrator/rounds/round-064
git diff --name-only
git diff --check
```

If the implementation remains artifact/docs-only, Cabal/package baselines may
be skipped under the verification contract's artifact-only allowance, but the
reviewer should still require the baseline if the diff escapes the selected
round artifact and optional policy-doc update:

```sh
cabal build all
cabal test watcher-core-test
scripts/validate-workflow-packages.sh
```

When staging is involved, also run:

```sh
git diff --cached --check
```
