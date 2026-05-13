### Goal
Remove the single stale `import CodexWatcher.AppServerClient` line from
`test/WorkflowExecutionSpec.hs` while preserving every test body, helper,
assertion, fixture path, runner hook, and failure message.

Roadmap lineage:
`2026-05-11-00-highest-value-cleanup` / `rev-001`,
`milestone-003-import-convergence-package-boundaries`,
`direction-010-appserverclient-import-convergence`,
`round-150-workflow-execution-spec-stale-appserverclient-import-removal`.

### Approach
This is an import-only convergence slice. The selected file currently imports
the `CodexWatcher.AppServerClient` compatibility facade, but the selected
symbol scan has no `AppServerTurn`, `AppServerEndpoint`, client failure,
formatting, transport, session, or endpoint helper use in
`test/WorkflowExecutionSpec.hs` that requires a replacement direct-owner
import.

Keep the public facade and all remaining references intact. This round must
not treat a local stale import as deprecation, Cabal exposure cleanup, docs
cleanup, public facade removal, or downstream migration approval. The project
contract and active verification bundle continue to own those broader gates.

### Steps
1. Open `test/WorkflowExecutionSpec.hs` and delete only the exact stale line
   `import CodexWatcher.AppServerClient`.
2. Do not reorder imports, do not run broad formatting, and do not edit any
   test body, helper, fixture, assertion, runner wiring, production source,
   Cabal file, documentation, compatibility facade, or policy file.
3. Run the focused selected-file facade import guard:
   `rg -n "^import CodexWatcher\\.AppServerClient$|CodexWatcher\\.AppServerClient" test/WorkflowExecutionSpec.hs`.
   Expected result after the edit: no matches.
4. Run the selected-file AppServerClient-owned symbol absence scan:
   `rg -n "\\b(AppServerTurn|AppServerEndpoint|AppServerClient|AppServerClientError|ClientFailure|clientFailure|parseAppServerEndpoint|renderAppServerEndpoint|withAppServer|sendAppServer|postTurn|appServerSession)\\b" test/WorkflowExecutionSpec.hs`.
   Expected result after the edit: no matches. If this finds a real symbol use,
   stop and return to planning instead of adding a replacement import.
5. Run the broad remaining facade scan:
   `rg -n "^import CodexWatcher\\.AppServerClient$|CodexWatcher\\.AppServerClient" src app test docs moifold.cabal`.
   Record remaining matches as expected out-of-scope references, including the
   public facade module, Cabal exposure, docs and policy text, and
   `test/Main.hs`.
6. Inspect the implementation diff with
   `git diff -- test/WorkflowExecutionSpec.hs` and confirm it contains only
   the one import-line deletion.
7. Inspect the changed-path set with `git diff --name-only` and confirm the
   implementation changed only `test/WorkflowExecutionSpec.hs`, aside from
   orchestrator artifacts already owned by this round.

### Verification
Run these commands before review:

- `rg -n "^import CodexWatcher\\.AppServerClient$|CodexWatcher\\.AppServerClient" test/WorkflowExecutionSpec.hs`
- `rg -n "\\b(AppServerTurn|AppServerEndpoint|AppServerClient|AppServerClientError|ClientFailure|clientFailure|parseAppServerEndpoint|renderAppServerEndpoint|withAppServer|sendAppServer|postTurn|appServerSession)\\b" test/WorkflowExecutionSpec.hs`
- `rg -n "^import CodexWatcher\\.AppServerClient$|CodexWatcher\\.AppServerClient" src app test docs moifold.cabal`
- `git diff -- test/WorkflowExecutionSpec.hs`
- `git diff --name-only`
- `cabal test watcher-core-test`
- `cabal build all`
- `git diff --check`
- `git diff --cached --check` if any changes are staged

The first two focused scans should be empty for
`test/WorkflowExecutionSpec.hs`. The broad scan should still show remaining
out-of-scope compatibility facade, Cabal, docs/policy, and `test/Main.hs`
references. Package validation must pass without changing test behavior.

### Risks
- A broad formatter or import sorter could create unrelated churn in a large
  test module. Avoid formatting and delete only the selected import line.
- The broad scan will still find legitimate remaining references. Do not
  "fix" them in this round; they are separate gates and later selected slices.
- If the selected-file symbol scan unexpectedly finds an AppServerClient-owned
  symbol after the import deletion, adding a direct owner import would exceed
  the selected item. Stop and report the blocker.
- `test/WorkflowExecutionSpec.hs` currently has `-Wno-unused-imports`, so build
  success alone is not enough evidence. Keep the focused scan and exact diff
  checks as required verification.

### Out Of Scope
- `test/Main.hs` and any symbol mapping for its remaining `AppServerClient`
  use.
- `test/BoundaryPolicySpec.hs` policy strings.
- `src/CodexWatcher/AppServerClient.hs`.
- `moifold.cabal` exposed-module or package wiring changes.
- Documentation, release notes, Haddock, deprecation language, and compatibility
  policy changes.
- Production code, direct owner modules, fixtures, runtime compatibility files,
  public facade exposure, Cabal exposure removal, and any compatibility removal
  claim.
- Roadmap ordering, roadmap revision updates, implementation notes, review
  artifacts, merge artifacts, or controller state.

### Worker Fan-Out
Worker mode: none.

No `worker-plan.json` is needed or authorized. This is a serial one-line
implementation slice with no separable ownership boundaries.
