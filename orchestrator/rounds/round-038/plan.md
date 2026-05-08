### Goal
Define the compatibility and deprecation policy for the future
`agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`
package candidates as an artifact-only documentation slice. The result should
give source-backed preferred-import guidance, classify moifold-owned
compatibility facades, and record explicit gates before deprecation pragmas,
import migrations, wrapper removal, descriptor changes, or package publication
can be considered.

### Approach
Keep the implementation sequential and documentation-only. Add a focused policy
artifact under `docs/agentic-workflow-framework/` and, if needed, add a single
README index link in the same docs directory. Do not edit production source,
tests, Cabal descriptors, changelog/release notes, roadmap files,
`orchestrator/state.json`, review artifacts, merge artifacts, or generated
release artifacts.

The policy should be grounded in these existing sources instead of inventing a
new compatibility model:

- `docs/agentic-workflow-framework/package-extraction-readiness.md`
- `docs/agentic-workflow-framework/package-identity-versioning-contract.md`
- `docs/agentic-workflow-framework/release-metadata-policy.md`
- `docs/agentic-workflow-framework/implemented-api-freeze.md`
- `orchestrator/project-contract.md`
- current source surfaces such as `src/CodexWatcher/AppServerClient.hs`,
  `src/CodexWatcher/Core/Ids.hs`, `src/CodexWatcher/Workflow/Types.hs`,
  `src/CodexWatcher/Workflow/EventLog.hs`,
  `src/CodexWatcher/Workflow/Execution.hs`, and
  `src/CodexWatcher/Workflow/Permission.hs`
- boundary assertions around package ownership and compatibility facades in
  `test/Main.hs`

The core decision is conservative: preferred imports can be documented now, but
compatibility wrappers stay available. A preferred-import policy is not a
deprecation pragma, not an import migration, and not removal approval.

### Steps
1. Create `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`
   with status text making clear that this is a compatibility policy for future
   external package candidates, not a code migration, package descriptor
   migration, release note, upload approval, or wrapper removal.
2. Add an evidence section that cites the readiness report, package identity
   contract, release metadata policy, implemented API freeze, project contract,
   `moifold.cabal`, current wrapper modules, and package-boundary tests as the
   source of truth.
3. Add a package-by-package preferred-import table:
   - For `agent-workflow-core`, prefer the implemented
     `CodexWatcher.Workflow.*` core modules from the package candidate for
     reusable workflow code. Classify moifold-facing modules such as
     `CodexWatcher.Workflow.Types`, `Workflow.EventLog`, `Workflow.Execution`,
     and `Workflow.Permission` as product compatibility or adapter facades
     where they expose concrete `MoifoldSpec`, `WatcherEvent`,
     `SomeWatcherState`, concrete effects, runtime action types, or
     compatibility behavior.
   - For `agent-workflow-codex`, prefer
     `CodexWatcher.AppServerProtocol`,
     `CodexWatcher.Workflow.Agent*`, and
     `CodexWatcher.Workflow.Agent.Codex*`. State explicitly that
     `CodexWatcher.AppServerClient` is a moifold-owned compatibility facade
     that reexports `CodexWatcher.Workflow.Agent.Codex.Client` and
     `CodexWatcher.Workflow.Agent.Codex.Transport`; new reusable-package
     guidance should point at the adapter modules directly.
   - For `agent-workflow-github`, prefer
     `CodexWatcher.Workflow.GitHub.Ids`,
     `CodexWatcher.Workflow.GitHub.Remote`, and
     `CodexWatcher.Workflow.GitHub.Command`. Classify
     `CodexWatcher.Core.Ids` as a moifold convenience facade over agent and
     GitHub ids, not the preferred public import for standalone reusable
     package consumers.
4. Add a compatibility-facade status table for at least:
   `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`,
   `CodexWatcher.Workflow.Types`, `CodexWatcher.Workflow.EventLog`,
   `CodexWatcher.Workflow.Execution`, and
   `CodexWatcher.Workflow.Permission`. For each row, record current source
   evidence, preferred import direction, allowed current use, deprecation
   readiness, and removal status.
5. Add policy rules for moifold-owned compatibility wrappers and compatibility
   files:
   - wrappers stay available until a later selected deprecation/removal round
     proves safety;
   - compatibility files such as `issue-state.json`, `daemon-state.json`,
     `planning-state.json`, PR URL files, block state, repair state, runtime
     owner files, and compatibility snapshots keep their names and meanings;
   - event schemas, golden logs, replay policy, dry-run rendering, action
     ordering, prompt schemas, structured-output compatibility, runtime
     ownership, healthcheck, and repair remain moifold-owned and outside the
     reusable package compatibility promise.
6. Add explicit deprecation-readiness gates. Before adding any deprecation
   pragma or warning, a future round must prove preferred imports are documented,
   source import coverage is known, downstream/internal consumers have a
   migration path, package descriptors and docs agree, and behavior checks still
   pass. The policy should say that this round does not add those pragmas.
7. Add explicit removal gates. Before removing any wrapper, facade, compatibility
   file, or old import path, a future round must be selected specifically for
   removal and must provide import-scan evidence, build evidence, focused
   compatibility behavior evidence, old-log/golden fixture evidence when
   relevant, changelog/release-note evidence when externally visible, and
   reviewer approval. Removal is blocked unless every gate is satisfied.
8. Add package-specific release-note constraints that mirror the release
   metadata policy: release notes may describe preferred imports and
   compatibility status only after the policy exists, must call out pre-1.0
   status and moifold-owned policy, and must not imply package upload, source
   distribution approval, CI readiness, public API stability beyond the approved
   contract, or facade removal.
9. If the new policy document is created, add one link to it from
   `docs/agentic-workflow-framework/README.md` under the implemented contract
   documents. Keep the README edit to an index entry only.
10. Inspect the final diff and confirm it is limited to the compatibility policy
    document and the optional docs README index link. Do not create
    `worker-plan.json`.

### Verification
For this artifact-only round, verify the implementation by inspection and
lightweight checks rather than build-heavy package validation:

- `git diff --check`
- `git diff --no-index --check /dev/null docs/agentic-workflow-framework/compatibility-deprecation-policy.md`
  if the policy file is new and unstaged
- final diff inspection confirming no changes to `orchestrator/state.json`,
  roadmap files, production source, tests, Cabal descriptors, changelog,
  release notes, review artifacts, merge artifacts, wrapper modules, or
  compatibility files
- source-backed content review against the readiness report, package identity
  contract, release metadata policy, implemented API freeze, project contract,
  `src/CodexWatcher/AppServerClient.hs`, moifold facade modules, and
  `test/Main.hs` package-boundary assertions

`cabal build all` and `cabal test watcher-core-test` are not required for a
docs-only implementation that does not change code, Cabal descriptors, tests,
or generated artifacts. If the implementer touches anything outside the docs
artifact scope, they must rerun the roadmap baseline checks from
`verification.md` and explain why the scope changed.
