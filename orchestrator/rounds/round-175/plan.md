### Goal

Migrate only `src/CodexWatcher/EffectInterpreter.hs` from the `CodexWatcher.Core.Ids` compatibility facade to direct ID owner imports for the selected symbols, preserving the module's exported API, data constructors, effect compilation behavior, request-id threading, runtime command planning, rendered prompt/input selection, and public compatibility facade exposure.

Lineage: roadmap `2026-05-11-00-highest-value-cleanup`, revision `rev-001`, milestone `milestone-003-import-convergence-package-boundaries`, direction `direction-011-core-ids-import-convergence`, extracted item `round-175-effect-interpreter-core-ids-split-import-migration`.

### Approach

Keep the implementation as an import-only migration in `src/CodexWatcher/EffectInterpreter.hs`.

Replace the current `CodexWatcher.Core.Ids` import:

```haskell
import CodexWatcher.Core.Ids
  ( BranchName (..)
  , CommitSha
  , IssueNumber (..)
  , PrNumber (..)
  , RepoName
  , RequestId
  , ThreadId
  , nextRequestId
  )
```

with direct owner imports:

```haskell
import CodexWatcher.Workflow.Agent.Ids (RequestId, ThreadId, nextRequestId)
import CodexWatcher.Workflow.GitHub.Ids
  ( BranchName (..)
  , CommitSha
  , IssueNumber (..)
  , PrNumber (..)
  , RepoName
  )
```

Do not edit function bodies, type definitions, exports, constructors, tests, Cabal files, docs, fixtures, runtime compatibility files, or `CodexWatcher.Core.Ids`. This round is one migration slice only; remaining facade users are expected and must be recorded rather than treated as completion or removal approval.

### Steps

1. Open `src/CodexWatcher/EffectInterpreter.hs` and locate the existing `CodexWatcher.Core.Ids` import block.
2. Replace that single import block with the two direct owner imports from `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`, preserving the selected symbol set exactly.
3. Keep all declarations and exports unchanged, including `CompiledEffectPlan`, `EffectRuntimeConfig`, `PlannedAction`, `TurnRuntimeConfig`, `agentTurnPlanForEffect`, `compileEffect`, `compileEffectPlan`, and `issuePlanFileText`.
4. Check the resulting diff and confirm it contains only the import migration in `src/CodexWatcher/EffectInterpreter.hs`.
5. Scan remaining `CodexWatcher.Core.Ids` users across production, tests, docs, and Cabal metadata, and record in implementation notes or review evidence that this is a single import-convergence slice, not facade deprecation, removal, or milestone completion.

### Verification

Run these checks from the round worktree:

```sh
git diff -- src/CodexWatcher/EffectInterpreter.hs
rg -n "CodexWatcher\\.Core\\.Ids" src/CodexWatcher/EffectInterpreter.hs
cabal build all
cabal test watcher-core-test
git diff --check
git diff --cached --check
rg -n "CodexWatcher\\.Core\\.Ids" src app test docs *.cabal
```

Expected verification evidence:

- `git diff -- src/CodexWatcher/EffectInterpreter.hs` shows only the replacement of the `CodexWatcher.Core.Ids` import with the two direct owner imports.
- The focused scan of `src/CodexWatcher/EffectInterpreter.hs` finds no `CodexWatcher.Core.Ids` import.
- `cabal build all` succeeds.
- `cabal test watcher-core-test` succeeds.
- `git diff --check` succeeds.
- `git diff --cached --check` succeeds if any changes are staged; if nothing is staged, record that no cached diff existed.
- The broader scan still shows remaining `CodexWatcher.Core.Ids` users outside this file, proving the round is one migration slice and not compatibility facade removal.

### Worker Fan-Out

Worker fan-out is not used. The selected implementation has one write target and one import block in `src/CodexWatcher/EffectInterpreter.hs`; splitting it would create coordination overhead without non-overlapping implementation ownership. Do not write `orchestrator/rounds/round-175/worker-plan.json` for this round.
