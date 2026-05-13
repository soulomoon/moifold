### Goal
Remove the now-unused exact `CodexWatcher.AppServerClient` import from
`test/WorkflowEventLogSpec.hs` only, preserving every workflow event-log test
body and leaving the public compatibility facade available and exposed.

Roadmap lineage:

- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-010-appserverclient-import-convergence`
- Extracted item id:
  `round-149-workflow-event-log-spec-appserverclient-import-cleanup`

### Approach
Make a single import-list cleanup in `test/WorkflowEventLogSpec.hs`: delete
only the exact unqualified `import CodexWatcher.AppServerClient` line. Do not
add replacement imports unless the file fails to compile, because the selected
scope says the file has no remaining AppServerClient-owned symbol use.

Keep this as import convergence evidence, not facade removal evidence. The
round must not change production code, package descriptors, documentation,
policy strings, test wiring, public facade exposure, deprecation wording, or
runtime compatibility files. Remaining `CodexWatcher.AppServerClient` users are
recorded by scan and left for later exact selections.

### Steps
1. Open `test/WorkflowEventLogSpec.hs` and remove only the line
   `import CodexWatcher.AppServerClient`.
2. Leave all language pragmas, options, module exports, helper definitions,
   fixtures, assertions, and test registrations unchanged.
3. Run the selected-file facade import guard:
   `rg -n '^import CodexWatcher\.AppServerClient\b' test/WorkflowEventLogSpec.hs`.
   The expected result is no matches.
4. Run the selected-file AppServerClient-owned symbol absence scan:
   `rg -n 'AppServerTurn|AppServerEndpoint|AppServerClientFailure|JsonRpcError|formatAppServerClientFailure|AppServerClientOptions|defaultAppServerClientOptions' test/WorkflowEventLogSpec.hs`.
   The expected result is no matches.
5. Run the broad remaining facade scan:
   `rg -n 'CodexWatcher\.AppServerClient' src app test docs *.cabal agent-workflow-*`.
   Record remaining matches as out of scope unless the selected file still
   appears.
6. Inspect `git diff -- test/WorkflowEventLogSpec.hs` and confirm the diff is
   exactly the one import-line deletion.
7. Inspect `git diff --name-only` and `git status --short`. Confirm the
   implementation added no touched files beyond `test/WorkflowEventLogSpec.hs`;
   preserve pre-existing orchestrator artifacts such as `orchestrator/state.json`
   and the round selection/plan files without reverting them.

### Verification
Required validation for the implementer/reviewer:

- `rg -n '^import CodexWatcher\.AppServerClient\b' test/WorkflowEventLogSpec.hs`
- `rg -n 'AppServerTurn|AppServerEndpoint|AppServerClientFailure|JsonRpcError|formatAppServerClientFailure|AppServerClientOptions|defaultAppServerClientOptions' test/WorkflowEventLogSpec.hs`
- `rg -n 'CodexWatcher\.AppServerClient' src app test docs *.cabal agent-workflow-*`
- `git diff -- test/WorkflowEventLogSpec.hs`
- `git diff --name-only`
- `git status --short`
- `cabal test watcher-core-test`
- `cabal build all`
- `git diff --check`
- `git diff --cached --check` if staging is performed

The first two `rg` commands should return no selected-file matches after the
implementation. The broad scan may still report remaining facade users in other
tests, docs, Cabal exposure, and the facade module itself; those matches are
expected blockers for future selected work, not failures for this round.

### Risks
- The file has `-Wno-unused-imports`, so compile success alone cannot prove the
  import was stale. The selected-file symbol scan is required evidence.
- The broad scan includes documentation and Cabal exposure entries that must
  remain untouched in this round. Treating those remaining matches as removal
  approval would violate the active roadmap and project contract.
- A test failure after the import deletion likely means the selected symbol scan
  missed a symbol or the file was concurrently changed. In that case, narrow the
  fix to this file and do not migrate adjacent AppServerClient importers.

### Out Of Scope
- No changes to `src/CodexWatcher/AppServerClient.hs`.
- No changes to `test/WorkflowExecutionSpec.hs`, `test/Main.hs`,
  `test/BoundaryPolicySpec.hs`, or any other remaining importer.
- No production code, test wiring, Cabal, docs, public facade, deprecation,
  compatibility-file, release, or roadmap-status changes.
- No claim that `CodexWatcher.AppServerClient` is deprecated, removable, or safe
  to remove from exposed modules.

### Worker Fan-Out
Worker mode: none.

No `worker-plan.json` is needed. The selected slice is a single import deletion
with one owned implementation file and sequential validation; fan-out would add
coordination cost without creating independent ownership boundaries.
