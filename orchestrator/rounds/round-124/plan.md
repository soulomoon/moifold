### Goal
Move only `src/CodexWatcher/Domain/PrReview/LaunchCli.hs` off the public `CodexWatcher.AppServerClient` compatibility facade and onto the direct owner imports for the Codex app-server symbols it already uses, with no behavior, package, facade, test, fixture, documentation, or runtime changes.

This round is part of roadmap `2026-05-11-00-highest-value-cleanup` revision `rev-001`, under milestone `milestone-003-import-convergence-package-boundaries`, direction `direction-010-appserverclient-import-convergence`, item `round-124-pr-review-launch-appserverclient-import-convergence`. Follow the shared invariants in `orchestrator/project-contract.md`; this is import convergence only, not deprecation or removal approval.

### Approach
Keep the implementation as a single sequential edit in `src/CodexWatcher/Domain/PrReview/LaunchCli.hs`. Replace the unqualified `CodexWatcher.AppServerClient` import with explicit direct owner imports for the exact symbols already used by this module:

- `CodexWatcher.Workflow.Agent.Codex.Client (formatAppServerClientFailure)`
- `CodexWatcher.Workflow.Agent.Codex.Transport (AppServerEndpoint, defaultAppServerClientOptions, startThreadWithEndpoint)`

Do not edit any declarations, expressions, request ids, launch-plan construction, child-command rendering, app-server failure formatting, refreshed worker/reviewer thread-id persistence, runtime-owner behavior, or watcher-state writes. Do not migrate `src/CodexWatcher/Cli/Command/IssueFanout.hs`, tests, test support, docs, package descriptors, public facade exposure, runtime compatibility files, fixtures, endpoint parsing, protocol modules, or any other imports.

Worker fan-out is not justified: the selected scope is one production import-only change in one file with tightly coupled verification, so use a single implementer and do not write `worker-plan.json`.

### Steps
1. Confirm the worktree is on `orchestrator/round-124-highest-value-cleanup-slice` and inspect `git status --short` before editing so unrelated existing changes are preserved.
2. Open `src/CodexWatcher/Domain/PrReview/LaunchCli.hs` and identify the symbols currently supplied by `CodexWatcher.AppServerClient`: `AppServerEndpoint`, `defaultAppServerClientOptions`, `startThreadWithEndpoint`, and `formatAppServerClientFailure`.
3. Replace only the `import CodexWatcher.AppServerClient` line with the two direct owner imports listed in the approach. Keep import ordering consistent with the file, but do not otherwise reformat the module.
4. Do not touch `CodexWatcher.AppServerClient`, `CodexWatcher.AppServerProtocol`, `CodexWatcher.Workflow.Agent.Codex.Client`, `CodexWatcher.Workflow.Agent.Codex.Transport`, `src/CodexWatcher/Cli/Command/IssueFanout.hs`, any tests, Cabal files, docs, fixtures, roadmap files, `selection.md`, or `orchestrator/state.json`.
5. Review the diff before validation and reject the change if `LaunchCli.hs` has any non-import hunk or if any other file changes besides this plan and the intended implementation file.

### Verification
Run and record these checks from the round worktree:

1. Focused PR-review launch source/test gate:
   - Prefer a focused REPL check when practical:
     `cabal repl watcher-core-test --repl-options=-ignore-dot-ghci`
     then in GHCi:
     `:load test/PrReviewLaunchCliSpec.hs`
     `prReviewLaunchCliTests`
   - If the REPL route is not practical in the environment, run a source-focused compile/check that loads `test/PrReviewLaunchCliSpec.hs` and record the exact command and result before continuing to the full test gate.
2. Import and behavior diff guards:
   - `rg -n '^import CodexWatcher\\.AppServerClient' src/CodexWatcher/Domain/PrReview/LaunchCli.hs` must return no matches.
   - `rg -n '^import CodexWatcher\\.Workflow\\.Agent\\.Codex\\.(Client|Transport)' src/CodexWatcher/Domain/PrReview/LaunchCli.hs` must show the new direct owner imports.
   - `git diff --unified=0 -- src/CodexWatcher/Domain/PrReview/LaunchCli.hs` must show only import-line changes, with no code-body hunks.
   - Run a facade scan such as `rg -n 'CodexWatcher\\.AppServerClient' src app test *.cabal agent-workflow-* docs` and record that `LaunchCli.hs` is no longer a facade user while the remaining `IssueFanout`, test-policy, or test-support users are intentionally out of scope.
3. Full selected baseline:
   - `cabal test watcher-core-test`
   - `cabal build all`
   - `git diff --check`
4. JSON/state and artifact checks:
   - `jq -e '.active_round_id == "round-124" and .stage == "plan" and .active_rounds[0].worker_mode == "none" and .active_rounds[0].round_artifacts.plan == "orchestrator/rounds/round-124/plan.md"' orchestrator/state.json`
   - `test ! -e orchestrator/rounds/round-124/worker-plan.json`
   - `git status --short` must show no edits to `orchestrator/state.json`, `orchestrator/rounds/round-124/selection.md`, roadmap files, tests, Cabal files, docs, fixtures, or runtime compatibility files from this round.
