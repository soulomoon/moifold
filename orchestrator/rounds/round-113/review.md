### Checks Run
- Command: `sed -n '1,240p' orchestrator/roles/reviewer.md`
  Result: pass; reviewer role requires plan, project-contract, roadmap verification, implementation-notes, full checks, explicit decision, and review record.
- Command: `sed -n '1,260p' orchestrator/project-contract.md`
  Result: pass; package-boundary imports and public compatibility facades remain protected stable surfaces.
- Command: `sed -n '1,260p' orchestrator/rounds/round-113/selection.md`
  Result: pass; selected item is `round-113-runner-guard-appserverclient-import-convergence`, scoped to an import-only `src/CodexWatcher/RunnerGuard.hs` migration.
- Command: `sed -n '1,260p' orchestrator/rounds/round-113/plan.md`
  Result: pass; plan requires only replacing the RunnerGuard `CodexWatcher.AppServerClient` import with direct owner imports from `CodexWatcher.Workflow.Agent.Codex.Client` and `CodexWatcher.Workflow.Agent.Codex.Transport`.
- Command: `sed -n '1,260p' orchestrator/rounds/round-113/implementation-notes.md`
  Result: pass; notes record an import-only production change, no test/package/docs/facade/API/code-body changes, and no worker fan-out.
- Command: `sed -n '824,1000p' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`
  Result: pass; roadmap records rounds 111 and 112 as satisfying the RunnerGuard behavior blockers while direction 010 remains in progress.
- Command: `sed -n '1,260p' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`
  Result: pass; baseline checks and facade import-convergence checks apply.
- Command: `if rg -n "^import CodexWatcher\\.AppServerClient" src/CodexWatcher/RunnerGuard.hs; then exit 1; else exit 0; fi`
  Result: pass; no `CodexWatcher.AppServerClient` import remains in `RunnerGuard.hs`.
- Command: `rg -n "^import CodexWatcher\\.Workflow\\.Agent\\.Codex\\.Client" src/CodexWatcher/RunnerGuard.hs`
  Result: pass; direct client owner import found at line 28.
- Command: `rg -n "^import CodexWatcher\\.Workflow\\.Agent\\.Codex\\.Transport" src/CodexWatcher/RunnerGuard.hs`
  Result: pass; direct transport owner import found at line 37.
- Command: `git diff -- src/CodexWatcher/RunnerGuard.hs`
  Result: pass; production diff is limited to replacing the facade import block with `AppServerProtocol`, direct client-owner, and direct transport-owner import blocks.
- Command: `rg -n "^import CodexWatcher\\.AppServerClient" src app test agent-workflow-core agent-workflow-codex agent-workflow-github`
  Result: pass; remaining facade imports are limited to non-selected source users (`Domain/PrReview/LaunchCli.hs`, `Cli/Command/AppServerProbe.hs`, `Cli/Command/IssueFanout.hs`, `AutomaticLoop/Runner.hs`, `Domain/IssuePlanning/Loop.hs`, `Healthcheck.hs`, `Cli/Command/Observe.hs`) and test/test-support policy imports.
- Command: `git diff --exit-code -- moifold.cabal cabal.project agent-workflow-codex/agent-workflow-codex.cabal src/CodexWatcher/AppServerClient.hs`
  Result: pass; package descriptors and public compatibility facade are unchanged.
- Command: `git diff --exit-code -- agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs`
  Result: pass; direct owner modules are unchanged.
- Command: `printf 'RunnerGuardSpec.runnerGuardActiveTurnInspectionTests\n:quit\n' | cabal repl watcher-core-test`
  Result: pass; focused RunnerGuard aggregate passed, including active turn inspection and repair-launch sequence checks.
- Command: `cabal test watcher-core-test`
  Result: pass; watcher-core test suite passed.
- Command: `cabal build all`
  Result: pass; build reported `Up to date`.
- Command: `test ! -e orchestrator/rounds/round-113/worker-plan.json`
  Result: pass; no worker fan-out artifact exists.
- Command: `git diff --check`
  Result: pass; no whitespace errors.
- Command: `git diff --cached --check`
  Result: pass; no staged whitespace errors.
- Command: `jq . orchestrator/state.json`
  Result: pass; state JSON parsed before review finalization.
- Command: `jq . orchestrator/state.json`
  Result: pass after review finalization; top-level stage and active round stage are `merge`, with `merge_ready` set to `true`.
- Command: `jq . orchestrator/rounds/round-113/review-record.json`
  Result: pass; review record JSON parses and records decision `approved` for roadmap `2026-05-11-00-highest-value-cleanup`, revision `rev-001`, direction `direction-010-appserverclient-import-convergence`, extracted item `round-113-runner-guard-appserverclient-import-convergence`.

### Plan Compliance
- Re-read selected scope and shared invariants: met; selection, roadmap slice, verification, and project contract all confirm this is only an import-convergence slice and not facade removal/deprecation.
- Confirm current target imports and use sites: met; old `RunnerGuard.hs` facade import is absent, direct owner imports are present.
- Confirm direct owner modules and facade stability: met; descriptor/facade and direct-owner diff guards are empty.
- Edit only `src/CodexWatcher/RunnerGuard.hs`: met for implementation scope; production diff is import-only in that file.
- Do not migrate other importers: met; remaining facade import scan shows only non-selected source users and tests.
- Run focused RunnerGuard coverage: met; REPL aggregate passed.
- Run full suite and build: met; `cabal test watcher-core-test` and `cabal build all` passed.
- Run round hygiene and JSON checks: met; no worker plan, whitespace checks pass, and state JSON parses.
- Finalize review state: met; state is coherent for merge and `review-record.json` records the approved decision with the required roadmap lineage.

### Decision
**APPROVED**

### Evidence
The integrated result matches the selected round exactly. The only production change is the import replacement in `src/CodexWatcher/RunnerGuard.hs`, moving symbols from the `CodexWatcher.AppServerClient` compatibility facade to the direct Codex client and transport owner modules. No code bodies, package descriptors, direct owner modules, public facade, tests, docs, or other `CodexWatcher.AppServerClient` importers changed.

The behavior gates that justified this import move remain covered: the focused RunnerGuard REPL aggregate passed, and the full `watcher-core-test` suite passed. Public compatibility facade exposure remains unchanged, and direction 010 remains in progress because other source and test-policy facade users remain for later selected rounds.

Review finalization set top-level `stage` and active round `stage` to `merge`, set active round `merge_ready` to `true`, and wrote `review-record.json` with decision `approved`.
