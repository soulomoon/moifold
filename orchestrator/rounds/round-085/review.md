### Checks Run
- Command: `cabal test watcher-core-test`
  Result: pass. The suite built `FacadeImportPolicySpec`, ran `watcher-core-test`, printed the moved facade/import-policy PASS labels, and ended with `Test suite watcher-core-test: PASS`.
- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`.
- Command: `git diff --check`
  Result: pass. No whitespace errors reported.
- Command: `git diff --cached --check`
  Result: pass. No staged diff whitespace errors reported.
- Command: `git status --short --untracked-files=all`
  Result: pass for expected dirty round state. Status showed `M moifold.cabal`, `M orchestrator/state.json`, `M test/Main.hs`, and untracked `orchestrator/rounds/round-085/{implementation-notes.md,plan.md,selection.md}` plus `test/FacadeImportPolicySpec.hs`.

### Plan Compliance
- Reconfirm starting context and round lineage: met. `orchestrator/state.json` selects `round-085` under roadmap `2026-05-11-00-highest-value-cleanup`, revision `rev-001`, direction `direction-003-facade-import-policy-test-split`.
- Add focused test module exporting `workflowFacadeImportPolicyTests`: met. `test/FacadeImportPolicySpec.hs` exports only `workflowFacadeImportPolicyTests` and owns the nine selected facade/import-policy checks.
- Keep `test/Main.hs` as aggregator and preserve runner reachability: met. `test/Main.hs` imports `FacadeImportPolicySpec (workflowFacadeImportPolicyTests)` and calls it from `workflowFacadeExtractionTests`, so `watcher-core-test` still reaches the moved checks.
- Update Cabal metadata only for `watcher-core-test` `other-modules`: met. `moifold.cabal` adds only `FacadeImportPolicySpec` under the `test-suite watcher-core-test` `other-modules`; exposed modules remain unchanged, including `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.EventLog`, and `CodexWatcher.Workflow.Permission`.
- Preserve assertion/failure detail and policy classifications: met. The moved checks keep the existing PASS/FAIL labels, `TestSupport.SourceScan` path/line violation detail through `assertNoTextMatches`, replay parity checks, permission policy checks, and compatibility-facade policy classifications.
- Stay within selected scope: met. The implementation diff is limited to `moifold.cabal`, `test/Main.hs`, `test/FacadeImportPolicySpec.hs`, and round-local artifacts. The existing `orchestrator/state.json` diff records controller active-round/review metadata; there are no production, docs, fixture, runtime compatibility file, roadmap revision, public deprecation/removal, facade removal, exposed-module, or source/app import-convergence changes.
- Record implementation evidence: met. `orchestrator/rounds/round-085/implementation-notes.md` records changed paths, line counts, moved ownership, and verification evidence.

### Decision
**APPROVED**

### Evidence
`test/Main.hs` shrank from 15910 to 15473 lines, while the new `test/FacadeImportPolicySpec.hs` is 486 lines and contains the extracted runner plus the selected checks:
`workflowSpecModuleKeepsCoreBoundary`, `workflowIndexedSpecModuleKeepsCoreBoundary`, `workflowSpecIndexedBridgeSourceScans`, `workflowSpecInventoryCoversCurrentSpecSurfaces`, `workflowFacadeReplayMatchesEventLog`, `workflowFacadeInitialApplyMatchesReplay`, `workflowPermissionFacadeMatchesStateMachine`, `workflowPermissionCoreChecksMatchMoifoldPermission`, and `workflowPermissionPolicyMatchesMoifoldPermission`.

`moifold.cabal` changed only by adding `FacadeImportPolicySpec` to `watcher-core-test` `other-modules`. `rg` inspection confirmed the public compatibility facades remain exposed in the library stanza and no exposed-module entry was removed or deprecated.

The full baseline passed independently in this worktree: `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and `git diff --cached --check`.
