### Changes Made
- `test/FacadeImportPolicySpec.hs`: added focused `workflowFacadeImportPolicyTests` ownership for the facade/import-policy assertions moved out of `test/Main.hs`. The runner preserves the existing PASS/FAIL labels, source-scan violation path/line detail through `TestSupport.SourceScan`, replay parity predicates, permission-policy checks, and compatibility-facade policy classifications.
- `test/Main.hs`: kept `workflowFacadeExtractionTests` as the suite aggregator and replaced the moved individual checks with a single `workflowFacadeImportPolicyTests` call. Removed only imports and helper definitions that became unused after the move.
- `moifold.cabal`: added `FacadeImportPolicySpec` to the `watcher-core-test` `other-modules` list only.
- `orchestrator/rounds/round-085/implementation-notes.md`: recorded round scope, moved ownership, line counts, changed paths, and verification results.

### Tests
- `test/FacadeImportPolicySpec.hs`: verifies the moved facade/import-policy checks:
  - `workflowSpecModuleKeepsCoreBoundary`
  - `workflowIndexedSpecModuleKeepsCoreBoundary`
  - `workflowSpecIndexedBridgeSourceScans`
  - `workflowSpecInventoryCoversCurrentSpecSurfaces`
  - `workflowFacadeReplayMatchesEventLog`
  - `workflowFacadeInitialApplyMatchesReplay`
  - `workflowPermissionFacadeMatchesStateMachine`
  - `workflowPermissionCoreChecksMatchMoifoldPermission`
  - `workflowPermissionPolicyMatchesMoifoldPermission`
- `test/Main.hs`: verifies runner reachability by calling `workflowFacadeImportPolicyTests` from `workflowFacadeExtractionTests`, which is still reached by `watcher-core-test`.

Commands run:
- `git status --short --untracked-files=all` before editing: dirty worktree already contained `M orchestrator/state.json` plus untracked `orchestrator/rounds/round-085/plan.md` and `orchestrator/rounds/round-085/selection.md`.
- `wc -l test/Main.hs` before editing: `15910 test/Main.hs`.
- `rg -n "workflowFacadeExtractionTests|workflowSpecModuleKeepsCoreBoundary|workflowIndexedSpecModuleKeepsCoreBoundary|workflowSpecIndexedBridgeSourceScans|workflowSpecInventoryCoversCurrentSpecSurfaces|workflowFacadeReplayMatchesEventLog|workflowFacadeInitialApplyMatchesReplay|workflowPermissionFacadeMatchesStateMachine|workflowPermissionCoreChecksMatchMoifoldPermission|workflowPermissionPolicyMatchesMoifoldPermission" test/Main.hs`: confirmed the selected checks and aggregate runner before moving them.
- `cabal test watcher-core-test`: first run failed after compiling `FacadeImportPolicySpec` because `test/Main.hs` still had now-unused `assertNoTextMatches`, `sameReplay`, and `sameReplayText`; those stale leftovers were removed.
- `cabal test watcher-core-test`: passed. The suite compiled `FacadeImportPolicySpec`, ran `watcher-core-test`, and reported `Test suite watcher-core-test: PASS`.
- `cabal build all`: passed. Cabal built the `moifold` executable with GHC 9.12.2.
- `git diff --check`: passed before and after writing this notes file.
- `git status --short --untracked-files=all`: dirty worktree with owned edits in `moifold.cabal`, `test/Main.hs`, new `test/FacadeImportPolicySpec.hs`, and this notes file; pre-existing `M orchestrator/state.json` plus untracked round plan/selection artifacts remain present.
- `git diff --cached --check`: not run because no staging occurred.

Line counts:
- `test/Main.hs` before: 15910 lines.
- `test/Main.hs` after implementation before this notes file: 15473 lines.
- `test/FacadeImportPolicySpec.hs` after implementation: 486 lines.

### Notes
Moved ownership is limited to the facade/import-policy test cluster selected for `round-085-facade-import-policy-test-split`. The public compatibility facades remain available; no production code, docs, fixtures, runtime compatibility files, roadmap files, exposed modules, public deprecation/removal status, facade exposure, source/app import convergence, or `orchestrator/state.json` edits were made by this implementation.

Changed paths owned by this implementation are:
- `moifold.cabal`
- `test/Main.hs`
- `test/FacadeImportPolicySpec.hs`
- `orchestrator/rounds/round-085/implementation-notes.md`

The existing `orchestrator/state.json` modification and untracked `orchestrator/rounds/round-085/{plan.md,selection.md}` artifacts were present before implementation and were not edited as part of this round.
