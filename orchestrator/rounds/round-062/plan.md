### Goal

Produce source-backed evidence for the `CodexWatcher.Workflow.EventLog` helper boundary without changing event-log helpers, production imports, public facades, Cabal exposure, event schemas, golden fixtures, runtime compatibility behavior, roadmap files, or `orchestrator/state.json`.

The round should leave a reviewed evidence artifact under `orchestrator/rounds/round-062/` that refreshes import and usage evidence, classifies each facade helper as either concrete moifold compatibility behavior or a preferred reusable event-log/audit import, reads back old-log and golden replay coverage protecting current behavior, and names blockers before any later helper movement, facade narrowing, migration, deprecation, or removal decision.

### Approach

Keep this as a sequential evidence-only round. Do not fan out workers: the deliverable is one compatibility-boundary inventory whose import scan, helper classification, replay coverage readback, and blocker conclusion need a single consistent source of truth.

Use `orchestrator/project-contract.md` for stable compatibility invariants: event schemas, JSON `type` fields, schema versions, parse behavior, golden event-log fixtures, replay determinism, package/module ownership, and public compatibility facades must not change unless a later roadmap explicitly authorizes a proven migration. Use the active verification bundle's `CodexWatcher.Workflow.EventLog` task-specific check as the acceptance gate: protect old-log and golden replay behavior before helper movement or facade narrowing.

The expected implementation output is a round-local evidence artifact, preferably `orchestrator/rounds/round-062/event-log-helper-boundary-evidence.md`, plus normal implementation notes. Do not add deprecation pragmas, migrate imports, move helpers, rewrite fixtures, change event codecs, update package descriptors, or claim any removal approval.

Classify helpers into these buckets:

- Concrete moifold compatibility helpers: `initializeMoifoldWorkflow`, `applyMoifoldWorkflowEvent`, and `replayMoifoldWorkflowEvents`, because they bind concrete `MoifoldSpec`, `WatcherEvent`, `SomeWatcherState`, `EffectPlan`, `ReplayFailure`, and moifold replay policy.
- Preferred reusable event-log helpers: `EventLogFixtureContract`, `WorkflowReplayFailure`, `WorkflowReplaySummary`, `WorkflowTransitionFailure`, `applyWorkflowEvent`, `initializeWorkflowEvent`, `replayWorkflowEventLog`, `replayWorkflowEventLogDetailed`, `formatWorkflowReplayFailure`, `formatWorkflowTransitionFailure`, and `validateEventLogFixtureContract`, whose preferred reusable import is `CodexWatcher.Workflow.EventLog.Core`.
- Preferred reusable audit helpers: `WorkflowNextDaemonRecommendation`, `WorkflowTickAudit`, `workflowAuditCommittedEventLabel`, `workflowAuditFailureClassification`, `workflowAuditFinalStateLabel`, `workflowAuditNextDaemonRecommendation`, `workflowAuditObservationLabel`, `workflowAuditPostCommitReports`, `workflowAuditPreCommitReports`, `workflowAuditPriorStateLabel`, `workflowDryRunAudit`, `workflowFailureAudit`, and `workflowSuccessAudit`, whose preferred reusable import is `CodexWatcher.Workflow.Audit` when code is not relying on moifold-specific failure retry binding.
- Preferred reusable file/commit helpers are not reexported by the facade; record them as adjacent replacement imports from `CodexWatcher.Workflow.EventLog.File.Core` and `CodexWatcher.Workflow.EventLog.Commit.Core` when usage evidence references event-log file or commit behavior.

### Steps

1. Create one evidence artifact, `orchestrator/rounds/round-062/event-log-helper-boundary-evidence.md`.
2. Refresh the selected-facade import inventory with anchored import scans across source, tests, examples, standalone package candidates, docs, README files, Cabal descriptors, and app files when present:

   ```sh
   rg -n '^ *import +(qualified +)?CodexWatcher\.Workflow\.EventLog(\b| +as +| *$| *\()' src test examples agent-workflow-core agent-workflow-codex agent-workflow-github README.md docs *.cabal */*.cabal
   rg -l '^ *import +(qualified +)?CodexWatcher\.Workflow\.EventLog(\b| +as +| *$| *\()' src test examples agent-workflow-core agent-workflow-codex agent-workflow-github README.md docs *.cabal */*.cabal | sort
   ```

   Record the command, current count, and file list. At planning time the direct facade import scan finds `src/CodexWatcher/Daemon.hs`, `src/CodexWatcher/Workflow/DocsMigration.hs`, and `test/Main.hs`; the implementer must refresh from the current tree and prefer current output over this snapshot.
3. Add a broader reference scan for public docs, package docs, Cabal descriptors, tests, examples, and downstream/operator evidence where available:

   ```sh
   rg -n 'CodexWatcher\.Workflow\.EventLog|CodexWatcher\.Workflow\.EventLog\.(Core|File\.Core|Commit\.Core)|CodexWatcher\.Workflow\.Audit|WatcherEvent|golden replay|event-log|event log' README.md docs examples *.cabal */*.cabal agent-workflow-core agent-workflow-codex agent-workflow-github src test golden
   ```

   Classify each relevant reference as observed usage, package exposure, public/policy documentation, fixture/replay evidence, test assertion, or unavailable downstream/operator evidence. Local absence of downstream/operator references must be recorded as unavailable, not as removal approval.
4. Read back the facade and replacement implementation shape:

   - `src/CodexWatcher/Workflow/EventLog.hs` should remain the moifold-facing compatibility facade that reexports generic event-log/audit helpers and defines concrete moifold wrappers.
   - `agent-workflow-core/src/CodexWatcher/Workflow/EventLog/Core.hs` should own generic initialization, apply, replay summary/failure, fixture contract, validation, and formatting helpers.
   - `agent-workflow-core/src/CodexWatcher/Workflow/Audit.hs` should own reusable audit type and label/report/recommendation accessors plus generic audit constructors.
   - `agent-workflow-core/src/CodexWatcher/Workflow/EventLog/File/Core.hs` and `agent-workflow-core/src/CodexWatcher/Workflow/EventLog/Commit/Core.hs` should own reusable file decoding and commit helpers when those are relevant to callers or tests.
   - `src/CodexWatcher/EventLog/Types.hs`, `src/CodexWatcher/EventLog/Replay.hs`, and `src/CodexWatcher/EventLog/File.hs` should remain concrete moifold event/replay/file wrappers around `WatcherEvent` and current event JSON behavior.

5. Build a helper-by-helper ownership table from the current export list in `src/CodexWatcher/Workflow/EventLog.hs`. For each helper, record the current owner, preferred reusable import if any, whether the facade export is compatibility-only or still product-facing, and which current callers/tests exercise it. Do not infer that a helper can move or be removed just because a replacement import exists.
6. Group current facade callers by behavior instead of only by file:

   - Moifold daemon/product behavior: `src/CodexWatcher/Daemon.hs` and any other refreshed source caller using audit labels, audit reports, transaction behavior, replay, or concrete moifold state.
   - Docs-migration or other generic workflow behavior: `src/CodexWatcher/Workflow/DocsMigration.hs` and any refreshed caller that imports generic replay/audit helpers through the facade.
   - Test/golden behavior: `test/Main.hs` and any refreshed test caller validating facade parity, generic core behavior, audit behavior, old logs, golden event logs, or DocsMigration event-log behavior.
   - Public/package docs: docs and Cabal references that present the facade as supported compatibility surface or present core modules as preferred reusable imports.

7. Prove package-boundary exposure without changing descriptors. Read back `moifold.cabal` and `agent-workflow-core/agent-workflow-core.cabal` to show that the moifold library still exposes `CodexWatcher.Workflow.EventLog`, while `agent-workflow-core` exposes `CodexWatcher.Workflow.EventLog.Core`, `CodexWatcher.Workflow.EventLog.File.Core`, `CodexWatcher.Workflow.EventLog.Commit.Core`, and `CodexWatcher.Workflow.Audit`.
8. Read back old-log and golden replay coverage protecting current behavior. Include at least:

   - the checked-in old event logs under `golden/event-log/**/events.jsonl`;
   - test coverage in `test/Main.hs` around event-log decode, replay, golden type fields, golden replay expectations, and failure messages;
   - facade/core parity tests for `replayMoifoldWorkflowEvents` versus `replayWorkflowEventLog @MoifoldSpec`, `initializeMoifoldWorkflow` versus `initializeWorkflowEvent @MoifoldSpec`, and `applyMoifoldWorkflowEvent` versus `applyWorkflowEvent @MoifoldSpec`;
   - generic core fixture-contract coverage for `replayWorkflowEventLogDetailed` and `validateEventLogFixtureContract`;
   - DocsMigration event-log fixture coverage if the refreshed scan confirms it still imports the facade.

9. Record blockers conservatively. Expected blockers include current production/test imports through the facade, concrete `WatcherEvent` schema and `MoifoldSpec` coupling, old-log/golden replay compatibility obligations, public docs that still describe the facade as supported compatibility surface, lack of downstream/operator confirmation, and lack of a later selected round authorizing import rewrites or facade narrowing. These blockers are evidence for later planning, not approval to remove or deprecate anything now.
10. Keep the diff limited to round-local evidence artifacts and implementation notes when the implementer runs. Do not edit `orchestrator/state.json`, roadmap files, source modules, tests, docs outside the round, Cabal descriptors, golden fixtures, runtime compatibility files, review artifacts, or merge artifacts.

### Verification

Run artifact and scope checks:

```sh
git diff --name-only
git status --short
git diff --check
```

The changed files should be limited to `orchestrator/rounds/round-062/plan.md`, `orchestrator/rounds/round-062/event-log-helper-boundary-evidence.md`, and the round-level implementation notes produced by the implementer. If any production source, tests, docs outside the round, Cabal descriptors, golden fixtures, roadmap files, `orchestrator/project-contract.md`, or `orchestrator/state.json` change, the round has escaped this plan.

Run the evidence scans and include refreshed output summaries in the evidence artifact or implementation notes:

```sh
rg -n '^ *import +(qualified +)?CodexWatcher\.Workflow\.EventLog(\b| +as +| *$| *\()' src test examples agent-workflow-core agent-workflow-codex agent-workflow-github README.md docs *.cabal */*.cabal
rg -l '^ *import +(qualified +)?CodexWatcher\.Workflow\.EventLog(\b| +as +| *$| *\()' src test examples agent-workflow-core agent-workflow-codex agent-workflow-github README.md docs *.cabal */*.cabal | sort
rg -n 'CodexWatcher\.Workflow\.EventLog|CodexWatcher\.Workflow\.EventLog\.(Core|File\.Core|Commit\.Core)|CodexWatcher\.Workflow\.Audit|WatcherEvent|golden replay|event-log|event log' README.md docs examples *.cabal */*.cabal agent-workflow-core agent-workflow-codex agent-workflow-github src test golden
rg -n 'CodexWatcher\.Workflow\.EventLog|CodexWatcher\.Workflow\.EventLog\.(Core|File\.Core|Commit\.Core)|CodexWatcher\.Workflow\.Audit' moifold.cabal agent-workflow-core/agent-workflow-core.cabal docs/agentic-workflow-framework/compatibility-deprecation-policy.md docs/agentic-workflow-framework/package-consumer-guide.md docs/agentic-workflow-framework/implemented-api-freeze.md
find golden/event-log -type f -name 'events.jsonl' -maxdepth 4 -print | sort
```

Because this is evidence-only, the implementer may skip `cabal build all`, `cabal test watcher-core-test`, and `scripts/validate-workflow-packages.sh` only if the diff remains limited to round-local orchestrator artifacts. If the diff touches production code, tests, package descriptors, public docs, scripts, golden fixtures, or runtime compatibility files, require the full baseline from `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/verification.md`:

```sh
cabal build all
cabal test watcher-core-test
scripts/validate-workflow-packages.sh
```

If files are staged later in the round, also run:

```sh
git diff --cached --check
```

### Worker Fan-Out

Worker fan-out is not used. No `worker-plan.json` should be written for this round.
