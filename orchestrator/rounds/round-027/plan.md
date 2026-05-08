### Goal
Add focused law/assertion coverage for the WorkflowSpec contract obligations selected for round 027: observation consistency, terminal closure, replay determinism, validation, and permission soundness across DocsMigration and one representative moifold indexed workflow, without changing runtime behavior, event codecs, golden fixtures, roadmap files, or compatibility facades.

### Approach
Keep the round sequential and assertion-first. Extend the existing workflow-law section in `test/Main.hs`, which already contains the DocsMigration indexed bridge coverage and the PR-review moifold indexed law coverage introduced by the preceding rounds. Use the additive bridge from round 026 as the assertion target instead of introducing a new workflow harness.

Use DocsMigration as the non-moifold proof because it is the compact second workflow with complete replay, permission, dry-run, and indexed bridge surfaces. Use the PR-review checking indexed bridge as the representative moifold proof because round 026 migrated it through `WorkflowSpecIndexedBridge`; add any missing terminal, observation/apply/replay, and permission assertions there rather than broadening into issue planning or issue implementation lifecycle behavior.

Prefer test-local helper functions in `test/Main.hs` for comparing labels, replay state, planned effects, and bridge outputs. Add production helper APIs only if the assertion cannot be written against the existing public contract, and keep any such helper pure, minimal, and covered by the new tests. Do not change workflow runtime semantics, event JSON, golden fixtures, daemon routing, transaction APIs, or roadmap/controller artifacts.

### Steps
1. Inspect the current `test/Main.hs` workflow-law block around the existing `workflowDocsMigrationIndexed*` tests and `workflowPrReviewMergeabilityFacadeLawPreservesObservationReplayEffectsAndPermissions`, then identify the exact gaps against the selected obligations: observation-to-event/apply consistency, replay determinism, terminal closure, validation, and permission soundness.
2. Add or refine DocsMigration assertions that prove an accepted indexed observation produces the same event, final state, effect partition, labels, terminal status, and replay result as the unindexed `WorkflowSpec` path; include a terminal-state rejection check for both complete and blocked terminal states if only one is currently asserted.
3. Add replay-determinism assertions for DocsMigration that compare repeated bridge/generic replay of the same event list, including state label, terminal status, and replayed effect history, without touching the existing codec fixture or golden fixture content.
4. Add representative moifold assertions against the PR-review checking indexed bridge from round 026. Cover accepted observation parity with the unindexed `MoifoldSpec` path, planned-event/apply consistency, replay determinism for the resulting event list, terminal-state closure where the slice can reach a terminal blocked/clean state, and permission rejection for an effect plan from the wrong phase.
5. If comparison code becomes repetitive, extract only small test-local helpers in `test/Main.hs` near the existing workflow helper functions, such as helpers for state-shape/replay-effect equality or indexed/unindexed transition label comparison.
6. Wire every new assertion into the existing `workflowFacadeExtractionTests` or the adjacent workflow-law aggregation already invoked from `main`, so `cabal test watcher-core-test` actually exercises the new checks.
7. Confirm no event codec definitions, fixture lists, golden files, daemon routing, compatibility facade modules, roadmap files, `selection.md`, or `state.json` changed.

### Verification
Run focused compile/test validation first, then the roadmap baseline:

1. `cabal build watcher-core-test`
2. `cabal test watcher-core-test`
3. `cabal build all`
4. `git diff --check`

If staging occurs later in the round, also run `git diff --cached --check`. Review the final diff to ensure it is limited to tests and any justified tiny helper API, with no `worker-plan.json` because this plan keeps the round sequential.
