### Goal
Migrate only `src/CodexWatcher/Effects.hs` off the `CodexWatcher.Core.Ids` compatibility facade by importing its existing ID types from their direct owner modules, while preserving the `CodexWatcher.Effects` public API, effect constructors, deriving behavior, action classification, mutation detection, and all function bodies.

### Approach
Make one implementation edit in `src/CodexWatcher/Effects.hs`: replace `import CodexWatcher.Core.Ids (BranchName, CommitSha, PrNumber, RepoName, ReviewThreadId, ThreadId)` with:

```haskell
import CodexWatcher.Workflow.Agent.Ids (ThreadId)
import CodexWatcher.Workflow.GitHub.Ids (BranchName, CommitSha, PrNumber, RepoName, ReviewThreadId)
```

Keep the change import-only. Do not edit constructors, exported names, `EffectPlan`, `SomeEffect`, `SomeEffectAction`, `actionKindText`, `effectActionSing`, `hasMutation`, `someEffectAction`, tests, Cabal files, docs, fixtures, runtime compatibility files, or public facade exposure.

This round is a single serial production migration slice under `2026-05-11-00-highest-value-cleanup` / `rev-001`, `milestone-003-import-convergence-package-boundaries`, `direction-011-core-ids-import-convergence`, and extracted item `round-173-effects-core-ids-split-import-migration`. Worker fan-out is not used because there is only one allowed implementation file and the edit has no separable ownership boundary.

### Steps
1. Open `src/CodexWatcher/Effects.hs` and confirm the only planned code change is the existing `CodexWatcher.Core.Ids (BranchName, CommitSha, PrNumber, RepoName, ReviewThreadId, ThreadId)` import.
2. Replace that import with direct owner imports from `CodexWatcher.Workflow.GitHub.Ids` for `BranchName`, `CommitSha`, `PrNumber`, `RepoName`, and `ReviewThreadId`, and from `CodexWatcher.Workflow.Agent.Ids` for `ThreadId`.
3. Leave every other import, export, type, constructor, instance, and function body unchanged unless the formatter performs import-order-only movement required by the existing style.
4. Do not edit package descriptors, tests, docs, fixtures, runtime compatibility files, `CodexWatcher.Core.Ids`, roadmap files, state files, selection files, review artifacts, or worker-plan artifacts.
5. Record implementation notes that this is an import-only migration, list the single changed implementation file, include the verification command results, and explicitly state that remaining `CodexWatcher.Core.Ids` users are expected because this is one migration slice, not completion or removal.

### Verification
Run and record:

```sh
git diff -- src/CodexWatcher/Effects.hs
rg -n "CodexWatcher\\.Core\\.Ids" src/CodexWatcher/Effects.hs
cabal build all
cabal test watcher-core-test
git diff --check
git diff --cached --check
rg -n "CodexWatcher\\.Core\\.Ids" src app test moifold.cabal agent-workflow-*/*.cabal
```

Expected verification outcomes:

- The `git diff -- src/CodexWatcher/Effects.hs` output shows only the `CodexWatcher.Core.Ids` import removed and the two direct owner imports added.
- The focused `rg` scan for `src/CodexWatcher/Effects.hs` returns no matches for `CodexWatcher.Core.Ids`.
- `cabal build all` and `cabal test watcher-core-test` pass.
- `git diff --check` passes.
- `git diff --cached --check` passes if anything is staged; if nothing is staged, record that result explicitly.
- The remaining-user scan still finds other `CodexWatcher.Core.Ids` users and `moifold.cabal` exposure as expected, proving this round is only one direct-owner migration slice and does not approve facade deprecation, Cabal exposure removal, runtime compatibility cleanup, public compatibility removal, or milestone completion.
