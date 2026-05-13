### Checks Run
- Command: `jq '{roadmap_id, roadmap_revision, roadmap_dir, stage, active_round_id, active_rounds: [.active_rounds[] | {round_id, milestone_id, direction_id, extracted_item_id, roadmap_item_id, stage, worker_mode, merge_ready}]}' orchestrator/state.json`
  Result: pass. State lineage is `2026-05-11-00-highest-value-cleanup` / `rev-001`, roadmap dir `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`, active round `round-173`, milestone `milestone-003-import-convergence-package-boundaries`, direction `direction-011-core-ids-import-convergence`, extracted item `round-173-effects-core-ids-split-import-migration`, `roadmap_item_id: null`, stage `review`, `worker_mode: none`, and `merge_ready: false`.

- Command: `git diff -- src/CodexWatcher/Effects.hs`
  Result: pass. The diff only removes `import CodexWatcher.Core.Ids (BranchName, CommitSha, PrNumber, RepoName, ReviewThreadId, ThreadId)` and adds `import CodexWatcher.Workflow.Agent.Ids (ThreadId)` plus `import CodexWatcher.Workflow.GitHub.Ids (BranchName, CommitSha, PrNumber, RepoName, ReviewThreadId)`.

- Command: `rg -n "CodexWatcher\\.Core\\.Ids" src/CodexWatcher/Effects.hs; rc=$?; printf 'rg_exit=%s\n' "$rc"`
  Result: pass. Exit was `1`, meaning no focused matches remain in `src/CodexWatcher/Effects.hs`.

- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`.

- Command: `cabal test watcher-core-test`
  Result: pass. `Test suite watcher-core-test: PASS`; `1 of 1 test suites (1 of 1 test cases) passed`.

- Command: `git diff --check`
  Result: pass. No whitespace or conflict-marker problems reported.

- Command: `git diff --cached --name-only`
  Result: pass. No staged paths were present.

- Command: `git diff --cached --check`
  Result: skipped because no changes were staged.

- Command: `rg -n "CodexWatcher\\.Core\\.Ids" src app test moifold.cabal agent-workflow-*/*.cabal`
  Result: pass. Remaining users are present in `moifold.cabal`, tests, `src/CodexWatcher/EffectInterpreter.hs`, event-log, state-machine, healthcheck, runtime compatibility, CLI, issue planning/implementation, golden replay, `src/CodexWatcher/Core/Ids.hs`, and indexed workflow modules. These are outside this slice and do not represent completion, removal, Cabal exposure cleanup, or facade deprecation.

### Plan Compliance
- Confirm existing import-only target in `src/CodexWatcher/Effects.hs`: met. The pre-review diff showed the single planned `CodexWatcher.Core.Ids` import replacement.
- Replace `Core.Ids` import with direct owner imports: met. `ThreadId` now comes from `CodexWatcher.Workflow.Agent.Ids`; `BranchName`, `CommitSha`, `PrNumber`, `RepoName`, and `ReviewThreadId` now come from `CodexWatcher.Workflow.GitHub.Ids`.
- Preserve every other import, export, type, constructor, instance, and function body: met. The `Effects.hs` diff contains only import-line changes; no function body, constructor, exported API shape, deriving behavior, action classification, mutation detection, or effect-plan logic changed.
- Do not edit package descriptors, tests, docs, fixtures, runtime compatibility files, `CodexWatcher.Core.Ids`, roadmap files, state files, selection files, review artifacts beyond reviewer outputs, or worker-plan artifacts: met for the implementation diff under review. The only implementation-path diff is `src/CodexWatcher/Effects.hs`; no Cabal, docs, tests, fixtures, runtime compatibility files, public facade module, public facade exposure, or roadmap files changed as part of the implementation.
- Record that remaining `CodexWatcher.Core.Ids` users are expected: met. The remaining-user scan still finds users outside this round and this approval is not completion, removal, deprecation, package exposure cleanup, or milestone completion.

### Decision
**APPROVED**

### Evidence
State lineage matches the required active round metadata: roadmap `2026-05-11-00-highest-value-cleanup`, revision `rev-001`, milestone `milestone-003-import-convergence-package-boundaries`, direction `direction-011-core-ids-import-convergence`, extracted item `round-173-effects-core-ids-split-import-migration`, stage `review`, `worker_mode: none`, and `merge_ready: false`.

The implementation is behavior-preserving and import-only in `src/CodexWatcher/Effects.hs`. It moves the existing ID type imports from the `CodexWatcher.Core.Ids` compatibility facade to the direct owner modules without changing any constructors, function bodies, action classification, mutation detection, deriving behavior, exported API shape, tests, fixtures, docs, Cabal descriptors, runtime compatibility files, roadmap files, public facade module, or facade exposure.

Baseline verification passed: `cabal build all`, `cabal test watcher-core-test`, and `git diff --check` all passed. No staged changes existed, so `git diff --cached --check` was skipped by rule. The focused scan proves `Effects.hs` no longer imports `CodexWatcher.Core.Ids`; the broader scan confirms remaining users are outside this round and must be handled by later selected slices or explicit removal gates.
