### Goal
Refresh the current, scan-backed evidence for the selected compatibility facades:
`CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`,
`CodexWatcher.Workflow.EventLog`, and `CodexWatcher.Workflow.Permission`.
The round should produce the shared evidence base needed by later readiness,
migration, policy, or removal/hold decisions under roadmap
`2026-05-10-00-facade-removal-readiness` revision `rev-001`.

### Approach
Keep this round evidence-only and sequential. Record current imports, direct
references, Cabal exposure, docs/README references, replacement candidates,
protecting tests, downstream/operator inventory scope, and remaining blocker
class for each selected facade. Reference `orchestrator/project-contract.md`
for repo-wide compatibility invariants instead of restating them.

Do not edit production source, app, test, Cabal, docs, README, roadmap, or
runtime compatibility files. Do not migrate imports, add deprecation pragmas,
change exposed modules, remove facades, change event schemas, or touch
healthcheck/repair behavior.

### Steps
1. Re-read the active inputs: `orchestrator/rounds/round-075/selection.md`,
   `orchestrator/state.json`, `orchestrator/project-contract.md`, and
   `orchestrator/roadmaps/2026-05-10-00-facade-removal-readiness/rev-001/verification.md`.
   Confirm the active round remains `round-075` and the roadmap lineage remains
   `2026-05-10-00-facade-removal-readiness` `rev-001`.
2. Run a fresh selected-facade scan over source, app, test, Cabal, docs, README,
   package candidates, and examples. Use a command equivalent to:
   `rg -n "^module CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.(EventLog|Permission))\\b|import (qualified )?CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.(EventLog|Permission))\\b|CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.(EventLog|Permission))" src app test docs README.md *.cabal agent-workflow-* examples`.
3. For each selected facade, record the current module definition file, direct
   import sites, non-import references, Cabal exposure lines, docs/README
   references, and whether references are in moifold code, package-candidate
   code, examples, tests, or operator-facing docs.
4. Build a replacement mapping from the current facade exports and existing
   policy evidence:
   `CodexWatcher.AppServerClient` maps to
   `CodexWatcher.Workflow.Agent.Codex.Client` and
   `CodexWatcher.Workflow.Agent.Codex.Transport`;
   `CodexWatcher.Core.Ids` maps to `CodexWatcher.Workflow.Agent.Ids` and
   `CodexWatcher.Workflow.GitHub.Ids`;
   `CodexWatcher.Workflow.EventLog` maps only its generic helpers to
   `CodexWatcher.Workflow.EventLog.Core`,
   `CodexWatcher.Workflow.EventLog.File.Core`,
   `CodexWatcher.Workflow.EventLog.Commit.Core`, and
   `CodexWatcher.Workflow.Audit`, while noting its moifold-specific replay and
   initialization helpers as blockers;
   `CodexWatcher.Workflow.Permission` maps only reusable permission checks to
   `CodexWatcher.Workflow.Permission.Core`, while noting concrete moifold phase
   validation helpers as blockers.
5. Record protecting tests and focused follow-up checks for each facade class:
   app-server protocol/failure rendering for `AppServerClient`; parser/rendering
   coverage for ids in `Core.Ids`; replay/golden/event-log coverage for
   `Workflow.EventLog`; permission and phase-validation coverage for
   `Workflow.Permission`.
6. Record the downstream/operator inventory scope explicitly. Treat local
   absence of imports outside the scan as incomplete evidence unless the
   implementation notes name the inspected surfaces and say what was not
   inspected.
7. Write the implementation evidence in
   `orchestrator/rounds/round-075/implementation-notes.md` only. Include the
   exact scan commands, summarized results by facade, replacement mapping,
   blocker class, and a statement that no production/source/Cabal/docs/runtime
   compatibility files were changed.
8. Leave roadmap files and `worker-plan.json` untouched. If the scan reveals
   scope that cannot be handled sequentially, stop and replan instead of
   silently creating fan-out.

### Verification
Because the intended implementation changes only round-local evidence
artifacts, verification is artifact-focused:

- `git diff --check`
- `git status --short`
- Manual review that the only intended changed implementation artifact is
  `orchestrator/rounds/round-075/implementation-notes.md`, alongside this
  planner artifact.
- Manual review that the evidence names all four selected facades, includes
  source/app/test/Cabal/docs/README/package-candidate/example scan scope, records
  current imports and direct references, maps preferred replacement modules, and
  states the remaining blocker class.
- Manual review that no roadmap file, production source, app, test, Cabal,
  docs, README, runtime compatibility file, event schema, healthcheck behavior,
  repair behavior, deprecation pragma, or facade exposure was changed.

Do not run `cabal build all` or `cabal test watcher-core-test` for artifact-only
evidence edits unless the implementation touches code, package descriptors,
exposed modules, README/Haddock wording, or source-distribution metadata.
