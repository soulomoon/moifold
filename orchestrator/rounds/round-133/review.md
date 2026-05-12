### Checks Run
- Command: `sed -n '1,260p' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`
  Result: pass; resolved active baseline checks to `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, and `git diff --cached --check` when staging is involved, plus facade import convergence scans.
- Command: `sed -n '1,260p' orchestrator/project-contract.md`
  Result: pass; confirmed this round must preserve event schemas, public compatibility facades, package exposure, runtime compatibility files, and cleanup sequencing.
- Command: `sed -n '1,260p' orchestrator/state.json`
  Result: pass; state lineage is roadmap `2026-05-11-00-highest-value-cleanup`, revision `rev-001`, dir `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`, active round `round-133`, stage `review`, worker_mode `none`, merge_ready `false`.
- Command: `git status --short --branch`
  Result: pass; branch is `orchestrator/round-133-highest-value-cleanup-slice`, with modified `orchestrator/state.json`, modified `test/WorkflowIndexedSpec.hs`, and untracked round artifacts only.
- Command: `git diff --name-only`
  Result: pass; implementation/controller diff is limited to `orchestrator/state.json` and `test/WorkflowIndexedSpec.hs`.
- Command: `git diff -- test/WorkflowIndexedSpec.hs`
  Result: pass; test diff replaces only the exact `CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog` import with `CodexWatcher.Workflow.Audit qualified as WorkflowAudit`, and rewrites local audit accessor/recommendation use sites from `WorkflowEventLog.` to `WorkflowAudit.`.
- Command: `test ! -e orchestrator/rounds/round-133/worker-plan.json && echo 'absent' || { echo 'present'; ls -l orchestrator/rounds/round-133/worker-plan.json; }`
  Result: pass; output `absent`.
- Command: `rg -n "CodexWatcher\\.Workflow\\.EventLog qualified as WorkflowEventLog|WorkflowEventLog\\." test/WorkflowIndexedSpec.hs`
  Result: pass; no matches, exit code 1 as expected for absence.
- Command: `rg -n "CodexWatcher\\.Workflow\\.(Audit|EventLog\\.Commit\\.Core|EventLog\\.File\\.Core) qualified as Workflow(Audit|EventLogCommit|EventLogFileCore)" test/WorkflowIndexedSpec.hs`
  Result: pass; found `WorkflowAudit` at line 84, preserved `WorkflowEventLogCommit` at line 85, and preserved `WorkflowEventLogFileCore` at line 86.
- Command: `rg -n "CodexWatcher\\.Workflow\\.EventLog( qualified as WorkflowEventLog)?|WorkflowEventLog\\." src app test docs *.cabal agent-workflow-* -g'*.hs' -g'*.md' -g'*.cabal'`
  Result: pass; `test/WorkflowIndexedSpec.hs` appears only for preserved direct owner identifiers `WorkflowEventLogCommit` and `WorkflowEventLogFileCore`. Remaining exact facade imports/stale `WorkflowEventLog.` uses are out-of-scope `test/FacadeImportPolicySpec.hs` and `test/WorkflowEventLogSpec.hs`, plus public exposure/docs/core owner references allowed by this round.
- Command: `git diff --check`
  Result: pass; no whitespace errors.
- Command: `git diff --cached --name-only`
  Result: pass; no staged files, so `git diff --cached --check` was not applicable.
- Command: `cabal test watcher-core-test`
  Result: pass; `watcher-core-test` completed successfully, `1 of 1 test suites (1 of 1 test cases) passed`.
- Command: `cabal build all`
  Result: pass; output `Up to date`.

### Plan Compliance
- Add `CodexWatcher.Workflow.Audit qualified as WorkflowAudit` to `test/WorkflowIndexedSpec.hs`: met; owner import is present at line 84.
- Remove only the exact `CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog` import from the selected file: met; selected-file absence scan has no exact facade import match.
- Replace selected-file `WorkflowEventLog.workflowAudit...` accessors with `WorkflowAudit.workflowAudit...`: met; selected-file absence scan has no `WorkflowEventLog.` matches, and diff shows audit accessor replacements only.
- Replace `WorkflowEventLog.WorkflowDaemonStop` with `WorkflowAudit.WorkflowDaemonStop`: met; diff shows the recommendation constructor rewired to `WorkflowAudit.WorkflowDaemonStop`.
- Preserve `WorkflowEventLogCommit` and `WorkflowEventLogFileCore` imports/use sites: met; owner import scan confirms both direct owner imports remain unchanged in `test/WorkflowIndexedSpec.hs`.
- Keep implementation scope to `test/WorkflowIndexedSpec.hs` and avoid public facade/deprecation/removal/Cabal/docs/runtime/event schema/fixture/Workflow.Permission changes: met; `git diff --name-only` shows only controller state plus the selected test module, and the selected module diff is import/use-site-only.
- Preserve state lineage and serial non-worker round shape: met; state records active round `round-133`, stage `review`, `worker_mode` none, `merge_ready` false, and no `worker-plan.json` exists.

### Decision
**APPROVED**

### Evidence
The implementation matches the selected behavior-preserving migration. `test/WorkflowIndexedSpec.hs` no longer imports or calls the exact `CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog` facade; it now uses `CodexWatcher.Workflow.Audit qualified as WorkflowAudit` for audit selectors and `WorkflowDaemonStop`.

The direct owner/core imports `WorkflowEventLogCommit` and `WorkflowEventLogFileCore` remain in the selected file. The broad scan confirms `WorkflowIndexedSpec.hs` no longer appears for stale facade import/use, while remaining exact facade users are the explicitly out-of-scope `test/FacadeImportPolicySpec.hs` and `test/WorkflowEventLogSpec.hs` plus public exposure/docs/core owner references that this round did not authorize changing.

Baseline verification passed: `cabal test watcher-core-test`, `cabal build all`, and `git diff --check`. No files are staged, so the cached diff whitespace check was not applicable. No public compatibility facade, package descriptor, docs, runtime compatibility file, fixture, event schema, or `Workflow.Permission` surface was changed by the implementation.
