### Goal

Migrate the remaining exact `test/Main.hs` import of `CodexWatcher.AppServerClient` to direct owner imports for the app-server symbols that the test module still uses, while preserving all test behavior and leaving the public compatibility facade exposed.

Roadmap lineage: `2026-05-11-00-highest-value-cleanup` / `rev-001`, milestone `milestone-003-import-convergence-package-boundaries`, direction `direction-010-appserverclient-import-convergence`, extracted item `round-151-main-appserverclient-direct-owner-import-migration`.

### Approach

Keep this as a serial, one-file import convergence slice. In `test/Main.hs`, replace only:

```haskell
import CodexWatcher.AppServerClient
```

with explicit imports from the direct owner modules:

```haskell
import CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn (..))
import CodexWatcher.Workflow.Agent.Codex.Transport (AppServerEndpoint (..))
import CodexWatcher.Workflow.Agent.Codex.Interpreter (AppServerInterpreter (..))
```

Keep the existing `CodexWatcher.AppServerProtocol` import for `AppServerRequest`. Do not alter test bodies, helper definitions, assertions, production modules, package descriptors, docs, policy strings, or the facade module. This round is import convergence only; it is not deprecation, public API cleanup, facade removal, Cabal exposure cleanup, package publication approval, or milestone completion.

### Steps

1. Inspect `test/Main.hs` imports and confirm the only in-scope facade import is `import CodexWatcher.AppServerClient`.
2. Replace that import with the three direct owner imports for `AppServerTurn (..)`, `AppServerEndpoint (..)`, and `AppServerInterpreter (..)`.
3. Preserve all existing `test/Main.hs` declarations, helper bodies, assertions, and failure messages.
4. Verify `CodexWatcher.AppServerProtocol` remains imported for `AppServerRequest`.
5. Run the focused import and symbol scans listed below before package validation.
6. Inspect `git diff -- test/Main.hs` and `git diff --name-only` to confirm the implementation stayed inside the selected file.
7. Run package validation and whitespace checks. If staging is later performed by another role, run the cached diff whitespace check too.

### Verification

Focused scans:

```sh
rg -n '^import CodexWatcher\.AppServerClient$' test/Main.hs
rg -n '^import CodexWatcher\.Workflow\.Agent\.Codex\.(Client|Transport|Interpreter)|^import CodexWatcher\.AppServerProtocol' test/Main.hs
rg -n 'AppServerEndpoint|AppServerTurn|AppServerInterpreter|AppServerRequest' test/Main.hs
rg -n 'module CodexWatcher\.Workflow\.Agent\.Codex\.Client|AppServerTurn' agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs
rg -n 'module CodexWatcher\.Workflow\.Agent\.Codex\.Transport|AppServerEndpoint' agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs
rg -n 'module CodexWatcher\.Workflow\.Agent\.Codex\.Interpreter|AppServerInterpreter' agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Interpreter.hs
rg -n '^import CodexWatcher\.AppServerClient$|CodexWatcher\.AppServerClient' src app test moifold.cabal docs
```

Expected scan results:

- The selected-file facade import guard should find no `import CodexWatcher.AppServerClient` in `test/Main.hs`.
- Direct-owner import scans should show the three direct owner imports in `test/Main.hs`, with `CodexWatcher.AppServerProtocol` still present for `AppServerRequest`.
- Symbol anchor scans should still find the `AppServerEndpoint`, `AppServerTurn`, `AppServerInterpreter`, and `AppServerRequest` uses in `test/Main.hs`.
- Direct owner export evidence scans should show the three owner modules define/export the selected symbols.
- The broad `CodexWatcher.AppServerClient` scan may still show the facade module, Cabal exposure, docs, and `BoundaryPolicySpec` policy strings; it should not show any remaining exact `src`, `app`, or `test` import of the facade.

Diff and package checks:

```sh
git diff -- test/Main.hs
git diff --name-only
cabal test watcher-core-test
cabal build all
git diff --check
git diff --cached --check
```

`git diff --cached --check` is required only if this round is staged later.

### Risks

- An overly broad import change could accidentally move `AppServerRequest` away from `CodexWatcher.AppServerProtocol`; keep that import unchanged.
- Reordering or rewriting test bodies would create unnecessary behavior risk and make review harder; this round should be an import-only patch.
- Broad scans will continue to find intentional compatibility references in Cabal, docs, policy tests, and the facade module; do not treat those as failures for this selected item.
- A passing import migration is not evidence that `CodexWatcher.AppServerClient` can be deprecated, unexposed, or removed.

### Out Of Scope

- No production code changes.
- No changes outside `test/Main.hs` for implementation.
- No edits to test bodies, helper behavior, assertions, or failure messages.
- No Cabal, docs, public facade, deprecation, policy-string, package descriptor, or compatibility-removal changes.
- No milestone completion, roadmap update, release gate, or public package publication claim.

### Worker Fan-Out

Worker mode: none.

No `worker-plan.json` is required or justified. The selected work is a single import-only edit in one file with no non-overlapping ownership boundary to fan out.
