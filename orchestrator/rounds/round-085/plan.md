### Goal

Extract the remaining facade extraction, import-policy, and compatibility policy checks from `test/Main.hs` into focused watcher-core test ownership for `round-085-facade-import-policy-test-split`.

This round is test-only. It should make the public-facade policy evidence easier to review while preserving the current classifications, runner reachability, assertion strength, and useful failure detail for `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.EventLog`, and `CodexWatcher.Workflow.Permission`.

### Approach

Keep the split sequential and centered on the existing `workflowFacadeExtractionTests` runner. Create a focused test module, preferably `test/FacadeImportPolicySpec.hs`, exporting `workflowFacadeImportPolicyTests :: IO Bool`. Reuse `test/TestSupport/SourceScan.hs` for source and Cabal scans. Add only small, scan-oriented support helpers there if a moved assertion already needs them; do not add a broad new support layer.

Likely clusters to inspect and move from `test/Main.hs`:

- The facade/import-policy registration in `workflowFacadeExtractionTests` near the current aggregation point.
- Source-scan policy checks currently around `workflowSpecModuleKeepsCoreBoundary`, `workflowIndexedSpecModuleKeepsCoreBoundary`, `workflowSpecIndexedBridgeSourceScans`, and `workflowSpecInventoryCoversCurrentSpecSurfaces`.
- Public facade parity and compatibility-policy checks around `workflowFacadeReplayMatchesEventLog`, `workflowFacadeInitialApplyMatchesReplay`, `workflowPermissionFacadeMatchesStateMachine`, `workflowPermissionCoreChecksMatchMoifoldPermission`, and `workflowPermissionPolicyMatchesMoifoldPermission`.
- Any directly related helper values that only serve these checks. Leave unrelated workflow behavior, indexed workflow parity, daemon behavior, DocsMigration behavior, agent-role behavior, fixtures, replay repair, runtime compatibility-file behavior, and large behavior-test clusters in `test/Main.hs` for later selected directions.

Keep `test/Main.hs` as the suite aggregator. It should import the new module and call `workflowFacadeImportPolicyTests` from `workflowFacadeExtractionTests`; it should not silently drop any existing check. If a moved function keeps the old assertion label, preserve it. If labels are made clearer, keep the same failure detail level or improve it without weakening the predicate.

Allowed Cabal metadata scope is limited to the `watcher-core-test` stanza in `moifold.cabal`: add the new test module to `other-modules`, and add no new dependencies unless compilation proves an existing test-only import was previously supplied only through `Main.hs` and there is no narrower alternative. Do not change library exposed modules, production modules, package dependencies for production components, docs, fixtures, runtime compatibility files, roadmap files, or `orchestrator/state.json`.

### Steps

1. Reconfirm the starting state before editing:
   - `git status --short --untracked-files=all`
   - `wc -l test/Main.hs`
   - `rg -n "workflowFacadeExtractionTests|workflowSpecModuleKeepsCoreBoundary|workflowIndexedSpecModuleKeepsCoreBoundary|workflowSpecIndexedBridgeSourceScans|workflowSpecInventoryCoversCurrentSpecSurfaces|workflowFacadeReplayMatchesEventLog|workflowFacadeInitialApplyMatchesReplay|workflowPermissionFacadeMatchesStateMachine|workflowPermissionCoreChecksMatchMoifoldPermission|workflowPermissionPolicyMatchesMoifoldPermission" test/Main.hs`
2. Add `test/FacadeImportPolicySpec.hs` with a single exported runner, `workflowFacadeImportPolicyTests`. Move the selected facade/import-policy checks into it with the imports needed to compile them locally.
3. Keep `test/TestSupport/SourceScan.hs` as shared scanner support. Move only generic scanner helpers if the extracted module needs them and they are not facade-specific. Do not move policy-specific predicates into support just to shrink the new module.
4. Update `test/Main.hs` to import `FacadeImportPolicySpec (workflowFacadeImportPolicyTests)`, call it from `workflowFacadeExtractionTests`, and remove only imports and helpers that became unused because the selected checks moved.
5. Update `moifold.cabal` only under `test-suite watcher-core-test` `other-modules` with `FacadeImportPolicySpec` and any new `TestSupport.*` module if one is genuinely needed.
6. Preserve policy classifications and non-removal semantics in the tests:
   - Preferred imports must remain tested as guidance, not deprecation, warning policy, Cabal exposure change, public API removal, or source/app import convergence approval.
   - `CodexWatcher.AppServerClient` and `CodexWatcher.Core.Ids` must remain classified as compatibility facades that stay available.
   - `CodexWatcher.Workflow.EventLog` and `CodexWatcher.Workflow.Permission` must remain treated as mixed/concrete moifold bridge facades whose public status is deferred until later exact gates.
   - The tests must still prove runner reachability through `watcher-core-test`; no extracted runner may be left uncalled.
7. Record implementation evidence in `orchestrator/rounds/round-085/implementation-notes.md` during the implementation phase, including before/after `test/Main.hs` line counts, moved test ownership, commands run, and changed paths. The planner should not write that file.

### Verification

Run the full behavior-preserving gates because this round touches test code and test metadata:

- `cabal test watcher-core-test`
- `cabal build all`
- `git diff --check`
- `git status --short --untracked-files=all`

If staging is performed later, also run `git diff --cached --check`.

Reviewer-facing checks should confirm:

- `workflowFacadeImportPolicyTests` is reachable from `workflowFacadeExtractionTests` and therefore from `watcher-core-test`.
- The moved assertions still print useful PASS/FAIL labels and still report source-scan violations with path and line detail through `TestSupport.SourceScan`.
- The diff is limited to `test/Main.hs`, the new focused test module, optional focused `TestSupport` additions, minimal `watcher-core-test` metadata, and round-local implementation/review artifacts.
- There are no changes to production code, docs, fixtures, runtime compatibility files, roadmap/state, public deprecation/removal status, facade removal, Cabal exposed modules, source/app import convergence, workflow behavior split, or large module decomposition.

### Worker Fan-Out

Do not use worker fan-out for this round. The edits are tightly coupled through the same `test/Main.hs` runner, the same `watcher-core-test` Cabal stanza, and one focused extracted module, so splitting workers would add integration risk without a clean non-overlapping ownership boundary. Do not write `worker-plan.json`.
