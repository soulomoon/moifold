### Goal
Add the first additive compatibility bridge between the unindexed `WorkflowSpec`
surface and the indexed `IndexedWorkflowSpec` surface, reducing duplicated hook
plumbing while proving current moifold and DocsMigration behavior remains
unchanged.

### Approach
Keep the round sequential and additive. The selected direction touches the core
workflow API plus moifold adapters, and `orchestrator/state.json` has
`max_parallel_rounds: 1` and `worker_mode: none`; splitting this into workers
would create unnecessary coordination around shared API files.

Implement the bridge in `agent-workflow-core`, close to
`CodexWatcher.Workflow.Indexed.Spec`, so it stays generic and obeys
`orchestrator/project-contract.md` package ownership rules. The bridge should
adapt existing `WorkflowSpec` hooks into indexed implementations through small
wrapper/projection helpers rather than changing event schemas, replay codecs,
golden fixtures, daemon routing, or compatibility file formats.

Use one current moifold indexed adapter and `DocsMigrationSpec` as migration
proofs. Prefer replacing duplicated adapter method bodies with the bridge only
where the source/target label wrappers already exist and the behavior can be
shown identical. Leave the remaining adapters on the old spelling if converting
them would broaden the round beyond the selected compatibility bridge.

### Steps
1. Inspect `agent-workflow-core/src/CodexWatcher/Workflow/Spec.hs`,
   `agent-workflow-core/src/CodexWatcher/Workflow/Indexed/Spec.hs`,
   `src/CodexWatcher/Workflow/Types.hs`, `src/CodexWatcher/Workflow/DocsMigration.hs`,
   and the moifold indexed adapter modules under
   `src/CodexWatcher/Workflow/Moifold/**/Indexed.hs` to identify the duplicated
   unindexed-to-indexed hook pattern.
2. Add a generic bridge helper or bridge data type in the core indexed spec
   surface that delegates replay, validation, effect permission, terminal
   checks, labels, planned transition construction, and effect-label projection
   to an underlying `WorkflowSpec`.
3. Export the new bridge from the existing core module list without removing or
   renaming `WorkflowSpec`, `IndexedWorkflowSpec`, existing existential wrappers,
   or compatibility helper exports.
4. Migrate `DocsMigrationSpec` to use the bridge for the hooks whose indexed
   wrappers only carry source/target labels around existing unindexed
   `DocsMigration*` values. Keep its event codec, fixture contract, daemon
   helpers, dry-run/execute helpers, and public constructors unchanged.
5. Migrate one representative moifold indexed adapter, preferably the smallest
   PR-review worker/checking adapter or the issue-planning adapter section whose
   hook bodies are straightforward delegations to `MoifoldSpec`, to use the same
   bridge. Do not rewrite all adapters unless the bridge makes that mechanical
   and low-risk.
6. Add focused regression tests in `test/Main.hs` that prove the bridged
   DocsMigration path and the selected moifold adapter still match the old
   unindexed behavior for labels, replay state projection, terminal semantics,
   validation hooks, effect permission hooks, and pre/post effect labels.
7. Extend the existing source-scan/inventory assertions so reviewers can see the
   bridge is generic core API, the old compatibility imports/modules still
   exist, and no moifold lifecycle policy was imported into
   `agent-workflow-core`.
8. Review the diff for accidental edits to event JSON type labels, golden
   fixtures, daemon/runtime behavior, roadmap files, `selection.md`, and
   `orchestrator/state.json`; those are out of scope for this round.

### Verification
Run the focused workflow-spec regression target first:

```sh
cabal test watcher-core-test --test-options='--pattern workflow'
```

Then run the active roadmap and project-contract baseline checks:

```sh
cabal build all
cabal test watcher-core-test
git diff --check
```

If the implementer stages changes before review, also run:

```sh
git diff --cached --check
```

Reviewer evidence should explicitly mention that event schemas/golden fixtures
were not changed, `agent-workflow-core` still has no moifold-specific imports,
DocsMigration fixture replay still passes, and the migrated moifold adapter
preserves compatibility labels, replay, terminal, validation, and permission
behavior.
