## Scope

Round: `round-083-cleanup-inventory-refresh`
Roadmap: `2026-05-11-00-highest-value-cleanup`, `rev-001`
Milestone: `milestone-001-test-topology-inventory`
Direction: `direction-001-cleanup-inventory-refresh`

This is a round-local evidence inventory only. It records current source,
test, fixture, policy, and operator evidence for later test-topology,
fixture, import-convergence, and module-split rounds. It does not change
production code, test code, Cabal files, docs, fixtures, runtime state files,
roadmap files, or controller state.

## Roadmap Lineage

- Active controller state points at
  `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`
  and active round `round-083`.
- Selection artifact:
  `orchestrator/rounds/round-083/selection.md`.
- Plan artifact:
  `orchestrator/rounds/round-083/plan.md`.
- Active verification artifact:
  `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`.
- Stable project contract:
  `orchestrator/project-contract.md`.

## Non-Goals

- No facade, public module, export, Cabal exposed-module entry, compatibility
  file, fixture, event schema, or runtime behavior is classified here as
  approved for any later action.
- Preferred imports are recorded only as current policy evidence, not as
  warning policy, Cabal exposure change, deprecation, migration, or removal
  approval.
- Local absence of a reader, fixture, or downstream checkout is recorded as an
  evidence gap or unknown, not as approval.
- Prior terminal-hold artifacts are non-removal evidence only.

## Compatibility Facade Inventory

### `CodexWatcher.AppServerClient`

- Facade file: `src/CodexWatcher/AppServerClient.hs`.
- Shape: pure reexport of
  `CodexWatcher.Workflow.Agent.Codex.Client` and
  `CodexWatcher.Workflow.Agent.Codex.Transport`.
- Cabal exposure: `moifold.cabal` exposes `CodexWatcher.AppServerClient`.
- Replacement owner modules visible from source:
  `CodexWatcher.Workflow.Agent.Codex.Client` and
  `CodexWatcher.Workflow.Agent.Codex.Transport` in the Codex workflow package.
- Current import scan:
  - `src`: 12 direct imports:
    `RunnerGuard.hs`, PR-review turn classifier and launch CLI,
    issue-planning turn classifier and loop, issue-implement turn classifier,
    `Turn/Classifier/Common.hs`, `Healthcheck.hs`,
    `AutomaticLoop/Runner.hs`, and CLI commands for app-server probe, issue
    fanout, and observe.
  - `app`: no direct imports found.
  - `test`: `test/Main.hs`.
  - package candidates: no direct facade imports found under
    `agent-workflow-*`.
  - docs: no direct import line found.
  - orchestrator evidence: `round-077/plan.md` records broad imports left for a
    later round.
- Follow-up gate: any import convergence needs direct-owner import evidence for
  each touched file plus app-server endpoint parsing, protocol, session,
  command-rendering, and failure-formatting coverage where applicable.

### `CodexWatcher.Core.Ids`

- Facade file: `src/CodexWatcher/Core/Ids.hs`.
- Shape: pure reexport of `CodexWatcher.Workflow.Agent.Ids` and
  `CodexWatcher.Workflow.GitHub.Ids`.
- Cabal exposure: `moifold.cabal` exposes `CodexWatcher.Core.Ids`.
- Replacement owner modules visible from source:
  `CodexWatcher.Workflow.Agent.Ids` for agent/thread/turn/request ids and
  `CodexWatcher.Workflow.GitHub.Ids` for repo/branch/commit/issue/PR/review
  ids.
- Current import scan:
  - `src`: 29 direct imports across effect interpretation, daemon-loop types,
    runner guard, golden replay, core state, state machine, runtime
    compatibility, event-log repair/types/replay, workflow execution,
    healthcheck, domain loops/watchers, CLI parsers and commands, and the
    issue-implement indexed workflow module.
  - `app`: `app/Main.hs`.
  - `test`: `test/Main.hs`, `test/CliSpec.hs`, `test/RuntimeSpec.hs`.
  - package candidates: no direct facade imports found under
    `agent-workflow-*`.
  - docs: no direct import line found.
- Follow-up gate: split-import work needs parser/renderer coverage for repo
  names, branch names, commit SHAs, PR numbers, issue numbers, thread ids,
  turn ids, request ids, and review thread ids before any public decision.

### `CodexWatcher.Workflow.EventLog`

- Facade file: `src/CodexWatcher/Workflow/EventLog.hs`.
- Shape: mixed moifold bridge. It reexports generic event-log/core/audit
  helpers and also defines concrete moifold wrappers:
  `initializeMoifoldWorkflow`, `applyMoifoldWorkflowEvent`, and
  `replayMoifoldWorkflowEvents`.
- Cabal exposure: `moifold.cabal` exposes `CodexWatcher.Workflow.EventLog`.
- Replacement owner modules visible from source:
  `CodexWatcher.Workflow.EventLog.Core`,
  `CodexWatcher.Workflow.EventLog.File.Core`,
  `CodexWatcher.Workflow.EventLog.Commit.Core`, and
  `CodexWatcher.Workflow.Audit` for generic reusable-package code.
- Current import scan:
  - `src`: `src/CodexWatcher/Daemon.hs` and
    `src/CodexWatcher/Workflow/DocsMigration.hs`.
  - `app`: no direct imports found.
  - `test`: `test/Main.hs`.
  - package candidates: no facade import found; core package imports
    `EventLog.Core` and `EventLog.Commit.Core` directly.
  - docs: no direct import line found.
  - orchestrator evidence: `round-062/event-log-helper-boundary-evidence.md`.
- Follow-up gate: convergence or public-surface changes need old-log parsing,
  golden replay, event JSON `type` stability, transition/replay parity, and
  concrete moifold wrapper behavior evidence.

### `CodexWatcher.Workflow.Permission`

- Facade file: `src/CodexWatcher/Workflow/Permission.hs`.
- Shape: mixed moifold bridge. It imports generic
  `CodexWatcher.Workflow.Permission.Core` while exposing concrete moifold
  permission helpers such as `validateMoifoldEffectPlan` and
  `moifoldPermissionPolicy`.
- Cabal exposure: `moifold.cabal` exposes `CodexWatcher.Workflow.Permission`.
- Replacement owner module visible from source:
  `CodexWatcher.Workflow.Permission.Core` for reusable permission checks.
- Current import scan:
  - `src`: no direct production import found outside the facade file.
  - `app`: no direct imports found.
  - `test`: `test/Main.hs`.
  - package candidates: no facade imports found; core package exposes
    `CodexWatcher.Workflow.Permission.Core`.
  - docs: no direct import line found.
  - orchestrator evidence:
    `round-063/workflow-permission-public-api-evidence.md`.
- Follow-up gate: any later public decision needs permission soundness,
  phase-validation errors, state/effect validation, concrete `MoifoldSpec`
  behavior, public API, and downstream-user evidence.

## Runtime Compatibility-File Inventory

### `planner-state.json`

- Production producers: `src/CodexWatcher/Runtime/Compatibility.hs` writes
  `ready`, `active`, `waiting_ready_issues`, and `complete` planning states.
- Production readers: current focused scan found `src/CodexWatcher/Healthcheck.hs`
  reads it for issue-planning healthcheck state files.
- Healthcheck readers: `stateFileSpecs SIssuePlanning` includes
  `("plannerState", "planner-state.json")`.
- Repair/replay readers: no direct repair read found in the focused scan;
  repair may rewrite compatibility files from replay state through
  `compatibilityStateWrites`.
- Tests: `test/Main.hs` contains compatibility write and healthcheck source
  checks around planner state behavior.
- Fixtures: no checked-in `planner-state.json` fixture found by the focused
  file-name scan.
- Gaps: explicit `planner-state.json` versus `planning-state.json` contract,
  fixture coverage, write-timing evidence, and external direct-reader
  inventory remain needed for later runtime-state work.

### `planning-state.json`

- Production producers: `Runtime.Compatibility` writes it for
  `PlanningWaitingForReadyIssues`; `EffectInterpreter` also writes it for
  `RecordPlanningGraph`.
- Production readers: no production Haskell reader found in the focused scan.
- Healthcheck readers: current healthcheck scan reads `planner-state.json` for
  issue planning, not `planning-state.json`.
- Repair/replay readers: repair rewrite can emit it when repaired replay state
  projects a waiting-ready-issues planning state.
- Tests: `test/Main.hs` asserts direct graph writes, canonical planning graph
  writes, indexed planning parity, and daemon compatibility writes.
- Fixtures: no checked-in `planning-state.json` fixture found.
- Gaps: old/current fixture coverage, external/direct-reader inventory, and
  reviewed behavior-selection evidence are needed before any reader, filename,
  schema, timing, or public decision.

### `daemon-state.json`

- Production producers: `Runtime.Compatibility` writes idle, active, stopped,
  and other daemon summaries; issue-implement launch writes compatibility
  state through launch compatibility writes.
- Production readers: `src/CodexWatcher/Snapshot.hs` reads optional daemon
  state for issue-implementation snapshots.
- Healthcheck readers: shared issue-planning and issue-implementation
  healthcheck state files include `("daemonState", "daemon-state.json")`.
- Repair/replay readers: repair command rewrites compatibility files from the
  repaired replay state, which may include daemon state.
- Scripts/operators: `scripts/restart-watcher` removes it during cleanup.
- Tests: `test/Main.hs` checks launch compatibility writes, healthcheck
  read-only state-file surfacing, and repair rewrite ordering.
- Fixtures: `golden/issue-implement/mlf2-issue42-incomplete/daemon-state.json`
  is checked in.
- Gaps: current active/stopped daemon fixtures and external
  operator/downstream direct-reader evidence remain missing.

### `block-state.json`

- Production producers: `EffectInterpreter` writes it for `RecordBlocked`;
  `Runtime.Compatibility` writes it for `BlockedState`; runner repair paths
  can write repair-failure block state.
- Production readers: `src/CodexWatcher/Snapshot.hs` reads optional block
  state.
- Healthcheck readers: issue-planning, issue-implementation, and PR-review
  healthcheck state file specs include block state.
- Repair/replay readers: successful repair removes stale `block-state.json`
  after compatibility rewrite; restart can remove it and optionally drop a
  blocked tail.
- Scripts/operators: `scripts/restart-watcher` removes it; operator checklist
  says to check it after restart.
- Tests: `test/Main.hs` covers `RecordBlocked`, blocked effect ordering,
  healthcheck state-file surfacing, and repair ordering.
- Fixtures: `golden/pr-review/mlf2-pr6-blocked/block-state.json` is checked
  in.
- Gaps: repair-failure block-state fixture coverage and external direct-reader
  inventory remain missing.

### `repair-state.json`

- Production producers: `src/CodexWatcher/Cli/Command/Replay.hs` writes
  `repair-state.json` in execute repair after archiving the invalid event log
  and writing repaired `events.jsonl`, then rewrites compatibility files and
  removes stale block state.
- Production readers: no Haskell production reader found in the focused scan.
- Healthcheck readers: current `stateFileSpecs` does not include
  `repair-state.json`.
- Repair/replay readers: it is repair command output evidence, not a repair
  input in the focused source.
- Tests: `test/Main.hs` protects repair dry-run/execute source ordering.
- Fixtures: no checked-in `repair-state.json` fixture found.
- Gaps: fixture round-trip coverage, production-reader expectation, external
  direct-reader inventory, and operator approval evidence remain missing.

### `runtime-owner.json`

- Production producers/readers: `src/CodexWatcher/Runtime/Owner/Store.hs`
  writes and reads a top-level `lease` object; `Runtime/Owner/Cli.hs`,
  automatic-loop startup/runner paths, PR-review launch reuse, and healthcheck
  also participate in current owner behavior.
- Healthcheck readers: issue-planning, issue-implementation, and PR-review
  state file specs include runtime owner.
- Repair/replay readers: no repair read found; restart script parses/removes
  it.
- Scripts/operators: `scripts/restart-watcher` reads the first `"pid"` with
  `sed`, stops that pid, and removes the file during cleanup; runbooks require
  absent or inactive lease before starting loops.
- Tests: `test/Main.hs` covers current lease JSON parsing, rejection of
  old owner-only shapes, running-lease rejection, and current-process cleanup.
- Fixtures: no checked-in `runtime-owner.json` fixture found.
- Gaps: checked-in fixture coverage, healthcheck field-path policy, external
  operator script inventory, and live archive evidence remain missing.

### Checked-In Compatibility Snapshots

- Focused file-name scan found:
  - `golden/issue-implement/mlf2-issue42-incomplete/daemon-state.json`
  - `golden/pr-review/mlf2-pr6-blocked/block-state.json`
- Existing golden event-log and snapshot replay tests live mainly in
  `test/Main.hs`, with fixture path lists and replay checks.
- No checked-in `planner-state.json`, `planning-state.json`,
  `repair-state.json`, `runtime-owner.json`, or live `issue-snapshot.json`
  fixture was found by this round's file-name scan.
- Follow-up gate: fixture-by-fixture old-log/golden proof and reviewer
  approval are required before any later fixture or compatibility snapshot
  decision.

### Live `issue-snapshot.json`

- Production producer: `src/CodexWatcher/Domain/IssuePlanning/Loop.hs` writes
  it in execute mode before planner turn start through
  `issuePlanningSnapshotPath`.
- Production consumer evidence: `src/CodexWatcher/TurnOutput.hs` renders
  `issueSnapshotPath` into prompt/turn output data.
- Healthcheck readers: no healthcheck reader found in the focused scan.
- Repair/replay readers: no repair, restart, replay, or golden direct reader
  found in the focused scan.
- Tests: `test/Main.hs` protects write timing before planner turn start and
  closed-scope behavior.
- Fixtures: no checked-in live `issue-snapshot.json` fixture found.
- Gaps: old/current live snapshot fixture coverage, external direct-reader
  inventory, and explicit write-timing/planner-turn evidence remain needed.

## Test Topology And Helper Clusters

- Current line counts:
  - `test/Main.hs`: 16956 lines.
  - `test/AppServerSpec.hs`: 334 lines.
  - `test/CliSpec.hs`: 212 lines.
  - `test/GhGitSpec.hs`: 251 lines.
  - `test/HealthcheckSpec.hs`: 200 lines.
  - `test/JsonPathSpec.hs`: 16 lines.
  - `test/RuntimeSpec.hs`: 411 lines.
- Obvious `test/Main.hs` clusters visible from read-only scans:
  - Event-log replay and repair properties near lines 649-1195 and
    1772-1995.
  - Turn-output schema and prompt compatibility checks near lines 2497-2876.
  - Runtime compatibility-file and owner behavior near lines 2952-3097.
  - Daemon observed tick, dry-run/execute, and compatibility-write behavior
    near lines 3897-5239 and 10062-10731.
  - Package-boundary and facade-policy source scans near lines 7280-8105.
  - Workflow event-log, permission, DocsMigration, indexed workflow, and DSL
    behavior checks near lines 8208-16293.
  - Test runner aggregation near lines 16640-16881.
- Follow-up gate: later test splits should preserve assertion intent and
  failure messages where practical, keep `watcher-core-test` reachability, and
  record before/after line counts.

## Large Behavior-Module Inventory

- `src/CodexWatcher/Daemon.hs`: 960 lines. Broad ownership includes daemon
  tick execution, audit, compatibility writes, and action interpretation
  boundaries. Test anchors include `runObservedDaemonTickWithEvents`,
  dry-run/execute parity, write ordering, and audit labels in `test/Main.hs`.
- `src/CodexWatcher/Workflow/DocsMigration.hs`: 954 lines. Broad ownership
  includes DocsMigration spec, indexed spec, event codec, interpreter, dry-run
  and execute helpers. Test anchors include DocsMigration facade laws,
  indexed parity, codec fixture contract, permission checks, and core
  daemon projection tests in `test/Main.hs`.
- `src/CodexWatcher/Workflow/Moifold/IssueImplement/Indexed.hs`: 940 lines.
  Broad ownership includes indexed issue-implement projections and
  compatibility transition parity. Test anchors include indexed issue-planning
  and issue-implement parity clusters plus daemon routing source scans.
- `src/CodexWatcher/EventLog/Types.hs`: 672 lines. Broad ownership includes
  event constructors, JSON names, schema stability, and replay-facing event
  shape. Test anchors include canonical JSON round trips, type-field fixture
  checks, old-log rejection, and golden replay.
- `src/CodexWatcher/TurnOutput.hs`: 618 lines. Broad ownership includes
  structured turn output schemas, prompt/turn paths, and
  `issueSnapshotPath` rendering. Test anchors include app-server schema tests
  in `test/AppServerSpec.hs` and turn-output schema checks in `test/Main.hs`.
- Follow-up gate: module decomposition needs focused tests for each moved
  behavior cluster plus import-cycle checks; this inventory does not propose
  concrete split modules.

## Fixture Coverage

| Surface | Checked-in fixture evidence | Current gap |
| --- | --- | --- |
| `planner-state.json` | none found | old/current fixture and explicit planner/planning contract |
| `planning-state.json` | none found | graph-state fixture, non-healthcheck policy, external readers |
| `daemon-state.json` | `golden/issue-implement/mlf2-issue42-incomplete/daemon-state.json` | current active/stopped daemon fixtures |
| `block-state.json` | `golden/pr-review/mlf2-pr6-blocked/block-state.json` | repair-failure fixture |
| `repair-state.json` | none found | repair summary round-trip fixture |
| `runtime-owner.json` | none found | lease fixture and healthcheck/script field policy |
| live `issue-snapshot.json` | none found | live snapshot fixture and write-timing evidence |

Replay and event-log fixture coverage exists in `test/Main.hs`, but runtime
state-file fixture coverage remains uneven and should be treated per exact
surface in later rounds.

## Policy References

- `orchestrator/project-contract.md` requires public compatibility facades and
  compatibility files to remain available until exact reviewed gates prove a
  safe later step.
- `orchestrator/project-contract.md` records that the previous
  `2026-05-09-01-compatibility-surface-cleanup` family closed with an empty
  removed-surface set and must not be treated as approval.
- Active verification forbids treating preferred-import guidance, import
  reduction, a terminal hold, or local absence of users as approval.
- `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`
  records preferred-import guidance and missing gates, but states that
  preferred imports are not warning policy, Cabal descriptor migration, or
  approval.
- `orchestrator/rounds/round-074/terminal-cleanup-gate.md` records the prior
  reviewed terminal hold, empty removed-surface set, and carried-forward
  blockers.

## Downstream And Operator Scope

Observed local scope:

- Cabal descriptors: `moifold.cabal` and `agent-workflow-*/*.cabal`.
- Repo-local scripts: `scripts/restart-watcher` and watcher init scripts.
- Repo-local runbooks/docs: `docs/watcher-agent-runbook/**` and
  `docs/agentic-workflow-framework/**`.
- Golden configs and fixtures under `golden/**`.
- Prior round evidence under `orchestrator/rounds/**`.

Not inspected or unavailable in this worktree:

- External downstream repositories.
- Hosted CI or package upload/release evidence.
- Live state archives outside this checkout.
- Operator approvals outside checked-in docs and prior round artifacts.
- External operator scripts not present in this repo.

These unavailable scopes remain blockers or unknowns for later public,
runtime-state, or compatibility-surface decisions.

## Follow-Up Gates

- Test topology: extract package-boundary/facade-policy helpers out of
  `test/Main.hs` while preserving assertions, runner wiring, and before/after
  line-count evidence.
- Fixture coverage: add exact old/current fixtures for selected runtime files
  before any runtime-state cleanup.
- Planner/planning contract: record and test the distinct roles of
  `planner-state.json` and `planning-state.json`, including healthcheck reader
  behavior and write timing.
- Import convergence: migrate only selected internal imports toward direct
  owner modules, with behavior and import-scan evidence per touched facade.
- Large-module decomposition: split only behind focused tests and import-cycle
  checks, one behavior module or disjoint module family at a time.
- Policy decisions: any later deprecation, migration, Cabal exposure, or
  removal gate must name the exact surface and prove downstream, docs, tests,
  fixtures, behavior, and operator evidence.

## Artifact-Only Validation

This round intentionally limits writes to:

- `orchestrator/rounds/round-083/cleanup-inventory.md`
- `orchestrator/rounds/round-083/implementation-notes.md`

Package build/test baselines remain skippable only if reviewer changed-path
evidence confirms no production code, test code, package descriptor, docs,
fixture, runtime compatibility file, public API, or behavior surface changed.
