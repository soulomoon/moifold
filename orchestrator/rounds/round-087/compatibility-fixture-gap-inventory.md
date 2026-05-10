## Scope

Round: `round-087-compatibility-fixture-gap-inventory`
Roadmap: `2026-05-11-00-highest-value-cleanup`, revision `rev-001`
Milestone: `milestone-002-compatibility-fixtures-contracts`
Direction: `direction-005-compatibility-fixture-gap-inventory`

This is a round-local inventory artifact only. It refreshes current evidence
for planning, daemon, block, repair, runtime-owner, checked-in compatibility
snapshots, and live `issue-snapshot.json` compatibility surfaces.

## Non-Goals

- No production code, tests, Cabal files, docs, fixtures, runtime
  compatibility files, roadmap files, or `orchestrator/state.json` were changed.
- No file is approved for deletion, rename, deprecation, migration, Cabal
  exposure changes, healthcheck behavior changes, repair behavior changes, or
  runtime behavior changes.
- Missing fixtures, missing readers, or missing local downstream users are
  blockers for later rounds, not removal evidence.

## Scans Run

- `git status --short --untracked-files=all`
- `sed -n '1,220p' orchestrator/state.json`
- `sed -n '1,240p' orchestrator/project-contract.md`
- `sed -n '1,220p' orchestrator/rounds/round-087/selection.md`
- `sed -n '1,260p' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`
- `sed -n '254,320p' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`
- `sed -n '1,360p' orchestrator/rounds/round-083/cleanup-inventory.md`
- `rg -n "planner-state\\.json|planning-state\\.json|daemon-state\\.json|block-state\\.json|repair-state\\.json|runtime-owner\\.json|issue-snapshot\\.json|compatibilityStateWrites|writeCompatibility|stateFileSpecs|issuePlanningSnapshotPath" src app test docs scripts golden -g '!dist-newstyle/**'`
- `rg -n "compatibilityStateWrites|writeCompatibility|RecordPlanningGraph|RecordBlocked|repair-state\\.json|repairFailureBlockStateJson|runtimeLeaseJson|readRuntimeOwner|issuePlanningSnapshotPath" src/CodexWatcher test -g '!dist-newstyle/**'`
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
- `rg -n "plannerState|daemonState|blockedState|runtimeOwner|planning-state\\.json|repair-state\\.json|issue-snapshot\\.json" src/CodexWatcher/Healthcheck.hs test/HealthcheckSpec.hs test/BoundaryPolicySpec.hs test/Main.hs`
- `find golden test docs scripts \( -name '*planner-state.json' -o -name '*planning-state.json' -o -name '*daemon-state.json' -o -name '*block-state.json' -o -name '*repair-state.json' -o -name '*runtime-owner.json' -o -name '*issue-snapshot.json' \) | sort`
- `rg -n "golden/|fixture|snapshot|planner-state\\.json|planning-state\\.json|daemon-state\\.json|block-state\\.json|repair-state\\.json|runtime-owner\\.json|issue-snapshot\\.json" test golden docs -g '!dist-newstyle/**'`
- `rg -n "planner-state\\.json|planning-state\\.json|daemon-state\\.json|block-state\\.json|repair-state\\.json|runtime-owner\\.json|issue-snapshot\\.json|compatibility fixture|compatibility files|healthcheck|repair" orchestrator/project-contract.md docs README.md scripts orchestrator/rounds/round-083/cleanup-inventory.md docs/agentic-workflow-framework/compatibility-deprecation-policy.md`

## Per-Surface Inventory

| Surface | Producers | Readers | Healthcheck status | Repair/replay/script interactions | Existing tests | Checked-in fixtures | Policy/docs references | Fixture gaps |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `planner-state.json` | `src/CodexWatcher/Runtime/Compatibility.hs` writes `ready`, `active`, `waiting_ready_issues`, and `complete` planning summaries through `compatibilityStateWrites`. Launch/replay paths call those writes through `writeCompatibility`. | Focused scan found `src/CodexWatcher/Healthcheck.hs` as the production Haskell reader. | Read for `SIssuePlanning` as key `plannerState`; not the same surface as `planning-state.json`. Source scan also found policy tests checking healthcheck state-file names. | Repair can rewrite it indirectly through `writeCompatibilityFiles` over repaired replay state. No direct replay input reader found. | `test/Main.hs`, `test/WorkflowIndexedSpec.hs`, and `test/BoundaryPolicySpec.hs` contain compatibility write/source assertions around planning state behavior and policy strings. | None found by the checked-in file-name scan. | `orchestrator/project-contract.md` explicitly keeps `planner-state.json` distinct from `planning-state.json`; active roadmap verification repeats this contract. | Add old/current fixtures and explicit contract tests for producer shapes, healthcheck reader behavior, write timing, and external reader assumptions. |
| `planning-state.json` | `src/CodexWatcher/Runtime/Compatibility.hs` writes it for `PlanningWaitingForReadyIssues`; `src/CodexWatcher/EffectInterpreter.hs` writes it for `RecordPlanningGraph`. | No production Haskell reader found in the focused scan. Tests and source scans mention expected write paths. | Not read by `stateFileSpecs`; current healthcheck reads `planner-state.json` for issue planning, not `planning-state.json`. | Repair can emit it through repaired replay compatibility writes. No direct repair/replay input reader found. | `test/Main.hs` checks direct graph writes, canonical planning graph writes, and issue-planning snapshot timing; `test/WorkflowIndexedSpec.hs` checks indexed compatibility writes; `test/BoundaryPolicySpec.hs` has source/policy assertions. | None found. | Project contract and roadmap verification require an explicit reviewed `planner-state.json` versus `planning-state.json` contract before rename, deletion, or reader changes. Compatibility deprecation policy marks this deferred. | Add file fixtures for direct graph and compatibility-projection shapes; record explicit non-healthcheck contract and external/downstream reader inventory. |
| `daemon-state.json` | `Runtime.Compatibility` writes idle, active, stopped, and workflow summaries. `src/CodexWatcher/Daemon.hs`, launch paths, fanout, startup, PR-review launch, and repair rewrite paths use `compatibilityStateWrites` / `writeCompatibility`. | `src/CodexWatcher/Snapshot.hs` reads optional daemon state for issue-implementation snapshots. Healthcheck reads it as shared state. | Read by shared state specs for issue planning and issue implementation as `daemonState`; not read for PR review state specs. | `repair-invalid-state --execute` rewrites daemon state from the repaired replay state. `scripts/restart-watcher` removes it during cleanup. | `test/Main.hs` covers launch compatibility writes, golden snapshot replay/bootstrap, repair ordering, and source ordering; `test/BoundaryPolicySpec.hs` checks healthcheck source strings. | `golden/issue-implement/mlf2-issue42-incomplete/daemon-state.json`. | Compatibility deprecation policy keeps it and calls out missing active/stopped daemon fixtures plus direct-reader inventory. | Add active and stopped daemon fixtures and reader inventory before any runtime cleanup decision. |
| `block-state.json` | `EffectInterpreter` writes it for `RecordBlocked`; `Runtime.Compatibility` writes it for `BlockedState`; `AutomaticLoop.Runner` writes repair-failure block state through `repairFailureBlockStateJson`. | `Snapshot.hs` reads optional block state for PR-review and issue-implementation snapshots. Healthcheck reads it for issue planning, issue implementation, and PR review. | Read as `blockedState` for all selected domain state specs. | Repair execute removes stale `block-state.json` after compatibility rewrite. `scripts/restart-watcher` removes it and can drop blocked-tail events. | `test/Main.hs`, `test/WorkflowIndexedSpec.hs`, and `test/WorkflowExecutionSpec.hs` cover `RecordBlocked`, blocked effect plans, compatibility writes, healthcheck strings, and repair ordering. | `golden/pr-review/mlf2-pr6-blocked/block-state.json`; `golden/pr-review/mlf2-pr6-merged/config.json` references a blocked-state path. | Compatibility deprecation policy keeps it as an operator contract and calls out missing repair-failure fixture coverage. | Add checked-in repair-failure block-state JSON fixture and external/operator direct-reader inventory. |
| `repair-state.json` | `src/CodexWatcher/Cli/Command/Replay.hs` writes it only during `repair-invalid-state --execute` after archiving the invalid event log and rewriting `events.jsonl`, before compatibility rewrite and stale block removal. | No production Haskell reader found. | Not read by healthcheck. The healthcheck scan only surfaced negative/policy mentions in tests. | It is repair command output evidence, not an input to repair/replay in the focused source. | `test/Main.hs` protects repair dry-run/execute source ordering and stale block removal ordering. | None found. | Compatibility deprecation policy defers it and records missing round-trip fixture coverage, production-reader expectations, and external inventory. | Add repair summary round-trip fixture and explicit non-reader/non-healthcheck contract before cleanup. |
| `runtime-owner.json` | `src/CodexWatcher/Runtime/Owner/Store.hs` writes current lease JSON under top-level `lease`. CLI and automatic-loop paths write or renew it. | `Runtime/Owner/Store.hs`, `Runtime/Owner/Cli.hs`, PR-review launch code, automatic loop startup/runner paths, healthcheck, and `scripts/restart-watcher` read or parse it. | Read as `runtimeOwner` for issue planning, issue implementation, and PR review. Healthcheck currently looks up `["runtimeOwner","owner"]`, while the current stored shape nests fields under `lease`; this remains a policy/field-path blocker, not approval to change behavior. | No repair read found. `scripts/restart-watcher` parses the first `"pid"` string with `sed`, stops it, then removes the file during cleanup. | `test/Main.hs` covers current lease JSON parsing, rejection of old owner-only shape, running-lease rejection, and current-process cleanup. `test/HealthcheckSpec.hs` covers runtimeOwner rendering cases. | None found. | Runbook preflight requires absent/inactive `runtime-owner.json`; compatibility policy keeps it and calls out field-path policy and script inventory gaps. | Add checked-in lease fixtures for healthcheck/script behavior, field-path policy tests, and external operator script inventory. |
| Checked-in compatibility snapshots | Existing snapshot producers are fixture directories and event-log/golden data, not live runtime writers. | `src/CodexWatcher/Snapshot.hs` loads snapshot directories, including optional daemon and block state; replay/bootstrap tests consume these paths. | Healthcheck reads live state files, not checked-in fixture directories. | Golden snapshot replay/bootstrap validates old snapshot directories; repair can regenerate compatibility files from replay state but does not read these fixture directories directly. | `test/Main.hs` golden replay/bootstrap cases; `test/WorkflowEventLogSpec.hs` event-log fixture decoding and replay contracts. | Found selected files: `golden/issue-implement/mlf2-issue42-incomplete/daemon-state.json` and `golden/pr-review/mlf2-pr6-blocked/block-state.json`. No checked-in selected `planner-state.json`, `planning-state.json`, `repair-state.json`, `runtime-owner.json`, or live `issue-snapshot.json` file found. | Project contract treats golden replay fixtures and compatibility snapshots as contracts. Compatibility policy defers checked-in snapshot cleanup until fixture-by-fixture old-log/golden proof and reviewer approval. | Add or classify per-surface fixtures before any migration/removal decision; preserve existing snapshot paths until exact evidence exists. |
| Live `issue-snapshot.json` | `src/CodexWatcher/Domain/IssuePlanning/Loop.hs` writes it in execute mode before planner turn start through `issuePlanningSnapshotPath`. | `src/CodexWatcher/TurnOutput.hs` renders `issueSnapshotPath` into planner prompt/turn output. No repair, replay, restart, golden, or healthcheck direct reader found. | Not read by healthcheck. | No repair/replay/script direct interaction found in the focused scan. | `test/Main.hs` protects snapshot write-before-turn-start timing, closed-scope behavior, prompt text that instructs reading the current issue snapshot, and canonical graph fetch behavior. | None found. | Compatibility policy defers live snapshot cleanup and records missing old live snapshot fixture coverage and direct-reader inventory. | Add live snapshot fixtures and explicit write-timing contract before any planner-turn or runtime-state cleanup decision. |

## Healthcheck Reader Evidence

Current `stateFileSpecs` reads:

- Issue planning: `daemon-state.json`, `planner-state.json`,
  `block-state.json`, and `runtime-owner.json`.
- Issue implementation: `daemon-state.json`, `issue-state.json`,
  `block-state.json`, and `runtime-owner.json`.
- PR review: `watcher-state.json`, `checker-state.json`, `agent-state.json`,
  `reviewer-state.json`, `block-state.json`, and `runtime-owner.json`.

Current `stateFileSpecs` does not read:

- `planning-state.json`
- `repair-state.json`
- live `issue-snapshot.json`

Tests and scans that currently protect or document this are source-oriented:
`test/BoundaryPolicySpec.hs` checks state-file names and cleanup-policy strings,
`test/HealthcheckSpec.hs` checks healthcheck output behavior, and `test/Main.hs`
contains older runtime compatibility and healthcheck-related assertions. This
is enough to describe current behavior, but it is not enough to approve a
healthcheck behavior change.

## Policy References

- `orchestrator/project-contract.md` keeps compatibility files available until
  explicit fixture, old-log, repair, healthcheck, write-timing, operator, and
  behavior evidence approves a selected migration or removal.
- `orchestrator/project-contract.md` and active roadmap verification both say
  `planner-state.json` and `planning-state.json` are distinct compatibility
  surfaces.
- `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`
  classifies `daemon-state.json`, `block-state.json`, and
  `runtime-owner.json` as keep surfaces, and classifies
  `planning-state.json`, `repair-state.json`, checked-in compatibility
  snapshots, and live `issue-snapshot.json` as deferred surfaces with missing
  evidence.
- Runbook/operator docs mention `runtime-owner.json` preflight and
  `block-state.json` post-restart inspection.
- Preferred imports, local absence of users, and prior terminal holds are not
  deprecation, migration, Cabal exposure, or removal approval.

## Prioritized Blockers

### Immediate Fixture Blockers

1. Add checked-in fixture coverage for `planner-state.json` and
   `planning-state.json` old/current shapes.
2. Add active and stopped `daemon-state.json` fixtures.
3. Add repair-failure `block-state.json` fixture coverage.
4. Add `repair-state.json` repair summary fixture coverage.
5. Add current `runtime-owner.json` lease fixtures, including the healthcheck
   and script field paths that operators rely on.
6. Add live `issue-snapshot.json` fixture or fixture-equivalent evidence for
   planner prompt consumption and write timing.

### Healthcheck Contract Blockers

1. Record explicit read/non-read contract tests for every selected surface.
2. Resolve or explicitly preserve the `runtime-owner.json` healthcheck
   field-path behavior against the current top-level `lease` JSON.
3. Keep `planning-state.json`, `repair-state.json`, and live
   `issue-snapshot.json` as explicit non-read surfaces unless a later selected
   behavior-change round approves otherwise.

### Planner/Planning Contract Blockers

1. Record a reviewed contract that keeps `planner-state.json` and
   `planning-state.json` distinct.
2. Cover both producer paths: compatibility projection and direct
   `RecordPlanningGraph`.
3. Record write-timing evidence before any reader, filename, schema, or
   migration decision.

### Operator/Downstream Inventory Blockers

1. Inventory scripts and runbooks that inspect or remove
   `runtime-owner.json`, `block-state.json`, and `daemon-state.json`.
2. Inventory any external downstream readers before concluding a file is
   write-only or unused.
3. Keep runbook/operator behavior separate from healthcheck behavior; neither
   one can approve the other by implication.

### Removal/Migration Blockers

1. Produce old-log, golden, repair, healthcheck, write-timing, fixture,
   operator, downstream, and behavior evidence for the exact selected surface.
2. Update docs, tests, and policy together only in a later selected round.
3. Do not treat this inventory as removal, rename, deprecation, migration,
   Cabal exposure, healthcheck, repair, or runtime behavior approval.

## Scope Confirmation

This round changed only round-local artifacts requested by the plan:

- `orchestrator/rounds/round-087/compatibility-fixture-gap-inventory.md`
- `orchestrator/rounds/round-087/implementation-notes.md`

It intentionally did not create
`orchestrator/rounds/round-087/worker-plan.json`.
