### Goal

Record current artifact-only readiness evidence for
`CodexWatcher.AppServerClient` import convergence so a later round can move
only safe internal users to direct
`CodexWatcher.Workflow.Agent.Codex.Client` and
`CodexWatcher.Workflow.Agent.Codex.Transport` imports with explicit behavior
gates.

This round does not change source, tests, package descriptors, fixtures, docs,
roadmap files, controller state, public APIs, app-server protocol, endpoint
parsing, session behavior, timeout behavior, fallback behavior, command
rendering, failure formatting, Cabal exposure, or compatibility facade
availability.

### Approach

Produce one round-local evidence artifact for
`round-105-appserverclient-import-convergence-readiness`. Re-read the active
selection, roadmap verification bundle, project contract, round-097 facade
scan, and round-104 closeout context; then run live scans over the current
worktree and classify only the observed `CodexWatcher.AppServerClient` uses.

The classification should separate:

- `source blocker`: production imports that touch endpoint parsing,
  app-server protocol, session handling, command rendering, timeout, fallback,
  or failure formatting and therefore need focused behavior checks before a
  direct-owner import migration.
- `turn-classifier source candidate`: production imports whose observed use is
  limited to `AppServerTurn` or shared turn-completion classification, but
  still need app-server turn parsing/classification coverage before migration.
- `endpoint/session source candidate`: production imports centered on
  endpoint-backed thread launch/read, client options, request ids, session
  initialization, or transport calls.
- `command-rendering/failure-formatting source candidate`: production imports
  that render app-server commands or user-visible failures.
- `timeout/fallback source candidate`: production imports that depend on
  timeout options, fallback behavior, healthcheck behavior, or loop fallback
  policy.
- `test-policy evidence`: test imports that intentionally preserve facade,
  workflow-agent, app-server protocol, docs-migration, event-log, execution, or
  indexed workflow coverage while later convergence remains gated.
- `public exposure`: Cabal exposed-module entries and any public import-policy
  checks proving the compatibility facade remains available.
- `documentation/policy reference`: docs or policy mentions that describe
  compatibility, readiness, release, or deprecation policy but do not approve
  migration, deprecation, Cabal exposure removal, or facade removal.

Do not create `worker-plan.json`. The work is a serial evidence inventory with
one owned artifact and no non-overlapping implementation work.

### Steps

1. Confirm starting coordination state and scope:
   - Read `orchestrator/state.json`.
   - Read `orchestrator/rounds/round-105/selection.md`.
   - Read `orchestrator/project-contract.md`.
   - Read
     `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`.
   - Read
     `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`
     around `milestone-003-import-convergence-package-boundaries` and
     `direction-010-appserverclient-import-convergence`.
   - Read `orchestrator/rounds/round-097/facade-import-scan-refresh.md`.
   - Read round-104 artifacts only as needed to confirm milestone 003 remains
     in progress after the EventLog/Permission readiness round.
   - Run `git status --short` and `git diff --name-status`; record that this
     implementation changes only round-local artifacts, aside from any
     pre-existing controller-owned state movement.

2. Confirm the compatibility facade shape:

   ```sh
   sed -n '1,120p' src/CodexWatcher/AppServerClient.hs
   ```

   Record that `CodexWatcher.AppServerClient` remains a public compatibility
   reexport of `CodexWatcher.Workflow.Agent.Codex.Client` and
   `CodexWatcher.Workflow.Agent.Codex.Transport`. Do not edit the facade.

3. Run the current exact import scan for `CodexWatcher.AppServerClient`:

   ```sh
   rg -n '^import[[:space:]]+(qualified[[:space:]]+)?CodexWatcher\.AppServerClient([[:space:]]|$|\()' \
     src app test agent-workflow-core agent-workflow-codex agent-workflow-github
   ```

   Record exact counts by area: `src`, `app`, `test`,
   `agent-workflow-core`, `agent-workflow-codex`, and
   `agent-workflow-github`. Record every importing file and its import list.

4. Run a broader reference scan to catch non-import policy, descriptor, and
   documentation evidence:

   ```sh
   rg -n 'CodexWatcher\.AppServerClient([[:space:]]|$|\.|\(|")' \
     src app test agent-workflow-core agent-workflow-codex agent-workflow-github \
     docs examples scripts moifold.cabal agent-workflow-core/agent-workflow-core.cabal \
     agent-workflow-codex/agent-workflow-codex.cabal \
     agent-workflow-github/agent-workflow-github.cabal cabal.project
   ```

   Classify matches as live imports, package exposure, standalone package
   candidate references, docs/policy references, or test import-policy
   assertions.

5. Run the direct-owner exposure and import scan:

   ```sh
   rg -n 'CodexWatcher\.Workflow\.Agent\.Codex\.(Client|Transport)|CodexWatcher\.AppServerClient|exposed-modules:' \
     src app test agent-workflow-core agent-workflow-codex agent-workflow-github \
     moifold.cabal agent-workflow-core/agent-workflow-core.cabal \
     agent-workflow-codex/agent-workflow-codex.cabal \
     agent-workflow-github/agent-workflow-github.cabal cabal.project
   ```

   Record that `moifold.cabal` still exposes
   `CodexWatcher.AppServerClient`, and that `agent-workflow-codex` exposes
   the direct owner modules without importing the compatibility facade.

6. For each live source importer from step 3, inspect the local use sites
   enough to classify the file against the selected gates:
   - endpoint parsing;
   - app-server protocol;
   - session handling or session initialization;
   - command rendering;
   - timeout behavior;
   - fallback behavior;
   - failure formatting;
   - turn-classifier behavior.

   Record whether the smallest later migration candidate is the whole file, a
   narrower import-list change, or no migration until a behavior slice is
   selected. Do not modify any imports.

7. For each live test importer from step 3, classify why it should remain
   test-policy evidence for now:
   - facade/public import availability;
   - workflow-agent coverage;
   - app-server protocol coverage;
   - docs-migration workflow coverage;
   - event-log workflow coverage;
   - workflow execution coverage;
   - indexed workflow coverage.

   Record any test that could become a later direct-owner import candidate
   only with a focused assertion-preservation gate.

8. Record public exposure and documentation evidence:
   - package descriptor exposure for `CodexWatcher.AppServerClient`;
   - absence or presence of facade imports in standalone package candidates;
   - docs and policy references under `docs`, `examples`, and `scripts`;
   - any public import-policy tests.

   State explicitly that these references do not approve public deprecation,
   Cabal exposure removal, facade removal, release/publication, milestone
   completion, or terminal completion.

9. Name the verification gates required before any later convergence,
   public exposure, Cabal exposure, deprecation, or removal work:
   - endpoint parser coverage for affected endpoint strings and thread ids;
   - app-server protocol request/response parsing and rendering coverage;
   - session initialization and existing-session handling coverage;
   - command rendering and dry-run/request text stability;
   - timeout behavior coverage for probe, healthcheck, loop, and fallback
     paths as applicable;
   - fallback behavior coverage for unavailable app-server or failed turn
     reads;
   - failure-formatting coverage for user-visible errors;
   - turn-classifier coverage for `AppServerTurn` success, failure, and
     incomplete outputs;
   - package descriptor, public API, docs/Haddock, downstream import, and test
     policy evidence for any exact surface later moved or removed.

10. Write the evidence artifact under `orchestrator/rounds/round-105/`,
    keeping it explicit that this round is readiness evidence only and is not
    import migration, deprecation, package exposure change, facade removal,
    behavior change, release approval, milestone completion, or terminal
    completion.

11. Confirm no worker fan-out artifact exists:

    ```sh
    test ! -e orchestrator/rounds/round-105/worker-plan.json
    ```

12. Run changed-path and descriptor hygiene checks:

    ```sh
    git diff -- src app test moifold.cabal cabal.project \
      agent-workflow-core agent-workflow-codex agent-workflow-github
    git diff -- moifold.cabal agent-workflow-core/agent-workflow-core.cabal \
      agent-workflow-codex/agent-workflow-codex.cabal \
      agent-workflow-github/agent-workflow-github.cabal cabal.project
    git diff --check
    git diff --cached --check
    ```

### Verification

The implementer should verify the artifact by re-running the exact scans above
and checking that:

- the evidence artifact records exact live import counts for
  `CodexWatcher.AppServerClient` across `src`, `app`, `test`, and standalone
  package candidates;
- `CodexWatcher.AppServerClient` is confirmed as a compatibility reexport of
  `CodexWatcher.Workflow.Agent.Codex.Client` and
  `CodexWatcher.Workflow.Agent.Codex.Transport`;
- every live source importer is classified by the endpoint parsing,
  app-server protocol, session handling, command rendering, timeout, fallback,
  failure-formatting, and turn-classifier gates it requires before any later
  direct-owner migration;
- every live test importer is classified as test-policy evidence or a later
  assertion-preserving migration candidate;
- public exposure, package descriptor, standalone package candidate, docs, and
  policy references are classified without implying deprecation, Cabal exposure
  removal, facade removal, release/publication, milestone completion, or
  terminal completion;
- no source, test, app, package descriptor, fixture, docs, roadmap,
  controller-state, public API, app-server protocol, endpoint parsing, session
  behavior, timeout behavior, fallback behavior, command rendering, failure
  formatting, runtime behavior, or Cabal exposure change is made by this
  round;
- `worker-plan.json` is absent; and
- `git diff --check` passes.

Because this is artifact-only, `cabal build all` and
`cabal test watcher-core-test` may be skipped only if changed-path evidence
shows the diff is limited to round-local orchestrator artifacts.
