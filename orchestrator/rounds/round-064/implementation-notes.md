### Changes Made
- `orchestrator/rounds/round-064/planning-state-fixture-policy.md`: added the round-local evidence artifact for `planning-state.json`, including producer readback, healthcheck readback, explicit non-healthcheck policy, existing behavior-test coverage, and blockers.
- `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`: added round 064 as a durable policy evidence pointer while preserving the `defer` classification.

### Tests
- `find . -name 'planning-state.json' -print`: passed with no output; no checked-in `planning-state.json` fixture exists in this worktree.
- `rg -n "planning-state\\.json|RecordPlanningGraph|PlanningWaitingForReadyIssues|compatibilityStateWrites|stateFileSpecs|sharedStateFiles" src/CodexWatcher/EffectInterpreter.hs src/CodexWatcher/Runtime/Compatibility.hs src/CodexWatcher/AutomaticLoop/IssuePlanningFanout.hs src/CodexWatcher/Healthcheck.hs test/Main.hs docs/agentic-workflow-framework/compatibility-deprecation-policy.md orchestrator/rounds/round-064`: passed; confirmed direct `RecordPlanningGraph` writes, compatibility projection writes, fanout compatibility writes, healthcheck state-file specs, existing test coverage, and policy/round references.
- `rg -n "planning-state\\.json|defer|non-healthcheck|healthcheck|fixture|external operator|downstream|removal|migration" docs/agentic-workflow-framework/compatibility-deprecation-policy.md orchestrator/rounds/round-064`: passed; confirmed `planning-state.json` remains `defer`, round 064 records explicit non-healthcheck policy, and blockers remain documented.
- `git diff --name-only`: passed; tracked diff is limited to `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`. New round artifacts are untracked until staging.
- `git diff --check`: passed with no output.
- `git status --short`: shows `M docs/agentic-workflow-framework/compatibility-deprecation-policy.md` and untracked `orchestrator/rounds/round-064/`.
- `rg -n "[ \\t]+$" orchestrator/rounds/round-064/planning-state-fixture-policy.md orchestrator/rounds/round-064/implementation-notes.md docs/agentic-workflow-framework/compatibility-deprecation-policy.md`: passed with no trailing-whitespace matches.

### Notes
No production source, tests, fixtures, schemas, roadmap files, controller state, selection/plan/review artifacts, or runtime behavior changed.

The current evidence preserves conservative classification: `planning-state.json` is a write-only compatibility projection today, has behavior-test coverage for current writes, has no checked-in state-file fixture, has no healthcheck reader, and still lacks external operator/downstream direct-reader inventory.

Cabal/package baselines were skipped under the artifact/docs-only allowance because the diff is limited to the selected round artifacts plus the optional compatibility policy pointer.
