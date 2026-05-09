### Goal

Produce source-backed public API evidence for `CodexWatcher.Workflow.Permission` without changing public facades, Cabal exposure, production imports, event/runtime compatibility behavior, roadmap files, or `orchestrator/state.json`.

The round should leave a reviewed evidence artifact under `orchestrator/rounds/round-063/` that reads back the current public exposure, refreshes import/downstream/operator evidence where available, proves concrete permission behavior parity from existing tests or explicit manual evidence, records replacement and ownership notes, and names blockers before any later deprecation, facade narrowing, import migration, or removal decision.

### Approach

Keep the work sequential. This is one public API surface whose import scan, Cabal exposure, concrete moifold behavior, generic replacement path, downstream/operator availability, and blocker conclusion should be reconciled into one consistent evidence record.

Use `orchestrator/project-contract.md` for stable package-boundary, compatibility-facade, permission-soundness, and no-incidental-removal invariants. Use the active verification bundle's `CodexWatcher.Workflow.Permission` check as the acceptance gate: public API exposure and concrete permission behavior are first-class gates.

The expected implementation output is a round-local evidence artifact, preferably `orchestrator/rounds/round-063/workflow-permission-public-api-evidence.md`, plus normal implementation notes. Do not add deprecation pragmas, remove or narrow facade exports, change Cabal exposed modules, migrate production imports, change event/runtime compatibility files, update publication policy, upload/release packages, or claim removal approval.

At planning time the current shape is:

- `src/CodexWatcher/Workflow/Permission.hs` is a main-library public facade exposed by `moifold.cabal`.
- It reexports reusable permission helpers from `CodexWatcher.Workflow.Permission.Core`.
- It adds concrete moifold permission API through `validateMoifoldEffectPlan :: SomeWatcherState -> EffectPlan -> Either PhaseActionValidationError ()`, `moifoldPermissionPolicy :: WorkflowPermissionPolicy MoifoldSpec`, and `validateWorkflowEffectPlan` over `WorkflowSpec`.
- `agent-workflow-core/agent-workflow-core.cabal` exposes `CodexWatcher.Workflow.Permission.Core` as the reusable replacement import for generic permission policy/check machinery.
- The implementer must refresh these facts from the current tree and prefer current evidence over this planning snapshot.

### Steps

1. Create one evidence artifact, `orchestrator/rounds/round-063/workflow-permission-public-api-evidence.md`.
2. Read back the current public API surface from `src/CodexWatcher/Workflow/Permission.hs`. Record every exported name, grouping exports as:
   - concrete moifold/state-machine API: `PhaseActionValidationError`, `formatPhaseActionValidationError`, `validateMoifoldEffectPlan`, and `moifoldPermissionPolicy`;
   - generic permission core reexports: `WorkflowEffectPermissionCheck`, `WorkflowPermissionPolicy`, `WorkflowPermissionValidationError`, `formatWorkflowPermissionValidationError`, `validateWorkflowEffectPlanCore`, `validateWorkflowEffectPlanWithPolicy`, `workflowEffectPermissionChecks`, `workflowEffectPermissionChecksWithPolicy`, and `workflowSpecPermissionPolicy`;
   - workflow-spec validation bridge: `validateWorkflowEffectPlan`.
3. Prove public exposure without changing descriptors. Read back `moifold.cabal` and `agent-workflow-core/agent-workflow-core.cabal` to show that the moifold library exposes `CodexWatcher.Workflow.Permission` and `agent-workflow-core` exposes `CodexWatcher.Workflow.Permission.Core`.
4. Refresh the anchored recursive import inventory for the facade across source, tests, examples, package candidates, docs, README files, Cabal descriptors, and app files when present:

   ```sh
   rg -n '^ *import +(qualified +)?CodexWatcher\.Workflow\.Permission(\b| +as +| *$| *\()' src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github README.md docs *.cabal */*.cabal
   rg -l '^ *import +(qualified +)?CodexWatcher\.Workflow\.Permission(\b| +as +| *$| *\()' src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github README.md docs *.cabal */*.cabal | sort
   ```

   Record the command, current count, and file list. If a path such as `app` is absent, record that and rerun over the existing path set. At planning time the facade import appears in `test/Main.hs`; the implementation must refresh the count from the current tree.
5. Refresh replacement and public-reference evidence:

   ```sh
   rg -n 'CodexWatcher\.Workflow\.Permission|CodexWatcher\.Workflow\.Permission\.Core|validateMoifoldEffectPlan|moifoldPermissionPolicy|WorkflowPermissionPolicy|WorkflowEffectPermissionCheck|WorkflowPermissionValidationError' README.md docs examples *.cabal */*.cabal agent-workflow-core agent-workflow-codex agent-workflow-github src test
   rg -n 'CodexWatcher\.Workflow\.Permission|CodexWatcher\.Workflow\.Permission\.Core|exposed-modules|other-modules' moifold.cabal agent-workflow-core/agent-workflow-core.cabal
   ```

   Classify references as public/package docs, package exposure, observed imports, test evidence, replacement guidance, or policy/readiness notes.
6. Record downstream/operator inventory honestly. Use repo-local docs, examples, package consumer examples, README files, and any checked-in operator/runbook references available in this checkout. If no external downstream checkout or operator confirmation is available, record it as unavailable or blocked on operator approval, not as evidence that removal is safe.
7. Read back implementation ownership:
   - `src/CodexWatcher/Workflow/Permission.hs` owns the moifold-facing compatibility bridge to `SomeWatcherState`, `EffectPlan`, `PhaseActionValidationError`, `validatePhaseActionPlan`, and `MoifoldSpec`.
   - `agent-workflow-core/src/CodexWatcher/Workflow/Permission/Core.hs` owns reusable `WorkflowSpec` permission policy records, per-effect permission reports, generic validation, and error formatting.
   - `src/CodexWatcher/StateMachine.hs` remains the concrete phase/action permission authority for moifold watcher states.
8. Prove concrete permission behavior parity from existing tests or explicit manual evidence. Include current readback for:
   - `workflowPermissionFacadeMatchesStateMachine`, which compares `WorkflowPermission.validateMoifoldEffectPlan` with `validatePhaseActionPlan`;
   - `workflowPermissionCoreChecksMatchMoifoldPermission`, which compares generic core errors/checks with moifold state-machine validation;
   - `workflowPermissionPolicyMatchesMoifoldPermission`, which verifies `moifoldPermissionPolicy` accepts allowed moifold effects and rejects denied ones like the state machine;
   - any indexed workflow or DocsMigration permission tests that exercise `validateWorkflowEffectPlanCore` or permission checks through `CodexWatcher.Workflow.Permission`.
9. Run a focused behavior test only if the round remains artifact-only and the local environment can do it cheaply; otherwise record exact test coverage readback as manual evidence. Preferred focused command:

   ```sh
   cabal test watcher-core-test --test-options='--match /workflow permission/'
   ```

   If the matcher is not accepted by the test runner, rerun the narrowest accepted matcher(s) for the three named `workflowPermission*` tests and record the exact command and result. Do not broaden to full baseline unless the diff escapes round-local artifacts or the reviewer requires it.
10. Record replacement notes conservatively:
   - reusable workflow/package code should import `CodexWatcher.Workflow.Permission.Core` for generic permission checks and policies;
   - existing moifold code may continue using `CodexWatcher.Workflow.Permission` for `validateMoifoldEffectPlan`, `moifoldPermissionPolicy`, `PhaseActionValidationError`, and concrete state-machine parity;
   - the facade is public and not a pure alias because it bridges concrete moifold permission behavior.
11. Record remaining blockers before any later cleanup decision. Expected blockers include public exposure in `moifold.cabal`, concrete `SomeWatcherState`/`EffectPlan`/`MoifoldSpec` ownership, existing test imports through the facade, downstream/operator evidence unavailable or unapproved, and no selected round authorizing deprecation, import migration, facade narrowing, Cabal exposure change, or removal approval.
12. Keep the implementation diff limited to round-local evidence artifacts and implementation notes. Do not edit source modules, tests, docs outside the round, Cabal descriptors, runtime compatibility files, roadmap files, `orchestrator/project-contract.md`, `orchestrator/state.json`, review artifacts, or merge artifacts.

### Verification

Run artifact and scope checks:

```sh
git diff --name-only
git status --short
git diff --check
```

The changed files should be limited to `orchestrator/rounds/round-063/plan.md`, `orchestrator/rounds/round-063/workflow-permission-public-api-evidence.md`, and the round-level implementation notes produced by the implementer. If any production source, tests, public docs outside the round, Cabal descriptors, roadmap files, runtime compatibility files, `orchestrator/project-contract.md`, or `orchestrator/state.json` change, the round has escaped this plan.

Run the evidence scans and include refreshed output summaries in the evidence artifact or implementation notes:

```sh
rg -n '^ *import +(qualified +)?CodexWatcher\.Workflow\.Permission(\b| +as +| *$| *\()' src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github README.md docs *.cabal */*.cabal
rg -l '^ *import +(qualified +)?CodexWatcher\.Workflow\.Permission(\b| +as +| *$| *\()' src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github README.md docs *.cabal */*.cabal | sort
rg -n 'CodexWatcher\.Workflow\.Permission|CodexWatcher\.Workflow\.Permission\.Core|validateMoifoldEffectPlan|moifoldPermissionPolicy|WorkflowPermissionPolicy|WorkflowEffectPermissionCheck|WorkflowPermissionValidationError' README.md docs examples *.cabal */*.cabal agent-workflow-core agent-workflow-codex agent-workflow-github src test
rg -n 'CodexWatcher\.Workflow\.Permission|CodexWatcher\.Workflow\.Permission\.Core|exposed-modules|other-modules' moifold.cabal agent-workflow-core/agent-workflow-core.cabal
rg -n 'workflowPermissionFacadeMatchesStateMachine|workflowPermissionCoreChecksMatchMoifoldPermission|workflowPermissionPolicyMatchesMoifoldPermission|validateWorkflowEffectPlanCore|workflowEffectPermissionChecks' test/Main.hs
```

Because this is evidence-only, the implementer may skip `cabal build all`, `cabal test watcher-core-test`, and `scripts/validate-workflow-packages.sh` only if the diff remains limited to round-local orchestrator artifacts. If the diff touches production code, tests, package descriptors, public docs, scripts, runtime compatibility files, or Cabal exposure, require the full baseline from `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/verification.md`:

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
