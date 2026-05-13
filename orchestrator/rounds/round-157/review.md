### Checks Run
- Command: `cabal test watcher-core-test`
  Result: pass. The test suite built and ran under GHC 9.12.2; `watcher-core-test` passed, including the runner guard active-turn, stale-turn, app-server failure, repair-launch, request-id, thread-id, turn-id, endpoint-backed app-server, and healthcheck assertions.

- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`.

- Command: `git diff --check`
  Result: pass. No whitespace errors.

- Command: `git diff --cached --check`
  Result: pass. No staged whitespace errors; no files are staged.

- Command: `rg -n "CodexWatcher\\.Core\\.Ids" test/RunnerGuardSpec.hs`
  Result: pass. Exit code 1 with no matches, confirming the selected file no longer imports the compatibility facade.

- Command: `rg -n "CodexWatcher\\.Workflow\\.(Agent|GitHub)\\.Ids" test/RunnerGuardSpec.hs`
  Result: pass. Matches show `CodexWatcher.Workflow.Agent.Ids (RequestId (..), ThreadId (..), TurnId (..), unThreadId, unTurnId)` and `CodexWatcher.Workflow.GitHub.Ids (RepoName (..))`.

- Command: `git diff -U0 -- test/RunnerGuardSpec.hs`
  Result: pass. The zero-context source diff contains only the import replacement in `test/RunnerGuardSpec.hs`; no test body, helper, assertion, failure message, or expectation changed.

- Command: `git diff --name-status`
  Result: pass. Modified tracked paths are `orchestrator/state.json` and `test/RunnerGuardSpec.hs`.

- Command: `git diff --cached --name-status`
  Result: pass. No staged paths.

- Command: `git status --porcelain=v1 --untracked-files=all`
  Result: pass. Working tree contains the selected implementation file, orchestrator state, and round artifacts only: `orchestrator/rounds/round-157/selection.md`, `plan.md`, and `implementation-notes.md` before review artifact creation.

- Command: `git diff -U0 -- orchestrator/state.json`
  Result: pass. The state diff activates `round-157` in `stage: "review"` with lineage and artifact paths matching the selection; it does not change production code, package descriptors, docs, compatibility files, or public facade exposure.

- Command: `test ! -e orchestrator/rounds/round-157/worker-plan.json && printf 'absent\n' || printf 'present\n'`
  Result: pass. `worker-plan.json` is absent, matching the serial one-file plan.

### Plan Compliance
- Confirm existing facade import in `test/RunnerGuardSpec.hs`: met. The changed import was the single `CodexWatcher.Core.Ids` import carrying `RepoName`, `RequestId`, `ThreadId`, `TurnId`, `unThreadId`, and `unTurnId`.
- Replace with direct owner imports: met. `RepoName` now comes from `CodexWatcher.Workflow.GitHub.Ids`, and request/thread/turn identifiers plus accessors come from `CodexWatcher.Workflow.Agent.Ids`.
- Preserve test bodies and assertions: met. `git diff -U0 -- test/RunnerGuardSpec.hs` shows only import lines changed.
- Keep implementation scope to the selected file: met for source/test implementation. The only code or test source path changed is `test/RunnerGuardSpec.hs`; the other tracked change is orchestrator control-plane state for the active round, and untracked files are round artifacts.
- Avoid production, package, facade, docs, runtime compatibility, deprecation, removal, milestone completion, terminal completion, release, or public compatibility changes: met. No such paths or claims appear in the diff or round notes.
- Keep public compatibility surfaces exposed: met. `CodexWatcher.Core.Ids` itself was not edited, removed, deprecated, or removed from package exposure.
- Roadmap lineage: met. Selection and active state identify roadmap `2026-05-11-00-highest-value-cleanup`, revision `rev-001`, roadmap dir `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`, milestone `milestone-003-import-convergence-package-boundaries`, direction `direction-011-core-ids-import-convergence`, and extracted item `round-157-runner-guard-spec-core-ids-split-import-migration`.

### Decision
**APPROVED**

### Evidence
The integrated result performs the selected import-convergence slice without behavioral churn. The selected file moved off `CodexWatcher.Core.Ids` and now imports `RepoName` from the GitHub owner module and `RequestId`, `ThreadId`, `TurnId`, `unThreadId`, and `unTurnId` from the agent owner module. The zero-context diff confirms test bodies and assertions are unchanged.

Baseline verification passed: `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and `git diff --cached --check`. Focused scans confirmed no `CodexWatcher.Core.Ids` import remains in `test/RunnerGuardSpec.hs`, and the direct owner imports are present. Scope checks found no staged files, no worker fan-out artifact, no production/package/docs/runtime-compatibility changes, and no deprecation or removal of the `CodexWatcher.Core.Ids` compatibility facade.
