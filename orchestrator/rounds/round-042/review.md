### Checks Run
- Command: `cabal build agent-workflow-core:lib:agent-workflow-core`
  Result: pass; Cabal reported the standalone core library target was up to date.
- Command: `cabal build agent-workflow-codex:lib:agent-workflow-codex`
  Result: pass; Cabal reported the standalone Codex library target was up to date.
- Command: `cabal build agent-workflow-github:lib:agent-workflow-github`
  Result: pass; Cabal reported the standalone GitHub library target was up to date.
- Command: `cabal build moifold:lib:moifold`
  Result: pass; Cabal reported the moifold library target was up to date.
- Command: `cabal build moifold:exe:moifold`
  Result: pass; Cabal reported the moifold executable target was up to date.
- Command: `cabal build all`
  Result: pass; Cabal reported the project was up to date.
- Command: `cabal test watcher-core-test`
  Result: pass; `watcher-core-test` completed successfully, including the workflow package-boundary assertions and compatibility regression suite. Cabal reported 1 of 1 test suites passed.
- Command: `rg -n "moifold:agent-workflow-(core|codex|github)|^library agent-workflow-(core|codex|github)" moifold.cabal cabal.project agent-workflow-core/agent-workflow-core.cabal agent-workflow-codex/agent-workflow-codex.cabal agent-workflow-github/agent-workflow-github.cabal`
  Result: pass; no matches, exit 1 as expected for the removed internal sublibrary wiring.
- Command: `rg -n "agent-workflow-(core|codex|github) >=0.1 && <0.2" moifold.cabal agent-workflow-codex/agent-workflow-codex.cabal`
  Result: pass; found standalone bounds in `moifold.cabal` main library lines 159-161, `watcher-core-test` lines 191-193, and the existing Codex-to-core dependency in `agent-workflow-codex/agent-workflow-codex.cabal` line 57.
- Command: `rg -n "CodexWatcher\\.(AppServerClient|ActionExecutor|ChildDaemon|Daemon|DaemonLoop|Domain\\.|EventLogRepair|Healthcheck|Runtime\\.|StateMachine|Workflow\\.Moifold\\.)" agent-workflow-core/src agent-workflow-codex/src agent-workflow-github/src`
  Result: pass; no matches, exit 1 as expected for the no-moifold-lifecycle-import boundary scan.
- Command: `git diff --check`
  Result: pass; no whitespace errors.
- Command: `git diff --cached --name-only`
  Result: pass; no staged files, so `git diff --cached --check` was not applicable.

### Plan Compliance
- Step 1, update `moifold.cabal` to remove internal workflow sublibraries and consume standalone package dependencies: met. The diff removes the `library agent-workflow-core`, `library agent-workflow-codex`, and `library agent-workflow-github` stanzas from `moifold.cabal`. The main library and `watcher-core-test` now depend on `agent-workflow-core >=0.1 && <0.2`, `agent-workflow-codex >=0.1 && <0.2`, and `agent-workflow-github >=0.1 && <0.2`; the executable dependency on `moifold` is unchanged.
- Step 2, leave `cabal.project` package entries unchanged: met. `cabal.project` still lists `.`, `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`, with no source distribution, repository, CI, or release validation wiring added.
- Step 3, update package-boundary assertions for standalone consumption: met. `test/Main.hs` now registers `workflowMoifoldCabalConsumesStandaloneWorkflowPackages`, `workflowCoreStandalonePackageKeepsPackageBoundary`, `workflowCodexStandalonePackageKeepsPackageBoundary`, and `workflowGithubStandalonePackageKeepsPackageBoundary`. The assertions verify no internal sublibrary stanzas or `moifold:agent-workflow-*` dependencies remain, verify standalone package bounds in both moifold consumers, and preserve descriptor/source-boundary checks for all three standalone packages.
- Step 4, update adapter reexport assertion for standalone dependencies while preserving compatibility facades: met. `workflowMoifoldCabalLibraryDoesNotReexportAdapters` now expects standalone Codex and GitHub package bounds. `src/CodexWatcher/AppServerClient.hs` remains a thin compatibility module reexporting `CodexWatcher.Workflow.Agent.Codex.Client` and `CodexWatcher.Workflow.Agent.Codex.Transport`.
- Step 5, inspect imports after the Cabal rewrite and add only required direct dependencies: met. The standalone package builds, moifold library/executable builds, and full build all pass without source-module changes or extra compatibility wrappers.
- Step 6, confirm the round did not broaden scope: met for the implementation payload. The package/code diff is limited to `moifold.cabal` and focused `test/Main.hs` assertions. There are no source-module edits, no compatibility facade removals, no event schema or golden fixture edits, no runtime owner, daemon, healthcheck, repair, lifecycle, CI, source distribution, docs, release-note, or package-upload changes. `orchestrator/state.json` is active controller state for round-042 review and was not edited during this review.
- Verification, run the package-specific, product, full, boundary, and diff-hygiene checks: met. All required commands passed; no staged files made the cached diff check not applicable.
- Implementation notes: met. `orchestrator/rounds/round-042/implementation-notes.md` records the implementation scope and validation evidence, including the no-staged-files cached-diff status.

### Decision
**APPROVED**

### Evidence
The implemented Cabal wiring matches selected `item-042-moifold-local-consumer-wiring`: moifold no longer defines or consumes internal `moifold:agent-workflow-*` sublibraries, while both the main library and `watcher-core-test` consume the local standalone workflow package candidates through approved `>=0.1 && <0.2` bounds.

The compatibility facade requirement is preserved. `src/CodexWatcher/AppServerClient.hs` remains available as a reexport-only compatibility module over the Codex client and transport modules, and the main moifold library still avoids owning the app-server websocket dependency directly.

The reusable packages remain free of moifold lifecycle, daemon, domain, runtime, state-machine, healthcheck, repair, and compatibility ownership imports under the required boundary scan. The round also avoids the explicitly excluded work: no source distribution, CI, docs/examples, package upload, compatibility facade removal, event schema/golden fixture change, or lifecycle/runtime/healthcheck/repair behavior change.
