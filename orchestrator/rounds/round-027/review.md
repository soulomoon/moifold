### Checks Run
- Command: `cabal build watcher-core-test`
  Result: pass; target was already up to date.
- Command: `cabal test watcher-core-test`
  Result: pass; `watcher-core-test` built and ran successfully, including the new indexed PR-review checking and DocsMigration law assertions, with `1 of 1 test suites (1 of 1 test cases) passed`.
- Command: `cabal build all`
  Result: pass; all targets were already up to date.
- Command: `git diff --check`
  Result: pass; no whitespace errors reported.
- Command: `git diff --cached --check`
  Result: pass; no staged whitespace errors reported.
- Command: `git diff --stat`
  Result: pass; substantive implementation diff is limited to `test/Main.hs`, with the controller's active-round metadata present in `orchestrator/state.json`.
- Command: `git diff --name-status`
  Result: pass; changed tracked files are `orchestrator/state.json` and `test/Main.hs`.
- Command: `git diff -- orchestrator/state.json`
  Result: pass; diff only records the active `round-027` review-stage metadata and artifact paths. I did not edit `state.json`.
- Command: `git diff -- test/Main.hs`
  Result: pass; diff adds law/assertion coverage and test-local helpers only.
- Command: `git diff --name-only -- orchestrator/roadmaps moifold.cabal src agent-workflow-core agent-workflow-codex agent-workflow-github golden test/Main.hs orchestrator/rounds/round-027`
  Result: pass; tracked implementation changes are limited to `test/Main.hs`, with no roadmap, cabal, production source, adapter, or golden fixture changes.

### Plan Compliance
- Step 1, inspect current workflow-law block and identify selected obligation gaps: met. The implementation extends the existing PR-review checking indexed bridge and DocsMigration law areas in `test/Main.hs`.
- Step 2, add/refine DocsMigration accepted-observation parity and terminal rejection coverage: met. DocsMigration indexed law coverage now checks blocked terminal parity in addition to complete and active terminal status, and replay-failure coverage rejects completion after blocked terminal state.
- Step 3, add DocsMigration replay-determinism assertions: met. The DocsMigration law now replays the same event list twice through both unindexed and indexed paths and compares replay state/effects.
- Step 4, add representative moifold PR-review checking indexed assertions: met. The PR-review checking bridge now compares indexed/unindexed observation, planned event, apply state shape, effect labels, replay determinism, terminal closure, and wrong-phase permission rejection.
- Step 5, keep helper extraction test-local and minimal: met. New helpers are local to `test/Main.hs`: `prReviewCheckingAppliedEffectsMatch`, `prReviewCheckingEffectLabels`, and `lastEffectPlanLabelsAre`.
- Step 6, wire assertions into the existing workflow-law aggregation: met. `workflowPrReviewCheckingIndexedSpecPreservesTerminalAndPermissionLaws` is added to `workflowFacadeExtractionTests`, and the existing DocsMigration tests were strengthened in place.
- Step 7, confirm no out-of-scope artifacts changed: met for substantive implementation. No production behavior, event codecs, golden fixtures, daemon routing, compatibility facades, roadmap files, cabal files, or adapter packages changed. `orchestrator/state.json` contains active round metadata already required by the orchestrator review stage and was not edited by this review.

### Decision
**APPROVED**

### Evidence
The round is assertion-first and stays inside the selected scope. `test/Main.hs` adds terminal, observation/apply/replay, validation, and permission checks for DocsMigration and the PR-review checking indexed bridge without changing runtime semantics or public compatibility surfaces.

The active roadmap verification baselines passed: `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, and `git diff --cached --check`. The plan-specific focused build also passed with `cabal build watcher-core-test`.

The project-contract invariants remain intact. Event schemas, golden fixtures, dry-run rendering, daemon/runtime behavior, package ownership, and compatibility facades are untouched. The new coverage reinforces replay determinism, observation-to-event/apply consistency, permission soundness, and terminal-state closure, which are the verification anchors for this roadmap slice.
