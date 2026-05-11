### Checks Run
- Command: `jq . orchestrator/state.json`
  Result: pass. State records roadmap `2026-05-11-00-highest-value-cleanup`, revision `rev-001`, active round `round-112`, and both top-level and active-round `stage` are `review`.
- Command: `sed -n '1,240p' orchestrator/roles/reviewer.md`
  Result: pass. Reviewer duties require integrated diff review, baseline checks, plan compliance, explicit decision, `review.md`, and `review-record.json`.
- Command: `sed -n '1,240p' orchestrator/project-contract.md`
  Result: pass. Relevant contracts require preserving app-server request rendering/action ordering/request-id progression, package boundaries, public compatibility facades, and baseline gates.
- Command: `sed -n '1,260p' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`
  Result: pass. Baseline checks and AppServerClient/RunnerGuard-adjacent task-specific checks were identified.
- Command: `sed -n '1,240p' orchestrator/rounds/round-112/selection.md`
  Result: pass. Selection scopes the round to focused `startRunnerGuardRepairThread` endpoint-backed repair-launch coverage and excludes production behavior/import changes.
- Command: `sed -n '1,260p' orchestrator/rounds/round-112/plan.md`
  Result: pass. Plan requires successful sequence, four failure-format cases, minimal suite wiring, no production app-server/client/protocol edits, no worker fan-out, and full gates.
- Command: `sed -n '1,260p' orchestrator/rounds/round-112/implementation-notes.md`
  Result: pass. Notes claim only `test/RunnerGuardSpec.hs` implementation changes plus round notes, with all required validations run.
- Command: `git diff --name-status`
  Result: pass. Tracked diff is limited to `orchestrator/state.json` and `test/RunnerGuardSpec.hs`.
- Command: `find orchestrator/rounds/round-112 -maxdepth 2 -type f -print | sort`
  Result: pass. Round artifacts before review were `selection.md`, `plan.md`, and `implementation-notes.md`; no worker plan was present.
- Command: `git diff -- test/RunnerGuardSpec.hs`
  Result: pass. Tests add endpoint-backed `startRunnerGuardRepairThread` coverage for success, launch failure, name-set failure, turn-start failure, and turn-start parse failure.
- Command: `git diff -- src/CodexWatcher/RunnerGuard.hs src/CodexWatcher/AppServerClient.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs agent-workflow-codex/src/CodexWatcher/AppServerProtocol.hs`
  Result: pass. Empty output; no production RunnerGuard/AppServerClient/client/transport/protocol behavior or imports changed.
- Command: `printf 'RunnerGuardSpec.runnerGuardActiveTurnInspectionTests\n:quit\n' | cabal repl watcher-core-test`
  Result: pass. GHCi loaded 19 modules and returned `True`; output included PASS lines for repair thread id, repair turn id, `thread/start`/`thread/name/set`/`turn/start`, request ids `1`/`2`/`3`, thread name, prompt details, and all four failure-format cases.
- Command: `cabal test watcher-core-test`
  Result: pass. Test suite `watcher-core-test` passed; output included the new RunnerGuard repair-launch PASS assertions.
- Command: `cabal build all`
  Result: pass. Output: `Up to date`.
- Command: `git diff --check`
  Result: pass. No whitespace errors.
- Command: `git diff --cached --check`
  Result: pass. No staged whitespace errors.
- Command: `test ! -e orchestrator/rounds/round-112/worker-plan.json`
  Result: pass. No worker-plan artifact exists.
- Command: `jq -r '.stage, .active_rounds[0].stage' orchestrator/state.json`
  Result: pass. Output was `review` and `review`.
- Command: `git status --short`
  Result: pass. Dirty paths are `orchestrator/state.json`, `test/RunnerGuardSpec.hs`, and untracked `orchestrator/rounds/round-112/` artifacts.

### Plan Compliance
- Extend the RunnerGuard test aggregate: met. `runnerGuardActiveTurnInspectionTests` now includes `runnerGuardRepairLaunchSequenceTests`; no `test/Main.hs` or Cabal wiring change was needed.
- Add deterministic repair fixture helpers in `RunnerGuardSpec`: met. `withRunnerGuardRepairFixture`, `repairLaunchProblem`, and helper assertions build a deterministic endpoint-backed `RunnerGuardConfig 'IssuePlanning`.
- Cover the successful repair launch sequence: met. The focused REPL and full suite assert returned `ThreadId "repair-thread"` and `TurnId "repair-turn"`, exact methods `thread/start`, `thread/name/set`, `turn/start`, ids `1`, `2`, `3`, thread name `runner-guard repair owner/name`, repair cwd, developer instructions, and prompt details.
- Cover launch failure formatting: met. The test scripts a `thread/start` JSON-RPC error and asserts `app-server JSON-RPC error for request id 1: launch boom`, stopping after `thread/start`.
- Cover name-set failure formatting: met. The test scripts `thread/name/set` failure and asserts `app-server JSON-RPC error for request id 2: name boom`, stopping after the first two non-session requests.
- Cover turn-start request failure formatting: met. The test scripts `turn/start` failure and asserts `app-server JSON-RPC error for request id 3: turn boom` after the full three-request sequence.
- Cover turn-start parse failure formatting: met. The test scripts malformed `turn/start` success, asserts `app-server JSON decode failed:`, verifies the full sequence, and verifies the prompt was still sent.
- Keep suite wiring minimal: met. Only `test/RunnerGuardSpec.hs` changed for test code; no new module, Cabal metadata, `test/Main.hs`, or test-support helper change was introduced.
- Preserve selected boundaries: met. Production guard was empty for `RunnerGuard.hs`, `AppServerClient.hs`, Codex client, transport, and protocol modules. No docs, fixtures, public API, facade exposure, package descriptor, import migration, or worker-plan changes were made.

### Decision
**APPROVED**

### Evidence
The integrated diff satisfies the round objective. The new tests use `withEndpointBackedAppServer` and call production `startRunnerGuardRepairThread`, so the assertions observe the endpoint-backed app-server JSON-RPC path rather than a production injection seam. The recorded non-session request assertions prove method order and request ids for `thread/start` id `1`, `thread/name/set` id `2`, and `turn/start` id `3`.

The tests also cover the repair id/name/prompt flow: returned repair thread/turn ids, thread-name params, repair cwd, developer instructions, and prompt contents including problem summary, details, repository path, restart watcher command, and restart guard command.

Failure coverage matches the selected surface: launch, name-set, and turn-start JSON-RPC errors assert stable `formatAppServerClientFailure` text with ids `1`, `2`, and `3`; turn-start parse failure asserts the stable decode prefix. The focused REPL aggregate and full `watcher-core-test` suite both passed with those assertions present.

Changed paths are within the selected scope: `test/RunnerGuardSpec.hs` plus orchestrator state/round artifacts. The production diff guard for RunnerGuard/AppServerClient/client/transport/protocol files was empty, and `worker-plan.json` is absent.
