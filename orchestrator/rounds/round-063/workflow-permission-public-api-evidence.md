### Scope

This is evidence-only public API review for `CodexWatcher.Workflow.Permission`.
No production source, tests, Cabal descriptors, public docs outside this round,
roadmap files, runtime compatibility files, `orchestrator/project-contract.md`,
or `orchestrator/state.json` were intentionally edited.

### Public API Readback

Source: `src/CodexWatcher/Workflow/Permission.hs`.

Concrete moifold/state-machine API exported by the facade:

- `PhaseActionValidationError (..)`
- `formatPhaseActionValidationError`
- `validateMoifoldEffectPlan`
- `moifoldPermissionPolicy`

Generic permission core reexports:

- `WorkflowEffectPermissionCheck (..)`
- `WorkflowPermissionPolicy (..)`
- `WorkflowPermissionValidationError (..)`
- `formatWorkflowPermissionValidationError`
- `validateWorkflowEffectPlanCore`
- `validateWorkflowEffectPlanWithPolicy`
- `workflowEffectPermissionChecks`
- `workflowEffectPermissionChecksWithPolicy`
- `workflowSpecPermissionPolicy`

Workflow-spec validation bridge:

- `validateWorkflowEffectPlan`

Current implementation ownership readback:

- `src/CodexWatcher/Workflow/Permission.hs` imports
  `CodexWatcher.Workflow.Permission.Core`, `SomeWatcherState`, `EffectPlan`,
  `PhaseActionValidationError`, `validatePhaseActionPlan`, `WorkflowSpec`, and
  `MoifoldSpec`.
- `validateMoifoldEffectPlan` is exactly `validatePhaseActionPlan`.
- `moifoldPermissionPolicy` is `workflowSpecPermissionPolicy @MoifoldSpec`.
- `validateWorkflowEffectPlan` delegates to `workflowValidateEffects @spec`.
- `agent-workflow-core/src/CodexWatcher/Workflow/Permission/Core.hs` owns
  reusable `WorkflowPermissionPolicy`, per-effect permission checks, generic
  validation helpers, and formatting.
- `src/CodexWatcher/StateMachine.hs` remains the concrete moifold
  phase/action permission authority through `validatePhaseActionPlan`.

### Public Exposure

Descriptor readback shows both public modules remain exposed:

- `moifold.cabal:31` starts the main library `exposed-modules` list, and
  `moifold.cabal:128` exposes `CodexWatcher.Workflow.Permission`.
- `agent-workflow-core/agent-workflow-core.cabal:46` starts the core package
  `exposed-modules` list, and `agent-workflow-core/agent-workflow-core.cabal:57`
  exposes `CodexWatcher.Workflow.Permission.Core`.

This round did not change either descriptor.

### Import Inventory

Command:

```sh
rg -n '^ *import +(qualified +)?CodexWatcher\.Workflow\.Permission(\b| +as +| *$| *\()' src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github README.md docs *.cabal */*.cabal
```

Result: exit 0, 2 matching import lines.

```text
test/Main.hs:179:import CodexWatcher.Workflow.Permission qualified as WorkflowPermission
src/CodexWatcher/Workflow/Permission.hs:29:import CodexWatcher.Workflow.Permission.Core
```

Command:

```sh
rg -l '^ *import +(qualified +)?CodexWatcher\.Workflow\.Permission(\b| +as +| *$| *\()' src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github README.md docs *.cabal */*.cabal | sort
```

Result: exit 0, 2 matching files.

```text
src/CodexWatcher/Workflow/Permission.hs
test/Main.hs
```

All planned top-level scan paths exist in this checkout: `src`, `app`, `test`,
`examples`, `agent-workflow-core`, `agent-workflow-codex`,
`agent-workflow-github`, `README.md`, and `docs`.

### Public References And Replacement Evidence

Command:

```sh
rg -n 'CodexWatcher\.Workflow\.Permission|CodexWatcher\.Workflow\.Permission\.Core|validateMoifoldEffectPlan|moifoldPermissionPolicy|WorkflowPermissionPolicy|WorkflowEffectPermissionCheck|WorkflowPermissionValidationError' README.md docs examples *.cabal */*.cabal agent-workflow-core agent-workflow-codex agent-workflow-github src test
```

Reference classification:

- Package exposure: `moifold.cabal:128` exposes
  `CodexWatcher.Workflow.Permission`; `agent-workflow-core/agent-workflow-core.cabal:57`
  exposes `CodexWatcher.Workflow.Permission.Core`.
- Public/package docs: `agent-workflow-core/README.md:45` and
  `docs/agentic-workflow-framework/package-consumer-guide.md:25` name
  `CodexWatcher.Workflow.Permission.Core` as reusable package surface.
- Framework docs: `docs/agentic-workflow-framework/event-log-and-transactions.md:128`
  through `:138`, `implemented-api-freeze.md:42` and `:99`, `monad-dsl.md:91`,
  and `workflow-spec.md:233` document or reference the core permission API.
- Compatibility policy/readiness notes:
  `docs/agentic-workflow-framework/compatibility-deprecation-policy.md:62`,
  `:84`, and `:104` classify `CodexWatcher.Workflow.Permission` as a moifold
  product or adapter facade, recommend `.Permission.Core` for reusable code,
  and defer deprecation/removal until public API, downstream-user, and behavior
  evidence is reviewed.
- Planning docs:
  `docs/agentic-workflow-framework/extraction-plan.md:251` records the earlier
  movement of phase/effect validation naming behind
  `CodexWatcher.Workflow.Permission`.
- Observed imports and test evidence: `test/Main.hs:179` imports the facade,
  `test/Main.hs:8574`, `:8607`, `:8612`, `:8617`, `:8622`, `:14594`,
  `:15262`, and `:15265` exercise facade/core permission behavior.
- Source ownership: `src/CodexWatcher/Workflow/Permission.hs` exports the facade
  names and imports `.Permission.Core`; `agent-workflow-core/src/CodexWatcher/Workflow/Permission/Core.hs`
  defines the reusable policy/check/error API.

Command:

```sh
rg -n 'CodexWatcher\.Workflow\.Permission|CodexWatcher\.Workflow\.Permission\.Core|exposed-modules|other-modules' moifold.cabal agent-workflow-core/agent-workflow-core.cabal
```

Result: exit 0. The descriptor evidence is:

```text
agent-workflow-core/agent-workflow-core.cabal:46:  exposed-modules:
agent-workflow-core/agent-workflow-core.cabal:57:    CodexWatcher.Workflow.Permission.Core
moifold.cabal:31:  exposed-modules:
moifold.cabal:128:    CodexWatcher.Workflow.Permission
moifold.cabal:130:  other-modules:
moifold.cabal:178:  other-modules:
```

### Downstream And Operator Inventory

Repo-local public/package references are available in the files named above.
The checked-in package consumer guide and `agent-workflow-core` README point
generic package users to `CodexWatcher.Workflow.Permission.Core`.

No external downstream checkout or operator confirmation was available in this
round. That is not evidence that removal is safe. Any later deprecation,
facade narrowing, Cabal exposure change, import migration, or removal still
needs explicit selection and reviewer approval with external/operator evidence
or an explicit unsupported-user decision.

### Behavior Evidence

Command:

```sh
rg -n 'workflowPermissionFacadeMatchesStateMachine|workflowPermissionCoreChecksMatchMoifoldPermission|workflowPermissionPolicyMatchesMoifoldPermission|validateWorkflowEffectPlanCore|workflowEffectPermissionChecks' test/Main.hs
```

Result: exit 0. Relevant readback:

- `test/Main.hs:6909` through `:6911` register the three direct permission
  facade/core/policy tests.
- `test/Main.hs:8567` defines `workflowPermissionFacadeMatchesStateMachine`,
  comparing `WorkflowPermission.validateMoifoldEffectPlan` with
  `validatePhaseActionPlan`.
- `test/Main.hs:8577` defines
  `workflowPermissionCoreChecksMatchMoifoldPermission`, comparing
  `validateWorkflowEffectPlanCore @MoifoldSpec` and
  `workflowEffectPermissionChecks @MoifoldSpec` with state-machine validation.
- `test/Main.hs:8596` defines `workflowPermissionPolicyMatchesMoifoldPermission`,
  proving `moifoldPermissionPolicy` accepts allowed moifold effects and rejects
  denied effects like the state machine.
- `test/Main.hs:13523`, `:14673`, `:14675`, `:14681`, `:15053`, `:15055`,
  `:15062`, `:15071`, `:15263`, and `:15265` provide additional indexed,
  DocsMigration, and PR-review permission coverage through
  `validateWorkflowEffectPlanCore` and the facade import.

Focused behavior command attempted:

```sh
cabal test watcher-core-test --test-options='--match /workflow permission/'
```

Result: exit 0. The command built the package/test suite in this worktree and
ended with:

```text
Test suite watcher-core-test: PASS
1 of 1 test suites (1 of 1 test cases) passed.
```

The output also included PASS lines for the named workflow permission behavior
areas, including:

- `workflow planned-transition facade preserves observed event and effects`
- `workflow mergeability planned transition keeps merge effect pre-commit`
- `workflow docs-migration law permission accepts complete draft plan`
- `workflow docs-migration law permission rejects partial draft plan`
- `workflow docs-migration law permission rejects wrong target draft write`
- `indexed docs-migration permissions accept allowed draft plan`
- `indexed docs-migration permissions reject partial draft plan like compatibility`
- `indexed docs-migration permissions reject wrong target plan like compatibility`
- `indexed docs-migration permissions reject disallowed state like compatibility`
- `workflow PR-review mergeability law permission accepts merge from mergeability state`
- `workflow PR-review mergeability law permission rejects merge outside mergeability state`

Because the diff is round-local evidence only, the plan does not require
`cabal build all`, full `cabal test watcher-core-test`, or
`scripts/validate-workflow-packages.sh`.

### Replacement Notes

- Reusable workflow/package code should import
  `CodexWatcher.Workflow.Permission.Core` for generic permission checks,
  policies, validation errors, and formatting.
- Existing moifold code may continue using
  `CodexWatcher.Workflow.Permission` for `validateMoifoldEffectPlan`,
  `moifoldPermissionPolicy`, `PhaseActionValidationError`, and concrete
  state-machine parity.
- `CodexWatcher.Workflow.Permission` is public and is not a pure alias: it
  bridges generic permission helpers to concrete moifold `SomeWatcherState`,
  `EffectPlan`, `PhaseActionValidationError`, `validatePhaseActionPlan`, and
  `MoifoldSpec`.

### Remaining Blockers Before Cleanup

- `CodexWatcher.Workflow.Permission` is publicly exposed in `moifold.cabal`.
- The facade owns concrete moifold bridge API over `SomeWatcherState`,
  `EffectPlan`, `PhaseActionValidationError`, and `MoifoldSpec`.
- `test/Main.hs` imports the facade and uses it for behavior parity evidence.
- External downstream/operator evidence was not available in this round.
- No selected round authorized deprecation, import migration, facade narrowing,
  Cabal exposure change, package publication, upload/release, or removal
  approval.

### Verification Commands

Evidence/readback commands run:

```sh
rg -n '^ *import +(qualified +)?CodexWatcher\.Workflow\.Permission(\b| +as +| *$| *\()' src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github README.md docs *.cabal */*.cabal
rg -l '^ *import +(qualified +)?CodexWatcher\.Workflow\.Permission(\b| +as +| *$| *\()' src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github README.md docs *.cabal */*.cabal | sort
rg -n 'CodexWatcher\.Workflow\.Permission|CodexWatcher\.Workflow\.Permission\.Core|validateMoifoldEffectPlan|moifoldPermissionPolicy|WorkflowPermissionPolicy|WorkflowEffectPermissionCheck|WorkflowPermissionValidationError' README.md docs examples *.cabal */*.cabal agent-workflow-core agent-workflow-codex agent-workflow-github src test
rg -n 'CodexWatcher\.Workflow\.Permission|CodexWatcher\.Workflow\.Permission\.Core|exposed-modules|other-modules' moifold.cabal agent-workflow-core/agent-workflow-core.cabal
rg -n 'workflowPermissionFacadeMatchesStateMachine|workflowPermissionCoreChecksMatchMoifoldPermission|workflowPermissionPolicyMatchesMoifoldPermission|validateWorkflowEffectPlanCore|workflowEffectPermissionChecks' test/Main.hs
cabal test watcher-core-test --test-options='--match /workflow permission/'
```
