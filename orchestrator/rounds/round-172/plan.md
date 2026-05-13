### Goal

Migrate only `src/CodexWatcher/RunnerGuard.hs` away from the `CodexWatcher.Core.Ids` compatibility facade by importing each ID type from its direct owner module, while preserving all runner-guard behavior and keeping the public `CodexWatcher.Core.Ids` facade exposed.

Roadmap lineage: `2026-05-11-00-highest-value-cleanup` / `rev-001`, milestone `milestone-003-import-convergence-package-boundaries`, direction `direction-011-core-ids-import-convergence`, extracted item `round-172-runner-guard-core-ids-split-import-migration`.

### Approach

Make a single import-only production change in `src/CodexWatcher/RunnerGuard.hs`:

- Replace `import CodexWatcher.Core.Ids (RepoName (..), RequestId (..), ThreadId (..), TurnId (..))`.
- Add `import CodexWatcher.Workflow.GitHub.Ids (RepoName (..))`.
- Add `import CodexWatcher.Workflow.Agent.Ids (RequestId (..), ThreadId (..), TurnId (..))`.

Do not touch function bodies, constructors, JSON encoders, JSON field names, app-server request sequencing, thread/turn parsing, event-log replay handling, prompts, repair workflow text, Cabal exposure, docs, tests, fixtures, runtime compatibility files, or the `CodexWatcher.Core.Ids` facade module. This round is one migration slice only; it is not facade deprecation, removal approval, milestone completion, or terminal cleanup.

Worker fan-out is not used. The change has one implementation file, one import block, and no non-overlapping worker ownership boundary that would justify `worker-plan.json`.

### Steps

1. Open `src/CodexWatcher/RunnerGuard.hs` and change only the ID import section.
2. Remove the existing `CodexWatcher.Core.Ids` import that brings in `RepoName`, `RequestId`, `ThreadId`, and `TurnId`.
3. Add the direct owner import for `RepoName` from `CodexWatcher.Workflow.GitHub.Ids`.
4. Add the direct owner import for `RequestId`, `ThreadId`, and `TurnId` from `CodexWatcher.Workflow.Agent.Ids`.
5. Do not edit any use sites such as `RequestId 1`, `RequestId 2`, `RequestId 3`, `unRepoName`, `unThreadId`, `unTurnId`, `RunnerGuardConfig`, `RunnerGuardRepair`, `checkRunnerGuard`, `startRunnerGuardRepairThread`, `runnerGuardRepairPrompt`, or active-turn checking logic unless the compiler proves the direct imports require a syntax-only import-list adjustment.
6. Confirm no other files changed as part of the implementation. If formatting tools would touch unrelated code, skip them and keep the diff manual and import-only.
7. Record in implementation notes that remaining `CodexWatcher.Core.Ids` users are intentionally left for later rounds and that the facade remains available and exposed.

### Verification

Run these checks from the round worktree:

1. Inspect the exact implementation diff:
   ```sh
   git diff -- src/CodexWatcher/RunnerGuard.hs
   ```
   Expected: only the `RunnerGuard.hs` import block changes from the facade import to the two direct owner imports.

2. Prove `RunnerGuard.hs` no longer imports the facade:
   ```sh
   rg -n '^import CodexWatcher\.Core\.Ids' src/CodexWatcher/RunnerGuard.hs
   ```
   Expected: no matches.

3. Build the full package set:
   ```sh
   cabal build all
   ```

4. Run the focused watcher test suite:
   ```sh
   cabal test watcher-core-test
   ```

5. Check whitespace and patch hygiene:
   ```sh
   git diff --check
   ```

6. If anything is staged, also run:
   ```sh
   git diff --cached --check
   ```

7. Record remaining `CodexWatcher.Core.Ids` users so review sees this as one migration slice, not completion or removal:
   ```sh
   rg -n 'CodexWatcher\.Core\.Ids' src app test *.cabal docs packages 2>/dev/null || true
   ```
   Expected: remaining users still include the public facade exposure in `moifold.cabal`, the facade module itself, and other production/test/docs imports outside this round's scope.
