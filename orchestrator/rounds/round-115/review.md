### Checks Run
- Command: `sed -n '1,220p' orchestrator/roles/reviewer.md`
  Result: pass; confirmed reviewer owns only verification, `review.md`, `review-record.json`, and state approval/rejection fields.
- Command: `sed -n '1,220p' orchestrator/rounds/round-115/selection.md`
  Result: pass; selected scope is only `src/CodexWatcher/Cli/Command/AppServerProbe.hs` import convergence from `CodexWatcher.AppServerClient` to direct Codex client/transport owners.
- Command: `sed -n '1,260p' orchestrator/rounds/round-115/plan.md`
  Result: pass; plan requires an import-only production change, no worker fan-out, focused AppServerProbe coverage, full watcher-core test, full build, import scans, descriptor/facade/direct-owner/protocol guards, and diff/JSON hygiene.
- Command: `sed -n '1,260p' orchestrator/rounds/round-115/implementation-notes.md`
  Result: pass; implementation records only the AppServerProbe import replacement and no behavior, package, docs, facade, direct-owner, or protocol changes.
- Command: `sed -n '1,260p' orchestrator/project-contract.md`
  Result: pass; contract requires compatibility facades to stay available until exact reviewed removal gates and keeps import convergence separate from deprecation/removal.
- Command: `sed -n '1,260p' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`
  Result: pass; verification requires baseline `cabal build all`, `cabal test watcher-core-test`, whitespace checks, AppServerClient import scans, and no deprecation/removal implication.
- Command: `sed -n '860,1080p' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`
  Result: pass; direction 010 remains in progress after round 114, and `Cli/Command/AppServerProbe.hs` is a remaining source user gated by the round-114 command coverage.
- Command: `rg -n "^import CodexWatcher\\.AppServerClient" src/CodexWatcher/Cli/Command/AppServerProbe.hs`
  Result: pass; no matches, so the selected target no longer imports the compatibility facade.
- Command: `rg -n "^import CodexWatcher\\.Workflow\\.Agent\\.Codex\\.Client" src/CodexWatcher/Cli/Command/AppServerProbe.hs`
  Result: pass; direct client-owner import is present at line 12.
- Command: `rg -n "^import CodexWatcher\\.Workflow\\.Agent\\.Codex\\.Transport" src/CodexWatcher/Cli/Command/AppServerProbe.hs`
  Result: pass; direct transport-owner import is present at line 17.
- Command: `rg -n "module CodexWatcher\\.Workflow\\.Agent\\.Codex\\.Client|formatAppServerClientFailure|parseThreadStartThreadId|parseTurnStartTurnId" agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs`
  Result: pass; direct client owner exports and defines the required failure-formatting and parser symbols.
- Command: `rg -n "module CodexWatcher\\.Workflow\\.Agent\\.Codex\\.Transport|AppServerClientOptions|defaultAppServerClientOptions|sendOneAppServerRequest" agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs`
  Result: pass; direct transport owner exports and defines the required options/default/send symbols.
- Command: `sed -n '1,80p' src/CodexWatcher/AppServerClient.hs`
  Result: pass; facade remains an unchanged compatibility reexport of the direct client and transport modules.
- Command: `git diff -- src/CodexWatcher/Cli/Command/AppServerProbe.hs`
  Result: pass; production diff is limited to replacing the `CodexWatcher.AppServerClient` import block with direct owner imports. No code body changed.
- Command: `git diff --exit-code -- moifold.cabal cabal.project agent-workflow-core/agent-workflow-core.cabal agent-workflow-codex/agent-workflow-codex.cabal agent-workflow-github/agent-workflow-github.cabal`
  Result: pass; package descriptors are unchanged.
- Command: `git diff --exit-code -- src/CodexWatcher/AppServerClient.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs agent-workflow-codex/src/CodexWatcher/AppServerProtocol.hs`
  Result: pass; facade, direct owner modules, and protocol module are unchanged.
- Command: `rg -n "^import CodexWatcher\\.AppServerClient" src app test agent-workflow-core agent-workflow-codex agent-workflow-github`
  Result: pass; remaining facade imports are limited to non-selected users in `Domain/PrReview/LaunchCli.hs`, `Domain/IssuePlanning/Loop.hs`, `AutomaticLoop/Runner.hs`, `Healthcheck.hs`, `Cli/Command/Observe.hs`, `Cli/Command/IssueFanout.hs`, and test/test-support files. `AppServerProbe.hs` is absent.
- Command: `rg -n "CodexWatcher\\.AppServerClient" src app test docs *.cabal cabal.project agent-workflow-core agent-workflow-codex agent-workflow-github`
  Result: pass; docs and `moifold.cabal` still mention/expose the compatibility facade as expected, with no migration or removal implied by this round.
- Command: `printf 'AppServerProbeSpec.appServerProbeCommandTests\n:quit\n' | cabal repl watcher-core-test`
  Result: pass; focused aggregate loaded 20 modules and all AppServerProbe command checks returned `PASS`, ending with `True`.
- Command: `cabal test watcher-core-test`
  Result: pass; `watcher-core-test` passed, 1 of 1 test suites and 1 of 1 test cases.
- Command: `cabal build all`
  Result: pass; build reported `Up to date`.
- Command: `test ! -e orchestrator/rounds/round-115/worker-plan.json`
  Result: pass; no worker fan-out plan exists.
- Command: `git diff --name-status`
  Result: pass; tracked changes are only `orchestrator/state.json` and `src/CodexWatcher/Cli/Command/AppServerProbe.hs` before review artifacts.
- Command: `git diff --check`
  Result: pass; no whitespace errors.
- Command: `git diff --cached --check`
  Result: pass; no staged whitespace errors.
- Command: `jq . orchestrator/state.json`
  Result: pass; state JSON is valid before approval update.

### Plan Compliance
- Re-read selected scope and shared invariants: met; selection, project contract, roadmap verification, and active roadmap slice all keep the round to AppServerProbe import convergence only.
- Confirm current target import and symbol use sites: met; target facade import is absent and direct owner imports are present.
- Confirm direct owner modules and public facade: met; required symbols are owned by `CodexWatcher.Workflow.Agent.Codex.Client` and `CodexWatcher.Workflow.Agent.Codex.Transport`, and `CodexWatcher.AppServerClient` remains available as a compatibility reexport.
- Edit only `src/CodexWatcher/Cli/Command/AppServerProbe.hs`: met for implementation scope; production diff is import-only and no other production/package/facade/protocol/direct-owner file changed.
- Reject out-of-scope edits: met; no behavior, request id, timeout, output, fallback, session, parser, failure-formatting, test, package, docs, facade, deprecation, removal, milestone, or terminal-completion change is present.
- Target import result: met; old target import is gone, direct client and transport imports are present.
- Production diff inspection: met; diff is limited to import replacement/reordering in `AppServerProbe.hs`.
- Public compatibility surface and direct owners left alone: met; descriptor and facade/direct-owner/protocol diff guards are empty.
- Remaining facade users recorded: met; scans show only non-selected remaining users, while docs and Cabal exposure still preserve the compatibility facade.
- Focused AppServerProbe coverage: met; focused REPL aggregate passed.
- Required suite and build: met; `cabal test watcher-core-test` and `cabal build all` passed.
- Round hygiene and state checks: met; no worker plan exists, diff checks pass, and state JSON is valid.

### Decision
**APPROVED**

### Evidence
The integrated round matches the selected scope. `src/CodexWatcher/Cli/Command/AppServerProbe.hs` moved from `CodexWatcher.AppServerClient` to the direct owner imports:

- `CodexWatcher.Workflow.Agent.Codex.Client` for `formatAppServerClientFailure`, `parseThreadStartThreadId`, and `parseTurnStartTurnId`.
- `CodexWatcher.Workflow.Agent.Codex.Transport` for `AppServerClientOptions (..)`, `defaultAppServerClientOptions`, and `sendOneAppServerRequest`.

The production diff does not touch any code bodies. Focused command behavior remains covered by `AppServerProbeSpec.appServerProbeCommandTests`, and the full `watcher-core-test` suite plus `cabal build all` passed. Remaining `CodexWatcher.AppServerClient` imports are outside the selected target, and the public facade, direct owner modules, protocol module, package descriptors, docs, and public exposure remain unchanged.

This approval records only the narrow AppServerProbe import migration. It does not approve migration of other importers, public facade deprecation/removal, Cabal exposure or public API cleanup, docs changes, release/publication, milestone completion, or terminal completion.
