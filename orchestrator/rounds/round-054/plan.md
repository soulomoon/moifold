### Goal
Produce bounded import-replacement readiness evidence for the six public import facades named by round 052:

- `CodexWatcher.AppServerClient`
- `CodexWatcher.Core.Ids`
- `CodexWatcher.Workflow.Types`
- `CodexWatcher.Workflow.EventLog`
- `CodexWatcher.Workflow.Execution`
- `CodexWatcher.Workflow.Permission`

The round should turn the round 052 inventory into current recursive import scans, preferred replacement-path evidence, Cabal exposure and package-boundary checks, and a surface-by-surface `keep`, `defer`, or `remove-later` classification. It must not remove wrappers, add deprecation pragmas, change exposed modules, perform broad import rewrites, touch runtime compatibility-file behavior gates, write cleanup policy, expand the roadmap, or approve final removal.

### Approach
Keep the implementation sequential. The selected surfaces share one public import-compatibility story, and splitting this into worker fan-out would create more integration risk than useful parallelism.

Use `orchestrator/project-contract.md` as the shared compatibility contract and cite the active roadmap verification contract instead of restating broad repo-wide rules. Build one round-local readiness artifact, preferably `orchestrator/rounds/round-054/import-replacement-readiness.md`, and add only focused tests or source assertions when the existing suite does not already protect a readiness claim.

The readiness artifact should be evidence-first, not policy. It may recommend a classification for future policy work, but it must not claim deprecation or removal approval. Treat modules that still own concrete moifold semantics differently from pure reexport facades.

### Steps
1. Re-run exact anchored import scans for the selected facades across `src`, `app`, `test`, `examples`, `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`. Use an anchored Haskell import pattern so replacement submodules such as `CodexWatcher.Workflow.EventLog.Core` are not counted as selected-facade imports.
2. Re-run docs and Cabal scans for the selected facade names and preferred replacement module names across `*.cabal`, `*/*.cabal`, `README.md`, `docs`, `examples`, and package candidate directories. Record which package exposes each selected facade and replacement module.
3. For each selected facade, write a readiness entry that includes current exact import users, preferred replacement imports, current Cabal exposure, package-boundary expectation, existing protecting tests, missing evidence if any, and a `keep`, `defer`, or `remove-later` classification.
4. Classify conservatively from current evidence:
   - `CodexWatcher.Workflow.Types` should not be treated as a pure compatibility alias because it owns `MoifoldSpec` and concrete moifold transition helpers.
   - `CodexWatcher.Workflow.EventLog`, `CodexWatcher.Workflow.Execution`, and `CodexWatcher.Workflow.Permission` should distinguish generic replacement APIs from concrete moifold helpers that remain product-owned.
   - `CodexWatcher.AppServerClient` and `CodexWatcher.Core.Ids` should account for current production import volume and domain splitting before any future removal candidate status.
5. Add focused tests or source assertions only where the readiness artifact depends on an unprotected fact. Good candidates are package-boundary assertions that standalone workflow packages expose the replacement modules, do not import the selected moifold compatibility facades, and that the main moifold library still exposes the public facades while they remain compatibility surfaces.
6. Do not rewrite production imports unless a tiny, local rewrite is required to make an evidence assertion meaningful. If any such rewrite is made, document why it is evidence-only and verify behavior remains unchanged.
7. Leave runtime compatibility-file behavior gates from round 053 untouched. Do not edit runtime-file tests, repair behavior, healthcheck behavior, compatibility write timing, golden fixtures, or cleanup policy docs as part of this round.
8. Review the final diff for scope drift: allowed outputs are the readiness artifact, focused readiness tests or assertions if needed, and this round's implementation evidence. No roadmap, project-contract, production compatibility surface, exposed-module, deprecation, or removal changes should appear.

### Verification
Run the task-specific evidence commands and record their results in the readiness artifact or implementation notes:

```sh
rg -n '^ *import +(qualified +)?CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(Types|EventLog|Execution|Permission))(\b| +as +| *$)' src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github
rg -n 'CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(Types|EventLog|Execution|Permission)|Workflow\.Agent\.Codex\.(Client|Transport)|Workflow\.Agent\.Ids|Workflow\.GitHub\.Ids|Workflow\.Spec|Workflow\.EventLog\.Core|Workflow\.EventLog\.File\.Core|Workflow\.EventLog\.Commit\.Core|Workflow\.Execution\.Core|Workflow\.Permission\.Core)' README.md docs examples *.cabal */*.cabal agent-workflow-core agent-workflow-codex agent-workflow-github
rg -n 'exposed-modules|other-modules|CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(Types|EventLog|Execution|Permission)|Workflow\.Agent\.Codex\.(Client|Transport)|Workflow\.Agent\.Ids|Workflow\.GitHub\.Ids|Workflow\.Spec|Workflow\.EventLog\.Core|Workflow\.EventLog\.File\.Core|Workflow\.EventLog\.Commit\.Core|Workflow\.Execution\.Core|Workflow\.Permission\.Core)' *.cabal */*.cabal
```

Run focused tests if tests or source assertions are added:

```sh
cabal test watcher-core-test
```

Run the baseline checks required by the roadmap verification contract before review:

```sh
cabal build all
cabal test watcher-core-test
scripts/validate-workflow-packages.sh
git diff --check
```

If files are staged later in the round, also run:

```sh
git diff --cached --check
```
