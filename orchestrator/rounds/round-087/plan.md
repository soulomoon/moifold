### Goal

Produce a round-local compatibility fixture gap inventory for
`round-087-compatibility-fixture-gap-inventory`.

The inventory should refresh the current evidence for planning, daemon, block,
repair, runtime-owner, checked-in snapshot, and live `issue-snapshot.json`
compatibility surfaces. It must compare producers/readers, healthcheck reader
behavior, existing golden or snapshot fixtures, docs/policy references, and
prioritized blockers for later fixture and contract rounds.

This round is artifact-only and inventory-only. It must not change production
code, test code, Cabal files, docs, fixtures, runtime compatibility files,
healthcheck behavior, repair behavior, file names, public deprecation state,
facade availability, roadmap files, or `orchestrator/state.json`.

### Approach

Use one sequential source and document scan. Worker fan-out is not justified:
the selected extraction is serial, the active state has `max_parallel_rounds:
1`, and there is only one write target,
`orchestrator/rounds/round-087/compatibility-fixture-gap-inventory.md`.

Treat `orchestrator/project-contract.md`,
`orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`,
and `orchestrator/rounds/round-087/selection.md` as authoritative. Use
`orchestrator/rounds/round-083/cleanup-inventory.md` as prior evidence, but
refresh the relevant scans at current HEAD before recording conclusions.

The inventory should classify gaps as blockers for later rounds, not as
approval for deletion, rename, deprecation, migration, Cabal exposure changes,
healthcheck reader changes, repair behavior changes, or runtime behavior
changes.

### Steps

1. Confirm active inputs and changed-path scope:
   - `git status --short --untracked-files=all`
   - `sed -n '1,220p' orchestrator/state.json`
   - `sed -n '1,240p' orchestrator/project-contract.md`
   - `sed -n '1,220p' orchestrator/rounds/round-087/selection.md`
   - `sed -n '1,260p' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`
   - `sed -n '254,320p' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`
   Record roadmap `2026-05-11-00-highest-value-cleanup`, revision `rev-001`,
   milestone `milestone-002-compatibility-fixtures-contracts`, direction
   `direction-005-compatibility-fixture-gap-inventory`, and the artifact-only
   boundary in the inventory artifact.
2. Load prior cleanup evidence:
   - `sed -n '1,360p' orchestrator/rounds/round-083/cleanup-inventory.md`
   Extract the prior runtime compatibility-file table, policy references,
   downstream/operator scope, and follow-up gates. Reuse it only as history;
   do not copy stale counts without refreshing the focused scans below.
3. Refresh producer and reader scans for the selected compatibility surfaces:
   - `rg -n "planner-state\\.json|planning-state\\.json|daemon-state\\.json|block-state\\.json|repair-state\\.json|runtime-owner\\.json|issue-snapshot\\.json|compatibilityStateWrites|writeCompatibility|stateFileSpecs|issuePlanningSnapshotPath" src app test docs scripts golden -g '!dist-newstyle/**'`
   - `rg -n "compatibilityStateWrites|writeCompatibility|RecordPlanningGraph|RecordBlocked|repair-state\\.json|repairFailureBlockStateJson|runtimeLeaseJson|readRuntimeOwner|issuePlanningSnapshotPath" src/CodexWatcher test -g '!dist-newstyle/**'`
   Record producers and readers separately for:
   `planner-state.json`, `planning-state.json`, `daemon-state.json`,
   `block-state.json`, `repair-state.json`, `runtime-owner.json`,
   checked-in compatibility snapshots, and live `issue-snapshot.json`.
4. Inspect the key source files behind those scan hits:
   - `sed -n '1,220p' src/CodexWatcher/Runtime/Compatibility.hs`
   - `sed -n '150,230p' src/CodexWatcher/EffectInterpreter.hs`
   - `sed -n '760,830p' src/CodexWatcher/Daemon.hs`
   - `sed -n '50,115p' src/CodexWatcher/Cli/Command/Replay.hs`
   - `sed -n '30,95p' src/CodexWatcher/Runtime/Owner/Store.hs`
   - `sed -n '70,105p' src/CodexWatcher/Runtime/Owner/Cli.hs`
   - `sed -n '220,255p' src/CodexWatcher/Domain/IssuePlanning/Loop.hs`
   - `sed -n '220,285p' src/CodexWatcher/Snapshot.hs`
   - `sed -n '230,285p' src/CodexWatcher/Healthcheck.hs`
   - `sed -n '130,230p' scripts/restart-watcher`
   Use these inspections to distinguish production producers, production
   readers, healthcheck readers, repair/replay effects, script/operator reads,
   and write-only outputs.
5. Refresh healthcheck reader evidence explicitly:
   - `sed -n '230,285p' src/CodexWatcher/Healthcheck.hs`
   - `rg -n "plannerState|daemonState|blockedState|runtimeOwner|planning-state\\.json|repair-state\\.json|issue-snapshot\\.json" src/CodexWatcher/Healthcheck.hs test/HealthcheckSpec.hs test/BoundaryPolicySpec.hs test/Main.hs`
   The inventory must say which selected files healthcheck reads, which
   selected files it does not currently read, and which tests or source-scan
   assertions protect that behavior.
6. Refresh checked-in fixture and snapshot evidence:
   - `find golden test docs scripts -name '*planner-state.json' -o -name '*planning-state.json' -o -name '*daemon-state.json' -o -name '*block-state.json' -o -name '*repair-state.json' -o -name '*runtime-owner.json' -o -name '*issue-snapshot.json' | sort`
   - `rg -n "golden/|fixture|snapshot|planner-state\\.json|planning-state\\.json|daemon-state\\.json|block-state\\.json|repair-state\\.json|runtime-owner\\.json|issue-snapshot\\.json" test golden docs -g '!dist-newstyle/**'`
   Record actual checked-in fixture paths, missing fixture paths, and whether
   existing tests cover old/current JSON shape, replay, bootstrap, healthcheck,
   or only source-order/write-timing evidence.
7. Refresh docs and policy references without editing them:
   - `rg -n "planner-state\\.json|planning-state\\.json|daemon-state\\.json|block-state\\.json|repair-state\\.json|runtime-owner\\.json|issue-snapshot\\.json|compatibility fixture|compatibility files|healthcheck|repair" orchestrator/project-contract.md docs README.md scripts orchestrator/rounds/round-083/cleanup-inventory.md docs/agentic-workflow-framework/compatibility-deprecation-policy.md`
   Record policy references that matter for later rounds, especially the
   distinct `planner-state.json` versus `planning-state.json` contract,
   runtime compatibility-file preservation, healthcheck/repair/operator gates,
   and the rule that preferred imports or missing local users are not removal
   approval.
8. Write
   `orchestrator/rounds/round-087/compatibility-fixture-gap-inventory.md` with:
   - scope, roadmap lineage, and non-goals;
   - a per-surface table for each selected compatibility surface;
   - producers, readers, healthcheck reader status, repair/replay/script
     interactions, existing tests, existing checked-in fixtures, docs/policy
     references, and current fixture gaps;
   - prioritized blockers for later rounds, grouped by immediate fixture
     blocker, healthcheck contract blocker, planner/planning contract blocker,
     operator/downstream inventory blocker, and removal/migration blocker;
   - explicit confirmation that the round made no production, test, Cabal,
     docs, fixture, healthcheck, repair, runtime behavior, file-name,
     roadmap/state, deprecation, or removal changes.
9. Do not create `orchestrator/rounds/round-087/worker-plan.json`. If the
   implementer believes fan-out has become necessary, stop and return to
   planning with a concrete non-overlapping ownership proposal instead of
   writing worker instructions.

### Verification

Because this is an artifact-only inventory round, first verify changed-path
scope:

- `test -f orchestrator/rounds/round-087/compatibility-fixture-gap-inventory.md`
- `test ! -e orchestrator/rounds/round-087/worker-plan.json`
- `git diff --name-only`
- `git diff -- orchestrator/rounds/round-087/plan.md orchestrator/rounds/round-087/compatibility-fixture-gap-inventory.md`
- `git diff --check`
- `git status --short --untracked-files=all`

The implementer should rerun the focused scan commands from the steps and make
sure the inventory artifact records the relevant results. Package build/test
baselines are not required if the only changed files are the round-local plan
and inventory artifacts. If any production code, test code, Cabal descriptor,
docs, fixture, runtime compatibility file, public API, healthcheck behavior, or
repair behavior changes appear in `git diff --name-only`, stop and return to
planning or review instead of treating the artifact-only exception as valid.

Reviewers should specifically confirm:

- The inventory covers planning, daemon, block, repair, runtime-owner,
  checked-in snapshots, and live `issue-snapshot.json` surfaces.
- `planner-state.json` and `planning-state.json` are treated as distinct
  compatibility surfaces.
- Healthcheck reader evidence is source-backed and does not imply a behavior
  change.
- Missing fixtures are recorded as blockers for later fixture rounds, not as
  approval to remove or rename files.
- No production code, test code, Cabal files, docs, fixtures, runtime
  compatibility files, roadmap files, `orchestrator/state.json`,
  healthcheck behavior, repair behavior, file names, deprecation state, or
  compatibility surface availability changed.

### Worker Fan-Out

No worker fan-out is used. This selected extraction is serial, has one
round-local inventory write target, and shares the same source/document scan
context across all selected surfaces. Do not write `worker-plan.json`.
