### Goal
Produce a focused evidence artifact and readiness decision for internal migration of
`CodexWatcher.Workflow.EventLog` and `CodexWatcher.Workflow.Permission`.

This round should decide whether each mixed surface is ready for behavior-neutral
internal import migration or should remain held as a concrete moifold bridge for
now. It must not edit production code, tests, package descriptors, docs,
roadmaps, `orchestrator/state.json`, runtime compatibility files, event schemas,
replay behavior, permission or phase-validation behavior, Cabal exposure,
deprecation state, public API, or facade removal.

### Approach
Use a single sequential evidence pass. Worker fan-out is not justified because
the work is artifact-only, the two surfaces share the same module/test/Cabal
evidence, and there is no non-overlapping write ownership beyond the round
artifact.

The implementer should inspect current imports, facade definitions, replacement
core modules, Cabal exposure, and focused protecting tests. The only expected
write is `orchestrator/rounds/round-079/implementation-notes.md`, unless the
implementer discovers that even artifact writing is blocked. The artifact should
record a per-surface decision using `keep`, `defer`, or `hold`, with `hold`
meaning migration is not behavior-neutral yet and later work must preserve the
facade until a reviewed removal/deprecation/public API decision exists.

Treat `orchestrator/project-contract.md` and the active roadmap verification
bundle as authoritative. In particular, do not treat the closed
`2026-05-09-01-compatibility-surface-cleanup` terminal hold as deprecation,
migration, Cabal exposure, or removal approval.

### Steps
1. Confirm active inputs and scope:
   - `git status --short --branch`
   - `sed -n '1,260p' orchestrator/state.json`
   - `sed -n '1,240p' orchestrator/project-contract.md`
   - `sed -n '1,260p' orchestrator/roadmaps/2026-05-10-00-facade-removal-readiness/rev-001/verification.md`
   - `sed -n '1,220p' orchestrator/roadmaps/2026-05-10-00-facade-removal-readiness/rev-001/retry-subloop.md`
   - `sed -n '1,240p' orchestrator/rounds/round-079/selection.md`
   Record in the evidence artifact that this is roadmap
   `2026-05-10-00-facade-removal-readiness`, revision `rev-001`, extracted item
   `round-079-eventlog-permission-readiness-hold`.
2. Refresh the import inventory for the selected facades and direct replacement
   modules:
   - `rg -n "^ *import +(qualified +)?CodexWatcher\\.Workflow\\.(EventLog|Permission)(\\b| +as +| *$)" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
   - `rg -n "^ *import +(qualified +)?CodexWatcher\\.Workflow\\.EventLog\\.(Core|File\\.Core|Commit\\.Core)(\\b| +as +| *$)" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
   - `rg -n "^ *import +(qualified +)?CodexWatcher\\.Workflow\\.Permission\\.Core(\\b| +as +| *$)" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
   Record current facade import counts, direct replacement import counts, and
   each selected facade importer. Do not migrate imports.
3. Inspect the facade definitions and generic replacement modules:
   - `sed -n '1,220p' src/CodexWatcher/Workflow/EventLog.hs`
   - `sed -n '1,180p' src/CodexWatcher/Workflow/Permission.hs`
   - `sed -n '1,260p' agent-workflow-core/src/CodexWatcher/Workflow/EventLog/Core.hs`
   - `sed -n '1,220p' agent-workflow-core/src/CodexWatcher/Workflow/EventLog/File/Core.hs`
   - `sed -n '1,220p' agent-workflow-core/src/CodexWatcher/Workflow/EventLog/Commit/Core.hs`
   - `sed -n '1,220p' agent-workflow-core/src/CodexWatcher/Workflow/Permission/Core.hs`
   For `Workflow.EventLog`, separate reusable replay/audit/file/commit helpers
   from moifold-specific bridge helpers such as `initializeMoifoldWorkflow`,
   `applyMoifoldWorkflowEvent`, and `replayMoifoldWorkflowEvents`. For
   `Workflow.Permission`, separate reusable permission policy/check helpers from
   moifold-specific phase validation such as `validateMoifoldEffectPlan`,
   `moifoldPermissionPolicy`, `validateWorkflowEffectPlan`, and the exported
   `PhaseActionValidationError` surface.
4. Inspect Cabal exposure without changing it:
   - `rg -n "CodexWatcher\\.Workflow\\.(EventLog|Permission)(\\b|$)|CodexWatcher\\.Workflow\\.EventLog\\.(Core|File\\.Core|Commit\\.Core)|CodexWatcher\\.Workflow\\.Permission\\.Core" moifold.cabal agent-workflow-core/agent-workflow-core.cabal agent-workflow-codex/agent-workflow-codex.cabal agent-workflow-github/agent-workflow-github.cabal examples/workflow-package-consumer/workflow-package-consumer.cabal`
   Record which selected facades remain exposed by `moifold.cabal`, which core
   modules are internal or exposed in package descriptors, and whether any
   package descriptor change would be required for a future migration. Do not
   edit Cabal files or exposure.
5. Inspect focused protecting tests and record the exact behavioral contracts
   already covered:
   - `rg -n "workflowEventLog|workflow event-log|workflowPermission|workflow permission|phaseActionValidation|phase action|goldenEventLog|golden event|eventLogRepair|replayEventLog" test/Main.hs test/*Spec.hs`
   - `sed -n '6880,6920p' test/Main.hs`
   - `sed -n '8120,8345p' test/Main.hs`
   Record which tests protect old-log/golden replay, event-log line decoding,
   detailed replay parity, transition failure labels, fixture contracts,
   permission facade parity, permission policy parity, and phase-action
   validation. Do not add, delete, weaken, or rewrite tests.
6. Write `orchestrator/rounds/round-079/implementation-notes.md` with:
   - active input confirmation and commands run;
   - a per-surface table for `CodexWatcher.Workflow.EventLog` and
     `CodexWatcher.Workflow.Permission`;
   - current import inventory and Cabal exposure evidence;
   - facade-local definitions versus reusable replacement module ownership;
   - protecting test inventory;
   - final readiness decision for each surface, using `keep`, `defer`, or
     `hold`;
   - explicit blockers for any `hold` decision, such as concrete `WatcherEvent`,
     `SomeWatcherState`, `EffectPlan`, `MoifoldSpec`, old-log/golden replay,
     event schema, permission, phase-validation, public API, downstream
     inventory, or Cabal exposure evidence;
   - explicit confirmation that no production code, tests, Cabal files, docs,
     roadmap files, `orchestrator/state.json`, runtime compatibility files,
     event schemas, replay behavior, permission/phase-validation behavior,
     deprecation pragmas, public API, or facade removal were changed.
7. If the evidence shows a future migration might be possible for a subset of
   pure generic imports, record it only as a later candidate. Do not implement
   it in this round and do not imply deprecation, removal, or Cabal exposure
   approval.

### Verification
Because this is an evidence-only artifact round, first verify the artifact and
scope:

- `test -f orchestrator/rounds/round-079/implementation-notes.md`
- `test ! -e orchestrator/rounds/round-079/worker-plan.json`
- `git diff -- orchestrator/rounds/round-079/plan.md orchestrator/rounds/round-079/implementation-notes.md`
- `git diff --name-only`
- `git diff --check`

Re-run the focused evidence commands from the steps and ensure the artifact
records their results:

- `rg -n "^ *import +(qualified +)?CodexWatcher\\.Workflow\\.(EventLog|Permission)(\\b| +as +| *$)" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
- `rg -n "^ *import +(qualified +)?CodexWatcher\\.Workflow\\.EventLog\\.(Core|File\\.Core|Commit\\.Core)(\\b| +as +| *$)" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
- `rg -n "^ *import +(qualified +)?CodexWatcher\\.Workflow\\.Permission\\.Core(\\b| +as +| *$)" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
- `rg -n "CodexWatcher\\.Workflow\\.(EventLog|Permission)(\\b|$)|CodexWatcher\\.Workflow\\.EventLog\\.(Core|File\\.Core|Commit\\.Core)|CodexWatcher\\.Workflow\\.Permission\\.Core" moifold.cabal agent-workflow-core/agent-workflow-core.cabal agent-workflow-codex/agent-workflow-codex.cabal agent-workflow-github/agent-workflow-github.cabal examples/workflow-package-consumer/workflow-package-consumer.cabal`
- `rg -n "workflowEventLog|workflow event-log|workflowPermission|workflow permission|phaseActionValidation|phase action|goldenEventLog|golden event|eventLogRepair|replayEventLog" test/Main.hs test/*Spec.hs`

Run `cabal test watcher-core-test` if the implementer edits anything outside
`orchestrator/rounds/round-079/implementation-notes.md` or if the reviewer asks
for a live behavior baseline. Otherwise, record why Cabal tests were not run:
the round is artifact-only and must not modify source/test behavior.

Do not run `git diff --cached --check` unless files are staged. If any command
is blocked by environment or duration, record the exact command and blocker in
the evidence artifact.

Reviewers should specifically confirm:

- `src/CodexWatcher/Workflow/EventLog.hs` and
  `src/CodexWatcher/Workflow/Permission.hs` remain available and unchanged.
- No import migration, wrapper change, Cabal exposure change, docs change,
  deprecation, public API change, facade removal, event schema change, replay
  change, permission/phase-validation change, runtime compatibility file
  change, healthcheck change, or repair change occurred.
- The final decision does not use local import absence or the prior terminal
  hold as removal approval.
- Any `hold` or `defer` decision names concrete blockers and later evidence
  required before migration or removal.

### Worker Fan-Out
No worker fan-out. This is an evidence-only decision round with one artifact
write target and shared verification; do not write `worker-plan.json`.
