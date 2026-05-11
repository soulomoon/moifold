### Checks Run
- Command: `printf ':set -Wno-type-defaults\nPrReviewLaunchCliSpec.prReviewLaunchCliTests\n:quit\n' | cabal repl watcher-core-test`
  Result: pass. GHCi loaded `PrReviewLaunchCliSpec`; `prReviewLaunchCliTests` returned `True`. The output included passing assertions for request ids `9000` and `9001`, launch workdir, worker/reviewer developer instructions, persisted refreshed thread ids, dry-run command flags, endpoint path handling, JSON-RPC failure formatting, decode failure formatting, and stopping before reviewer launch when worker start fails.

- Command: `cabal test watcher-core-test`
  Result: pass. `Test suite watcher-core-test: PASS`; `1 of 1 test suites (1 of 1 test cases) passed.`

- Command: `cabal build all`
  Result: pass. Output: `Up to date`.

- Command: `git diff --check`
  Result: pass. No whitespace errors.

- Command: `git diff --cached --check`
  Result: pass. No staged whitespace errors.

- Command: `rg -n '^import[[:space:]]+CodexWatcher\.AppServerClient\b' src/CodexWatcher/Domain/PrReview/LaunchCli.hs`
  Result: pass. Output: `17:import CodexWatcher.AppServerClient`.

- Command: `! rg -n '^import[[:space:]]+CodexWatcher\.Workflow\.Agent\.Codex\.(Client|Transport|Interpreter)\b' src/CodexWatcher/Domain/PrReview/LaunchCli.hs`
  Result: pass. No direct owner-client, transport, or interpreter imports.

- Command: `git diff -- src/CodexWatcher/Domain/PrReview/LaunchCli.hs`
  Result: pass. Empty output; `LaunchCli.hs` has no production diff.

- Command: `git diff --name-only -- . ':!test/PrReviewLaunchCliSpec.hs' ':!test/Main.hs' ':!moifold.cabal' ':!orchestrator/state.json' ':!orchestrator/rounds/round-123/plan.md' ':!orchestrator/rounds/round-123/selection.md' ':!orchestrator/rounds/round-123/implementation-notes.md'`
  Result: pass. Empty output; tracked changes stay inside allowed paths.

- Command: `git ls-files --others --exclude-standard -- . ':!test/PrReviewLaunchCliSpec.hs' ':!orchestrator/rounds/round-123/plan.md' ':!orchestrator/rounds/round-123/selection.md' ':!orchestrator/rounds/round-123/implementation-notes.md' ':!orchestrator/rounds/round-123/review.md' ':!orchestrator/rounds/round-123/review-record.json'`
  Result: pass. Empty output; untracked files stay inside allowed paths.

- Command: `git diff --name-only -- src/CodexWatcher/AppServerClient.hs src/CodexWatcher/AppServerProtocol.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Interpreter.hs src/CodexWatcher/ChildDaemon.hs src/CodexWatcher/Cli/Command/IssueFanout.hs src/CodexWatcher/Runtime/Compatibility.hs src/CodexWatcher/Runtime/Owner docs fixtures app`
  Result: pass. Empty output; forbidden surfaces are untouched.

- Command: `git diff --name-only -- '*.cabal' 'package.yaml' 'cabal.project*'`
  Result: pass. Output only `moifold.cabal`.

- Command: `git diff -- moifold.cabal`
  Result: pass. The only package descriptor change adds `PrReviewLaunchCliSpec` to `watcher-core-test` `other-modules`.

- Command: `test ! -e orchestrator/rounds/round-123/worker-plan.json`
  Result: pass. No worker fan-out artifact exists.

- Command: `jq -e '.roadmap_id == "2026-05-11-00-highest-value-cleanup" and .roadmap_revision == "rev-001" and .controller_stage == "dispatch-rounds" and .active_round_id == "round-123" and (.active_rounds | length) == 1 and .active_rounds[0].round_id == "round-123" and .active_rounds[0].stage == "review" and .active_rounds[0].worker_mode == "none" and .active_rounds[0].merge_ready == false and (.active_rounds[0].roadmap_item_id == "round-123-pr-review-launch-appserverclient-coverage")' orchestrator/state.json`
  Result: pass. Output: `true`.

- Command: `jq -e '(.review_records == null or (.review_records | type == "object")) and (.roadmap_update == null)' orchestrator/state.json`
  Result: pass. Output: `true`.

- Command: `rg -n "9000|9001|worker-created|reviewer-created|reviewLaunchWorkdir|worker role|reviewer role|developer|--app-server-path|--execute|--loop|watcher\.pid|JSON-RPC|decode|stops before reviewer|runtime-owner|ThreadId|prReviewLaunchCliTests|sequenceAnd" test/PrReviewLaunchCliSpec.hs`
  Result: pass. The new test module contains meaningful assertions for the selected behavior: fixed request ids, cwd, role/developer instructions, refreshed thread ids, dry-run command flags and path handling, failure formatting, and worker-failure short-circuiting.

- Command: `jq -e '.roadmap_id == "2026-05-11-00-highest-value-cleanup" and .roadmap_revision == "rev-001" and .roadmap_dir == "orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001" and .milestone_id == "milestone-003-import-convergence-package-boundaries" and .direction_id == "direction-010-appserverclient-import-convergence" and .extracted_item_id == "round-123-pr-review-launch-appserverclient-coverage" and .roadmap_item_id == "round-123-pr-review-launch-appserverclient-coverage" and .decision == "approved" and (.evidence_summary | type == "string" and length > 0)' orchestrator/rounds/round-123/review-record.json`
  Result: pass. Output: `true`.

### Plan Compliance
- Add `test/PrReviewLaunchCliSpec.hs` with `prReviewLaunchCliTests :: IO Bool`: met. The module exists and exports the aggregate.
- Build deterministic launch fixtures with `IssueConfig`, `PrNumber`, and `prReviewWatcherLaunchPlan`: met. The fixture uses repo `soulomoon/mlf2`, branch `codex/pr-review-launch`, issue `42`, and PR `87`.
- Use a live `runtime-owner.json` to avoid spawning a real child daemon in execute success: met. The test writes a `RuntimeLease` for the current process and asserts the live-owner path.
- Cover endpoint-backed successful worker/reviewer `thread/start`: met. The focused REPL output and source inspection prove request ids `9000` and `9001`, cwd, worker/reviewer developer instructions, and persisted `worker-created` / `reviewer-created` ids.
- Cover dry-run child command rendering: met. The tests assert `run-pr-review`, state paths, repo/workdir, host, port, poll seconds, `--execute`, `--loop`, pid file, root-path omission, and non-root `--app-server-path`.
- Cover selected app-server failure formatting: met. The tests assert request-id-specific JSON-RPC formatting, decode failure prefix, non-zero exits, and no reviewer request after worker failure.
- Keep helpers local to the new test module: met. No `TestSupport` module changes.
- Wire the aggregate into `test/Main.hs`: met. `prReviewLaunchCliTests` is imported, run, and included in the final success conjunction.
- Add watcher-core test metadata only: met. `moifold.cabal` only adds `PrReviewLaunchCliSpec` to `watcher-core-test`.
- Leave `src/CodexWatcher/Domain/PrReview/LaunchCli.hs` unchanged: met. `git diff -- src/CodexWatcher/Domain/PrReview/LaunchCli.hs` is empty.
- Leave forbidden owner/client/protocol/runtime/docs/fixtures/app/issue-fanout surfaces untouched: met. The forbidden-surface guard printed no paths.
- Do not create `worker-plan.json`: met.
- Preserve project-contract invariants: met. Dry-run rendering and request-id progression are covered by focused tests; public compatibility facade availability is preserved by the import guard.

### Decision
**APPROVED**

### Evidence
The implementation is a coverage-only slice. It adds the focused PR-review launch test module, wires it into the watcher-core aggregate, and updates only watcher-core test metadata in `moifold.cabal`. There are no production file edits, no `LaunchCli.hs` diff, no direct owner-client import migration, no worker fan-out artifact, and no forbidden-surface changes. Baseline build/test/check commands all pass.
