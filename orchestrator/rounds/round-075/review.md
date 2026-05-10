### Checks Run
- Command: `sed -n '1,240p' orchestrator/roles/reviewer.md`
  Result: pass. Loaded the reviewer role and confirmed the review-only boundaries, required `review.md` structure, and approval record requirements.
- Command: `sed -n '1,260p' orchestrator/rounds/round-075/selection.md`
  Result: pass. Selection names roadmap `2026-05-10-00-facade-removal-readiness`, revision `rev-001`, milestone `milestone-001-current-facade-evidence`, direction `direction-001-import-scan-refresh`, and extracted item `round-075-import-scan-refresh`.
- Command: `sed -n '1,260p' orchestrator/rounds/round-075/plan.md`
  Result: pass. Plan limits this round to evidence artifacts and explicitly says not to run `cabal build all` or `cabal test watcher-core-test` unless code, package descriptors, exposed modules, README/Haddock wording, or source-distribution metadata were touched.
- Command: `sed -n '1,320p' orchestrator/rounds/round-075/implementation-notes.md`
  Result: pass. Implementation notes record all four selected facades, scan scope, replacement mappings, blocker classes, protecting checks, and the statement that no production/source/Cabal/docs/runtime compatibility files were changed.
- Command: `sed -n '1,220p' orchestrator/state.json`
  Result: pass. State confirms active round `round-075`, stage `review`, roadmap `2026-05-10-00-facade-removal-readiness`, revision `rev-001`, and worktree `orchestrator/worktrees/round-075`.
- Command: `sed -n '1,260p' orchestrator/project-contract.md`
  Result: pass. Contract confirms public compatibility facades must remain available until safe removal is proven and that the prior compatibility cleanup hold is not deprecation, migration, Cabal exposure, or removal approval.
- Command: `sed -n '1,260p' orchestrator/roadmaps/2026-05-10-00-facade-removal-readiness/rev-001/verification.md`
  Result: pass. Verification lists baseline checks and alignment checks; the cabal baseline is intentionally waived here under the round plan because only round-local orchestrator artifacts changed.
- Command: `git status --short`
  Result: pass. The only changed path set is the untracked round artifact directory `orchestrator/rounds/round-075/`; no production source, app, test, Cabal, docs, README, roadmap, runtime compatibility, healthcheck, or repair files are modified.
- Command: `git diff --name-only -- orchestrator/rounds/round-075 && git ls-files --others --exclude-standard orchestrator/rounds/round-075`
  Result: pass. There are no tracked diffs; untracked round files before review were `selection.md`, `plan.md`, and `implementation-notes.md`.
- Command: `git diff --check`
  Result: pass. No whitespace errors in tracked diffs; there are no tracked diffs.
- Command: `git diff --cached --check`
  Result: pass. No staged diff exists and no staged whitespace errors were reported.
- Command: `git diff --no-index --check -- /dev/null orchestrator/rounds/round-075/selection.md`
  Result: pass for whitespace. Command exits nonzero because `/dev/null` differs from the file, with no whitespace-error output.
- Command: `git diff --no-index --check -- /dev/null orchestrator/rounds/round-075/plan.md`
  Result: pass for whitespace. Command exits nonzero because `/dev/null` differs from the file, with no whitespace-error output.
- Command: `git diff --no-index --check -- /dev/null orchestrator/rounds/round-075/implementation-notes.md`
  Result: pass for whitespace. Command exits nonzero because `/dev/null` differs from the file, with no whitespace-error output.
- Command: `rg -n "^module CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(EventLog|Permission))\b|import (qualified )?CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(EventLog|Permission))\b|CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(EventLog|Permission))" src app test docs README.md *.cabal agent-workflow-* examples`
  Result: pass. Live scan confirms definitions, Cabal exposures, docs references, package-candidate references, and direct selected-facade import sites across the planned scope.
- Command: `rg -n "^import (qualified )?CodexWatcher\.AppServerClient\b" src app test agent-workflow-* examples | wc -l`
  Result: pass. Output: `28`, matching the implementation notes.
- Command: `rg -n "^import (qualified )?CodexWatcher\.Core\.Ids\b" src app test agent-workflow-* examples | wc -l`
  Result: pass. Output: `65`, matching the implementation notes.
- Command: `rg -n "^import (qualified )?CodexWatcher\.Workflow\.EventLog(\s|$)" src app test agent-workflow-* examples | wc -l`
  Result: pass. Output: `3`, matching the implementation notes.
- Command: `rg -n "^import (qualified )?CodexWatcher\.Workflow\.Permission(\s|$)" src app test agent-workflow-* examples | wc -l`
  Result: pass. Output: `1`, matching the implementation notes.
- Command: `sed -n '1,140p' src/CodexWatcher/AppServerClient.hs`
  Result: pass. Confirms `CodexWatcher.AppServerClient` reexports `CodexWatcher.Workflow.Agent.Codex.Client` and `CodexWatcher.Workflow.Agent.Codex.Transport`.
- Command: `sed -n '1,120p' src/CodexWatcher/Core/Ids.hs`
  Result: pass. Confirms `CodexWatcher.Core.Ids` reexports `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`.
- Command: `sed -n '1,180p' src/CodexWatcher/Workflow/EventLog.hs`
  Result: pass. Confirms the mixed facade shape: generic event-log/audit helpers plus moifold-specific initialize/apply/replay helpers.
- Command: `sed -n '1,160p' src/CodexWatcher/Workflow/Permission.hs`
  Result: pass. Confirms the mixed facade shape: reusable permission core plus concrete moifold phase-validation helpers.

`cabal build all` and `cabal test watcher-core-test` were not run. This is justified by the round plan and actual diff: the integrated result is artifact-only evidence under `orchestrator/rounds/round-075/`, with no code, package descriptor, exposed-module, README/Haddock, source-distribution, runtime compatibility, event schema, healthcheck, or repair change. Running the cabal baselines would not validate a touched behavior surface for this round.

### Plan Compliance
- Re-read active inputs: met. Reviewer read selection, state, project contract, active verification, plan, and implementation notes. Active round and roadmap lineage match `round-075` / `2026-05-10-00-facade-removal-readiness` `rev-001`.
- Fresh selected-facade scan: met. Reviewer reran the combined scan over `src`, `app`, `test`, `docs`, `README.md`, `*.cabal`, `agent-workflow-*`, and `examples`.
- Record current evidence for each selected facade: met. Implementation notes include module definition, direct import count and location class, non-import references, Cabal exposure, inspected surfaces, and uninspected downstream/operator scope.
- Replacement mapping: met. Notes map `AppServerClient` to Codex client/transport modules, `Core.Ids` to agent and GitHub ids, `Workflow.EventLog` generic helpers to event-log/audit core modules while naming moifold-specific blockers, and `Workflow.Permission` reusable checks to permission core while naming moifold phase-validation blockers.
- Protecting tests and follow-up checks: met. Notes record focused follow-up checks for app-server protocol/failure rendering, id parsing/rendering, replay/golden/event-log behavior, and permission/phase-validation behavior.
- Downstream/operator inventory scope: met. Notes explicitly state local scan scope and that external downstream repositories, published package tarballs, Hackage metadata, GitHub code search, deployed operator environments, and generated source distributions were not inspected.
- Implementation evidence written only to `implementation-notes.md`: met for implementation stage. The integrated pre-review changed paths were only round-local artifacts `selection.md`, `plan.md`, and `implementation-notes.md`.
- Roadmap files and `worker-plan.json` untouched: met. No roadmap file or `worker-plan.json` appears in the changed path set.

### Decision
**APPROVED**

### Evidence
The integrated result satisfies the evidence-only scope for round-075. The selected facade scan is live-verified and matches the implementation notes: `CodexWatcher.AppServerClient` has 28 direct imports, `CodexWatcher.Core.Ids` has 65, `CodexWatcher.Workflow.EventLog` has 3, and `CodexWatcher.Workflow.Permission` has 1 across the planned local surfaces. The wrapper module reads confirm the replacement mappings and blocker classifications recorded in the notes.

The round does not treat the closed `2026-05-09-01-compatibility-surface-cleanup` family as removal approval, and it does not make deprecation, migration, Cabal exposure, removal, release, runtime compatibility-file, event-schema, healthcheck, or repair decisions. The cabal baseline was intentionally not run because this round changed only round-local orchestrator evidence artifacts, and the plan specifically directs reviewers not to run cabal build/test for that artifact-only case.
