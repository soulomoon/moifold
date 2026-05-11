### Goal

Record current artifact-only readiness evidence for
`CodexWatcher.Workflow.EventLog` and `CodexWatcher.Workflow.Permission` so a
later convergence or removal round can distinguish reusable direct-owner
imports from product-owned moifold bridge behavior and test-policy evidence.

This round does not change source, tests, package descriptors, fixtures, docs,
roadmap files, controller state, public APIs, event schemas, permission
behavior, replay behavior, Cabal exposure, or compatibility facade
availability.

### Approach

Produce one round-local evidence artifact for
`round-104-eventlog-permission-bridge-split-readiness`. Re-read the active
selection, roadmap verification bundle, project contract, round-097 facade
scan, and round-103 closeout context; then run live scans over the current
worktree and classify only the observed uses.

The classification should separate:

- `direct-owner reusable core/audit candidate`: uses that can later target
  `CodexWatcher.Workflow.EventLog.Core`,
  `CodexWatcher.Workflow.EventLog.File.Core`,
  `CodexWatcher.Workflow.EventLog.Commit.Core`,
  `CodexWatcher.Workflow.Audit`, or
  `CodexWatcher.Workflow.Permission.Core` without depending on moifold
  lifecycle policy.
- `product-owned moifold wrapper`: uses of `initializeMoifoldWorkflow`,
  `applyMoifoldWorkflowEvent`, `replayMoifoldWorkflowEvents`,
  `validateMoifoldEffectPlan`, `moifoldPermissionPolicy`, phase/state
  validation helpers, or other concrete `MoifoldSpec` bridge behavior that
  must remain in the main moifold package unless later evidence proves a
  different owner.
- `permission-policy helper`: permission checks, permission policy values,
  effect-plan validation, and formatted permission errors that may be reusable
  only when they stay spec-parametric and do not pull in moifold state-machine
  policy.
- `test-policy evidence`: test imports that intentionally preserve facade
  coverage, public import policy, golden replay, old-log parsing, event JSON
  `type` stability, transition/replay parity, permission soundness,
  phase-validation, state/effect validation, and wrapper behavior evidence.
- `public exposure/downstream evidence`: Cabal exposed-module entries,
  standalone package exposure, documentation or policy references, and any
  downstream import surface that must be checked before later public API,
  deprecation, or removal work.

Do not create `worker-plan.json`. The work is a serial evidence inventory with
one owned artifact and no non-overlapping implementation work.

### Steps

1. Confirm starting coordination state and scope:
   - Read `orchestrator/state.json`.
   - Read `orchestrator/rounds/round-104/selection.md`.
   - Read `orchestrator/project-contract.md`.
   - Read
     `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`.
   - Read `orchestrator/rounds/round-097/facade-import-scan-refresh.md`.
   - Read round-103 artifacts needed to confirm the prior `Core.Ids` queue is
     closed before this bridge-readiness direction.
   - Run `git status --short` and `git diff --name-status`; record that only
     round-local artifacts are changed by this implementation, aside from any
     pre-existing controller-owned state movement.

2. Run the current exact import scan for the two selected facades:

   ```sh
   rg -n '^import[[:space:]]+(qualified[[:space:]]+)?CodexWatcher\.Workflow\.(EventLog|Permission)([[:space:]]|$|\()' \
     src app test agent-workflow-core agent-workflow-codex agent-workflow-github
   ```

   Record exact counts by area: `src`, `app`, `test`,
   `agent-workflow-core`, `agent-workflow-codex`, and
   `agent-workflow-github`. Record every importing file and whether it imports
   `EventLog`, `Permission`, or both.

3. Run a broader reference scan to catch non-import policy, descriptor, and
   downstream evidence:

   ```sh
   rg -n 'CodexWatcher\.Workflow\.(EventLog|Permission)([[:space:]]|$|\.|\(|")' \
     src app test agent-workflow-core agent-workflow-codex agent-workflow-github \
     docs examples scripts moifold.cabal agent-workflow-core/agent-workflow-core.cabal \
     agent-workflow-codex/agent-workflow-codex.cabal \
     agent-workflow-github/agent-workflow-github.cabal cabal.project
   ```

   Classify matches as live imports, package exposure, package-candidate
   direct-owner exposure, docs/policy references, or test import-policy
   assertions.

4. Run the direct-owner and bridge-module exposure scan:

   ```sh
   rg -n 'CodexWatcher\.Workflow\.(Audit|EventLog\.(Core|File\.Core|Commit\.Core)|Permission\.Core)|CodexWatcher\.Workflow\.(EventLog|Permission)|exposed-modules:' \
     src app test agent-workflow-core agent-workflow-codex agent-workflow-github \
     moifold.cabal agent-workflow-core/agent-workflow-core.cabal \
     agent-workflow-codex/agent-workflow-codex.cabal \
     agent-workflow-github/agent-workflow-github.cabal cabal.project
   ```

   Record that `moifold.cabal` still exposes
   `CodexWatcher.Workflow.EventLog` and
   `CodexWatcher.Workflow.Permission`, and that
   `agent-workflow-core` exposes the reusable owner modules without importing
   the compatibility facades.

5. Inspect the export lists of
   `src/CodexWatcher/Workflow/EventLog.hs` and
   `src/CodexWatcher/Workflow/Permission.hs`. For each exported symbol group,
   classify it as reusable direct-owner core/audit, product-owned moifold
   wrapper, permission-policy helper, or concrete phase/state validation
   bridge. Record any mixed export group that blocks mechanical import
   convergence.

6. For each live importer from step 2, inspect the local use sites enough to
   classify the file:
   - `src` users: distinguish direct-owner candidates from concrete moifold
     wrappers, event-log/replay behavior, daemon/runtime bridge behavior, and
     phase/state validation.
   - `app` users: record any CLI/public entrypoint exposure if present.
   - `test` users: classify as facade policy, golden replay, old-log parsing,
     event JSON `type` stability, transition/replay parity, wrapper behavior,
     permission soundness, phase-validation, state/effect validation, or
     downstream/public API evidence.
   - standalone package users: record any facade import as a package-boundary
     blocker; expected result is no facade imports.

7. Name the verification gates required before any later convergence, public
   exposure, Cabal exposure, or removal work:
   - golden replay coverage for affected workflows and fixtures;
   - old-log parsing across current compatibility fixtures;
   - stable `WatcherEvent` JSON `type` fields and parse behavior;
   - transition/replay parity for initialized and applied workflow events;
   - moifold wrapper behavior for `initializeMoifoldWorkflow`,
     `applyMoifoldWorkflowEvent`, `replayMoifoldWorkflowEvents`,
     `validateMoifoldEffectPlan`, and `moifoldPermissionPolicy`;
   - permission soundness for allowed and denied effects;
   - phase-validation error behavior and formatting;
   - state/effect validation behavior before interpretation;
   - public API, Cabal exposure, docs/Haddock, and downstream import evidence
     for the exact surface later moved or removed.

8. Write the evidence artifact under `orchestrator/rounds/round-104/`,
   keeping it explicit that this round is readiness evidence only and is not
   deprecation, import migration, package exposure change, facade removal,
   milestone completion, release approval, or terminal completion.

9. Confirm no worker fan-out artifact exists:

   ```sh
   test ! -e orchestrator/rounds/round-104/worker-plan.json
   ```

10. Run changed-path and descriptor hygiene checks:

   ```sh
   git diff -- src app test moifold.cabal cabal.project \
     agent-workflow-core agent-workflow-codex agent-workflow-github
   git diff -- moifold.cabal agent-workflow-core/agent-workflow-core.cabal \
     agent-workflow-codex/agent-workflow-codex.cabal \
     agent-workflow-github/agent-workflow-github.cabal cabal.project
   git diff --check
   git diff --cached --check
   ```

### Verification

The implementer should verify the artifact by re-running the exact scans above
and checking that:

- the evidence artifact records exact live import counts for
  `CodexWatcher.Workflow.EventLog` and
  `CodexWatcher.Workflow.Permission` across `src`, `app`, `test`, and
  standalone package candidates;
- every live importer is classified as direct-owner reusable core/audit,
  product-owned moifold wrapper or permission-policy helper, concrete
  phase/state validation bridge, test-policy evidence, or public
  exposure/downstream evidence;
- the artifact names the later gates for golden replay, old-log parsing, event
  JSON `type` stability, transition/replay parity, wrapper behavior,
  permission soundness, phase-validation, state/effect validation, and public
  API/downstream evidence;
- `CodexWatcher.Workflow.EventLog` and
  `CodexWatcher.Workflow.Permission` remain exposed and available;
- no source, test, app, package descriptor, fixture, docs, roadmap,
  controller-state, public API, event-schema, replay, permission, runtime
  behavior, or Cabal exposure change is made by this round;
- `worker-plan.json` is absent; and
- `git diff --check` passes.

Because this is artifact-only, `cabal build all` and
`cabal test watcher-core-test` may be skipped only if changed-path evidence
shows the diff is limited to round-local orchestrator artifacts.
