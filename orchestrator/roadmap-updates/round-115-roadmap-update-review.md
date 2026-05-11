### Checks Run
- Command: `sed -n '1,240p' orchestrator/roles/reviewer.md`
  Result: pass; confirmed update-roadmap review owns roadmap-update verification, the review artifact, and approval or rejection state.
- Command: `sed -n '1,240p' orchestrator/roadmap-updates/round-115-roadmap-update.md`
  Result: pass; the update cites source round `round-115`, merged commit `dab7a84`, prior revision `rev-001`, proposed revision `rev-001`, and a status-only state change.
- Command: `sed -n '1,260p' orchestrator/rounds/round-115/selection.md`
  Result: pass; selected scope was only the import-only migration of `src/CodexWatcher/Cli/Command/AppServerProbe.hs` from `CodexWatcher.AppServerClient` to direct Codex client and transport owners.
- Command: `sed -n '1,260p' orchestrator/rounds/round-115/implementation-notes.md`
  Result: pass; implementation evidence records no behavior, test, package, docs, facade, direct-owner, protocol, or other-importer changes.
- Command: `sed -n '1,260p' orchestrator/rounds/round-115/review.md`
  Result: pass; the round reviewer approved only the narrow AppServerProbe import migration after focused AppServerProbe coverage, `watcher-core-test`, full build, import scans, descriptor/facade/direct-owner/protocol guards, and hygiene checks.
- Command: `jq . orchestrator/rounds/round-115/review-record.json`
  Result: pass; review record is approved for roadmap `2026-05-11-00-highest-value-cleanup`, revision `rev-001`, milestone `milestone-003-import-convergence-package-boundaries`, direction `direction-010-appserverclient-import-convergence`, item `round-115-appserver-probe-appserverclient-import-convergence`.
- Command: `sed -n '1,260p' orchestrator/rounds/round-115/merge.md`
  Result: pass; merge note records squash title `Move AppServerProbe off AppServerClient facade`, local merge readiness, no dependencies, and no approval for facade removal, Cabal/API cleanup, docs changes, other importers, milestone completion, or terminal completion.
- Command: `git show --stat --oneline --decorate --no-renames dab7a84`
  Result: pass; `dab7a84` is `Move AppServerProbe off AppServerClient facade` and includes the approved round artifacts, controller state, and the import-only `AppServerProbe.hs` change.
- Command: `git diff -- orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`
  Result: pass; roadmap diff records round-115 evidence, removes only `Cli/Command/AppServerProbe.hs` from the remaining source-user list, and keeps milestone 003 plus direction 010 in progress.
- Command: `jq . orchestrator/state.json`
  Result: pass; state is valid JSON, `roadmap_revision` and both roadmap-update revision fields remain `rev-001`, `roadmap_dir` remains `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`, active rounds are empty, and `roadmap_update.status` was `authored` before approval.
- Command: `rg -n "^import CodexWatcher\\.AppServerClient" src app test agent-workflow-core agent-workflow-codex agent-workflow-github`
  Result: pass; current scan shows no `Cli/Command/AppServerProbe.hs` match and still shows remaining source users in `Domain/PrReview/LaunchCli.hs`, `Domain/IssuePlanning/Loop.hs`, `AutomaticLoop/Runner.hs`, `Healthcheck.hs`, `Cli/Command/Observe.hs`, and `Cli/Command/IssueFanout.hs`, plus test and test-support imports.
- Command: `git diff --check`
  Result: pass; no whitespace errors.
- Command: `git diff --cached --check`
  Result: pass; no staged whitespace errors.

### Roadmap Compliance
- Merged round evidence: met. The update follows the approved round-115 evidence and merged commit `dab7a84`: only `src/CodexWatcher/Cli/Command/AppServerProbe.hs` moved from the compatibility facade to direct `CodexWatcher.Workflow.Agent.Codex.Client` and `CodexWatcher.Workflow.Agent.Codex.Transport` imports.
- Revision rule: met. The update keeps the proposed revision at `rev-001`; no new roadmap revision or `roadmap_dir` activation is required because this is a status update to the active roadmap revision.
- Milestone and direction status: met. The update does not mark milestone 003 or direction 010 complete. It records remaining source users and leaves the public compatibility facade exposed.
- Scope boundaries: met. The roadmap text records only the import-only AppServerProbe migration and preserves no-behavior, no-test, no-facade, no-Cabal/API/docs, no-direct-owner/protocol, and no-other-importer boundaries.
- Remaining users: met. The current import scan supports removing `Cli/Command/AppServerProbe.hs` from the remaining source-user list while still listing other source users and test/test-support imports.
- Immutability and activation metadata: met. State continues to reference roadmap id `2026-05-11-00-highest-value-cleanup`, revision `rev-001`, and the same active roadmap dir; the roadmap update records `prior_roadmap_revision = rev-001` and `proposed_roadmap_revision = rev-001`.

### Decision
**APPROVED**
