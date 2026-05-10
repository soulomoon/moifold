### Changes Made
- `moifold.cabal`: retry metadata edit only in the `watcher-core-test` stanza; added exactly `BoundaryPolicySpec` and `TestSupport.SourceScan` to `other-modules` so the extracted test modules compile and remain reachable.
- `test/Main.hs`: preserved the existing `workflowBoundaryPolicyTests` aggregation path; imported the extracted `textNeedlesInOrder` helper from `TestSupport.SourceScan` and removed imports that became unused after the existing boundary-policy extraction.
- `test/BoundaryPolicySpec.hs`: preserved the extracted boundary-policy runner and assertions; removed a duplicate uncalled event-log commit assertion that remains wired in `test/Main.hs`, and imported `RuntimeCommandSpec (..)` so existing record-field comparisons compile.
- `test/TestSupport/SourceScan.hs`: preserved reusable scan helpers; exported `textNeedlesInOrder` for the remaining `test/Main.hs` assertions.
- `orchestrator/rounds/round-084/implementation-notes.md`: recorded retry scope, commands, changed paths, and verification evidence.

### Tests
- `test/BoundaryPolicySpec.hs`: preserves the extracted package-boundary, Cabal/package dependency, reusable package import/token boundary, adapter reexport, runtime-render facade parity, and IssueImplement lifecycle boundary checks behind `workflowBoundaryPolicyTests`.
- `test/TestSupport/SourceScan.hs`: preserves extracted scanner behavior and `assertNoTextMatches` violation detail output used by `BoundaryPolicySpec` and remaining `test/Main.hs` assertions.

Commands run:
- `cabal test watcher-core-test`: passed. The test suite compiled `BoundaryPolicySpec` and `TestSupport.SourceScan`, ran `watcher-core-test`, and reported `Test suite watcher-core-test: PASS`.
- `cabal build all`: passed. Cabal built the `moifold` executable with GHC 9.12.2.
- `git diff --check`: passed. No whitespace errors reported.
- `git status --short --untracked-files=all`: dirty worktree with `M moifold.cabal`, pre-existing `M orchestrator/state.json`, `M test/Main.hs`, untracked round artifacts, `test/BoundaryPolicySpec.hs`, and `test/TestSupport/SourceScan.hs`.
- `git diff --cached --check`: not run because no staging occurred.

### Notes
Retry scope stayed limited to the authorized `watcher-core-test` metadata plus direct compile fixes exposed after the extracted modules became part of the test-suite build. No package dependencies, exposed modules, production code, docs, fixtures, runtime compatibility files, roadmap/state edits, public deprecation/removal, or broader Cabal metadata were added by this retry.

Changed paths owned by this implementation/retry are:
- `moifold.cabal`
- `test/Main.hs`
- `test/BoundaryPolicySpec.hs`
- `test/TestSupport/SourceScan.hs`
- `orchestrator/rounds/round-084/implementation-notes.md`

The existing `orchestrator/state.json` modification and untracked `orchestrator/rounds/round-084/{plan.md,review.md,selection.md}` artifacts were present in the worktree context and were not edited by this retry.
