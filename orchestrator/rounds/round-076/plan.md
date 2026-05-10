### Goal
Classify the four selected compatibility facades by behavior ownership using only round-075 evidence and current wrapper-module reads:

- `CodexWatcher.AppServerClient`
- `CodexWatcher.Core.Ids`
- `CodexWatcher.Workflow.EventLog`
- `CodexWatcher.Workflow.Permission`

The output for this round is an evidence-only classification record in `orchestrator/rounds/round-076/implementation-notes.md`. It must not change production code, imports, Cabal exposure, roadmap files, runtime compatibility files, event schemas, healthcheck/repair behavior, deprecation state, or removal state.

### Approach
Use `orchestrator/rounds/round-075/implementation-notes.md` as the source for current import counts, replacement mappings, Cabal exposure, docs references, blocker classes, and protecting checks. Re-read the four wrapper modules to confirm whether each selected facade is pure reexport, moifold behavior bridge, or mixed surface.

Classify each facade with a short owner rationale:

- `CodexWatcher.AppServerClient`: pure reexport convenience facade over `CodexWatcher.Workflow.Agent.Codex.Client` and `CodexWatcher.Workflow.Agent.Codex.Transport`; note that app-server protocol behavior belongs to the Codex agent adapter modules, while the existing facade still has broad moifold import and compatibility exposure.
- `CodexWatcher.Core.Ids`: pure reexport convenience facade over `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`; note that this is adapter-id convenience, not one behavior owner, because agent ids and GitHub ids split across different package owners.
- `CodexWatcher.Workflow.EventLog`: mixed surface; generic replay/audit helpers belong to workflow core/audit modules, while `initializeMoifoldWorkflow`, `applyMoifoldWorkflowEvent`, and `replayMoifoldWorkflowEvents` are concrete moifold behavior bridges tied to `WatcherEvent`, `SomeWatcherState`, `EffectPlan`, and `MoifoldSpec`.
- `CodexWatcher.Workflow.Permission`: mixed surface; reusable permission checks belong to `CodexWatcher.Workflow.Permission.Core`, while `validateMoifoldEffectPlan`, `moifoldPermissionPolicy`, `PhaseActionValidationError`, and phase-action formatting are concrete moifold phase-validation behavior tied to the state machine and `MoifoldSpec`.

Keep the classification descriptive, not prescriptive. Do not recommend import migrations, deprecations, exposure changes, or removals in this round; only record what ownership evidence the later readiness and policy rounds must respect.

### Steps
1. Confirm the active context still matches `round-076`, roadmap `2026-05-10-00-facade-removal-readiness`, revision `rev-001`, and stage `plan`/implementation handoff expectations.
2. Re-read `orchestrator/rounds/round-075/implementation-notes.md` and extract only the evidence needed for the four selected facades: facade shape, import counts, replacement mapping, Cabal exposure, non-import references, blocker class, and protecting checks.
3. Re-read the four wrapper modules and classify each facade as one of:
   - `pure reexport`
   - `moifold behavior bridge`
   - `mixed surface`
4. Write `orchestrator/rounds/round-076/implementation-notes.md` with:
   - an active input confirmation;
   - commands run;
   - an explicit statement that only round-local artifact evidence changed;
   - a classification table for the four facades;
   - per-facade evidence notes covering owner modules, moifold behavior, adapter-id convenience, import/exposure blockers, and protecting checks;
   - out-of-scope confirmation for `CodexWatcher.Workflow.Types`, `CodexWatcher.Workflow.Execution`, runtime compatibility files, event JSON, healthcheck, repair, release, and publication decisions.
5. Do not create `worker-plan.json`; this round is sequential and evidence-only.
6. Do not edit roadmap files, production source, package descriptors, docs, tests, or compatibility files.

### Verification
Artifact verification is enough if the implementation changes only `orchestrator/rounds/round-076/implementation-notes.md`.

Review checks:

- `git diff -- orchestrator/rounds/round-076/plan.md orchestrator/rounds/round-076/implementation-notes.md`
- `git status --short`
- Confirm no `worker-plan.json` exists for round 076.
- Confirm the classification record cites round-075 evidence and the wrapper-module reads for all four facades.
- Confirm no production source, Cabal file, docs, roadmap file, runtime compatibility file, event schema, healthcheck/repair path, deprecation state, or removal state changed.

Do not run `cabal build all` or `cabal test watcher-core-test` for this artifact-only evidence round unless implementation escapes the round-local artifact boundary.
