### Changes Made
- `orchestrator/rounds/round-056/import-facade-cleanup-policy.md`: added the round-local import-facade cleanup policy with scope and non-goals, refreshed selected-facade import counts, Cabal exposure evidence, surface-by-surface `keep`/`defer` policy, protecting tests, missing evidence before deprecation/removal, and explicit non-approval for removal.
- `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`: aligned the framework policy with rounds 052, 054, and 056 by adding the evidence artifacts, preserving preferred imports as reusable-consumer guidance only, and recording conservative `keep`/`defer` classifications.

### Tests
- Existing `test/Main.hs` package-boundary, facade availability, event-log parity, execution dry-run, permission parity, and indexed workflow compatibility tests are cited as the protecting tests for this docs-only policy round.
- Existing compile-through coverage in `test/AppServerSpec.hs`, `test/CliSpec.hs`, `test/GhGitSpec.hs`, and `test/RuntimeSpec.hs` is cited for facade consumers.
- Evidence scan: `rg -n '^ *import +(qualified +)?CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(Types|EventLog|Execution|Permission))($| +|\()' src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github` passed and found selected-facade counts of 28, 65, 10, 3, 4, and 1, with no selected-facade imports under standalone package candidates or `examples`.
- Cabal exposure scan: `rg -n 'exposed-modules|CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(Types|EventLog|Execution|Permission)|Workflow\.Agent\.Codex\.(Client|Transport)|Workflow\.Agent\.Ids|Workflow\.GitHub\.Ids|Workflow\.Spec|Workflow\.EventLog\.Core|Workflow\.EventLog\.File\.Core|Workflow\.EventLog\.Commit\.Core|Workflow\.Execution\.Core|Workflow\.Permission\.Core)' *.cabal */*.cabal` passed and confirmed selected facades remain exposed by `moifold.cabal` while replacement modules are exposed by `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`.
- `git diff --check` passed with no whitespace errors.
- `cabal test watcher-core-test` passed: 1 of 1 test suites and 1 of 1 test cases passed.
- Diff banned-claim grep over removal/deprecation/Cabal exposure/runtime-policy terms found only deleted old wording and new negative/non-goal wording; it found no affirmative claim that this round approves removal, deprecation pragmas, Cabal exposure changes, or runtime compatibility-file policy changes.

### Notes
- `orchestrator/project-contract.md` was reviewed and left unchanged. Its durable invariant already says public compatibility facades stay available until safe removal is proven with import, build, and behavior coverage.
- No production Haskell source, imports, Cabal descriptors, runtime compatibility-file policy, runtime files, roadmap files, deprecation pragmas, or removal approvals were changed.
- Runtime compatibility-file policy remains a separate sibling direction under `direction-006-runtime-compatibility-cleanup-policy`; round 055 was used only as boundary context.
