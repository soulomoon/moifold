### Checks Run
- Command: `pwd && git status --short --branch`
  Result: pass. Worktree is `/Users/ares/src/codex-feishu-bot/.codex-local/workspace/artifacts/codex-watcher-hs/orchestrator/worktrees/round-124` on branch `orchestrator/round-124-highest-value-cleanup-slice`; initial status showed controller-owned `orchestrator/state.json`, intended `src/CodexWatcher/Domain/PrReview/LaunchCli.hs`, and untracked round-124 artifacts.

- Command: `printf ':load test/PrReviewLaunchCliSpec.hs\nprReviewLaunchCliTests\n:quit\n' | cabal repl watcher-core-test --repl-options=-ignore-dot-ghci`
  Result: not counted as approval evidence. GHCi loaded the watcher-core-test modules, but the focused reload failed under `-Werror=missing-home-modules` because `TestSupport.AppServer` and `TestSupport.Workflow` are needed but not listed as `other-modules`; `prReviewLaunchCliTests` was therefore not in scope. The process exited 0 despite the GHCi errors, so the approval relies on the full test gate below.

- Command: `rg -n '^import CodexWatcher\.AppServerClient' src/CodexWatcher/Domain/PrReview/LaunchCli.hs`
  Result: pass. No matches; `LaunchCli.hs` no longer imports the public facade.

- Command: `rg -n '^import CodexWatcher\.Workflow\.Agent\.Codex\.(Client|Transport)' src/CodexWatcher/Domain/PrReview/LaunchCli.hs`
  Result: pass. Found direct owner imports for `CodexWatcher.Workflow.Agent.Codex.Client (formatAppServerClientFailure)` and `CodexWatcher.Workflow.Agent.Codex.Transport (AppServerEndpoint (..), defaultAppServerClientOptions, startThreadWithEndpoint)`.

- Command: `git diff --unified=0 -- src/CodexWatcher/Domain/PrReview/LaunchCli.hs`
  Result: pass. The only `LaunchCli.hs` hunks remove `import CodexWatcher.AppServerClient` and add the two direct owner imports; there are no code-body hunks.

- Command: `rg -n 'CodexWatcher\.AppServerClient' src app test *.cabal agent-workflow-* docs`
  Result: pass for this round's scope. `LaunchCli.hs` is absent. Remaining users are `src/CodexWatcher/AppServerClient.hs`, `src/CodexWatcher/Cli/Command/IssueFanout.hs`, `moifold.cabal` exposure, test-policy/test-support imports, and docs, all explicitly out of scope.

- Command: `jq -e '.active_round_id == "round-124" and .stage == "review" and .active_rounds[0].stage == "review" and .active_rounds[0].worker_mode == "none" and .active_rounds[0].round_artifacts.plan == "orchestrator/rounds/round-124/plan.md" and .active_rounds[0].round_artifacts.review == "orchestrator/rounds/round-124/review.md" and .active_rounds[0].round_artifacts.review_record == "orchestrator/rounds/round-124/review-record.json"' orchestrator/state.json`
  Result: pass. Printed `true`; state is in `review`, not worker fan-out.

- Command: `test ! -e orchestrator/rounds/round-124/worker-plan.json`
  Result: pass. No worker plan exists.

- Command: `git diff --name-only`
  Result: pass. Tracked diff contains only `orchestrator/state.json` and `src/CodexWatcher/Domain/PrReview/LaunchCli.hs`; no tests, docs, Cabal files, fixtures, runtime compatibility files, public facade code, or roadmap files are modified.

- Command: `find orchestrator/rounds/round-124 -maxdepth 1 -type f -print | sort`
  Result: pass before this review write. Round artifacts present were `implementation-notes.md`, `plan.md`, and `selection.md`; no worker plan.

- Command: `git diff --check`
  Result: pass. No whitespace errors.

- Command: `cabal test watcher-core-test`
  Result: pass. `watcher-core-test` passed. The output includes the PR-review launch behavior checks: execute starts only worker and reviewer command threads, thread starts use launch workdir, worker/reviewer instructions keep role and PR context, refreshed worker/reviewer IDs persist in config and finalized manifest, dry-run root/non-root endpoint child command rendering stays stable, JSON-RPC failure reports request id `9000`, and decode failure reports formatted decode text.

- Command: `cabal build all`
  Result: pass. Output: `Up to date`.

### Plan Compliance
- Confirm branch/status before editing: met. Review verified the branch and current status; no implementation or state files were edited during review.
- Identify `CodexWatcher.AppServerClient` symbols used by `LaunchCli.hs`: met. The migration covers `formatAppServerClientFailure`, `AppServerEndpoint`, `defaultAppServerClientOptions`, and `startThreadWithEndpoint`. `AppServerEndpoint (..)` is necessary because the existing code uses record selectors through `OverloadedRecordDot`.
- Replace only the facade import in `LaunchCli.hs`: met. The diff is import-only and limited to replacing the single facade import with direct owner imports.
- Preserve behavior and code bodies: met. `git diff --unified=0` shows no non-import hunks, and `watcher-core-test` passed the PR-review launch behavior checks covering request ids, launch requests, refreshed thread IDs, command rendering, and failure formatting.
- Keep out-of-scope surfaces unchanged: met. The tracked diff does not modify `CodexWatcher.AppServerClient`, `CodexWatcher.AppServerProtocol`, direct owner modules, `IssueFanout`, tests, Cabal files, docs, fixtures, runtime compatibility files, or roadmap files.
- Do not create worker fan-out: met. State records `worker_mode == "none"` and no `worker-plan.json` exists.
- Follow active roadmap verification: met. Baseline `cabal test watcher-core-test`, `cabal build all`, and `git diff --check` passed; facade scan records remaining users without treating this import migration as deprecation or removal approval.

### Decision
**APPROVED**

### Evidence
The integrated round result matches the selected scope: a production import-only migration of `src/CodexWatcher/Domain/PrReview/LaunchCli.hs` away from `CodexWatcher.AppServerClient` to direct Codex app-server owner modules. The only tracked implementation hunk in `LaunchCli.hs` is the import replacement. Full package verification passed, including the PR-review launch behavior tests that protect worker/reviewer app-server requests, request-id and failure-format stability, refreshed launch-plan thread IDs, and dry-run child command rendering.

The public facade remains exposed and unchanged; remaining `CodexWatcher.AppServerClient` users are the facade module/Cabal exposure, `IssueFanout`, test-policy/test-support imports, and docs, all outside round 124. This approval is not deprecation, Cabal exposure cleanup, public facade removal, runtime compatibility cleanup, fixture migration, or milestone completion approval.
