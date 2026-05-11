### Goal

Refresh the current import, exposure, documentation, and standalone-package
candidate inventory for `round-097-facade-import-scan-refresh` as an
artifact-only evidence round.

The inventory must cover these selected compatibility facades:
`CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`,
`CodexWatcher.Workflow.EventLog`, and `CodexWatcher.Workflow.Permission`.
It should give later import-convergence slices current evidence after the
test-split and runtime-compatibility fixture rounds, without changing imports,
public module exposure, docs, package descriptors, production behavior, tests,
roadmap files, or controller state.

### Approach

Keep the round sequential and read-only except for round-local artifacts. Worker
fan-out is not justified because the work is one coupled inventory over the
same four facade surfaces, and splitting it would mostly duplicate scan setup
and classification rules.

The implementer should create one evidence artifact:
`orchestrator/rounds/round-097/facade-import-scan-refresh.md`.
The usual `orchestrator/rounds/round-097/implementation-notes.md` should record
the exact commands, pass/fail results, changed-path evidence, and
artifact-only baseline rationale.

The evidence artifact should record:

- Roadmap lineage: active roadmap
  `2026-05-11-00-highest-value-cleanup`, revision `rev-001`, milestone
  `milestone-003-import-convergence-package-boundaries`, direction
  `direction-009-facade-import-scan-refresh`, and extracted item
  `round-097-facade-import-scan-refresh`.
- Non-goals: no import migration, Cabal exposure change, public deprecation,
  facade removal, compatibility-file cleanup classification, runtime behavior
  change, release approval, or milestone completion claim.
- For each selected facade: facade file, facade shape, current Cabal exposure,
  direct-owner replacement modules visible from source, current references
  grouped by `src`, `app`, `test`, package descriptors, docs, examples/scripts,
  standalone package candidates, and prior round evidence where relevant.
- For each selected facade: a classification of each remaining reference as
  one of `safe direct-owner candidate`, `mixed/product-owned bridge`,
  `test-policy evidence`, `public exposure`, `documentation/policy reference`,
  or `blocked/needs later evidence`.
- Blockers and next-slice notes for later convergence rounds, especially
  behavior checks required by the active verification bundle for
  `AppServerClient`, `Core.Ids`, `Workflow.EventLog`, and
  `Workflow.Permission`.

### Steps

1. Re-read and record the required control-plane inputs before scanning:
   `orchestrator/state.json`, `orchestrator/rounds/round-097/selection.md`,
   `orchestrator/project-contract.md`,
   `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`,
   and
   `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`.
2. Confirm the facade module shapes from the source files without editing them:
   `src/CodexWatcher/AppServerClient.hs`,
   `src/CodexWatcher/Core/Ids.hs`,
   `src/CodexWatcher/Workflow/EventLog.hs`, and
   `src/CodexWatcher/Workflow/Permission.hs`.
3. Create
   `orchestrator/rounds/round-097/facade-import-scan-refresh.md` with sections
   for scope, lineage, non-goals, scan commands, per-facade inventory,
   classifications, blockers, and artifact-only verification.
4. Run a broad selected-facade reference scan over source, app, tests,
   standalone package candidates, docs, examples, scripts, package descriptors,
   and Cabal project files:

   ```sh
   rg -n "CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.EventLog|Workflow\\.Permission)" \
     src app test agent-workflow-core agent-workflow-codex agent-workflow-github \
     docs examples scripts *.cabal cabal.project
   ```

5. Run a narrowed import-only scan so the artifact can distinguish true Haskell
   import users from docs, Cabal exposure, and policy references:

   ```sh
   rg -n "^import[[:space:]]+(qualified[[:space:]]+)?CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.EventLog|Workflow\\.Permission)([[:space:]]|$|\\()" \
     src app test agent-workflow-core agent-workflow-codex agent-workflow-github
   ```

6. Run a package exposure and direct-owner scan across all package descriptors:

   ```sh
   rg -n "exposed-modules:|CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.EventLog|Workflow\\.Permission)|CodexWatcher\\.Workflow\\.(Agent\\.Codex|Agent\\.Ids|GitHub\\.Ids|EventLog\\.|Permission\\.Core)" \
     moifold.cabal agent-workflow-core/agent-workflow-core.cabal \
     agent-workflow-codex/agent-workflow-codex.cabal \
     agent-workflow-github/agent-workflow-github.cabal cabal.project
   ```

7. Run direct-owner import scans to identify replacement paths that are already
   in use and to avoid classifying a facade reference as blocked merely because
   owner modules are unused:

   ```sh
   rg -n "^import[[:space:]]+(qualified[[:space:]]+)?CodexWatcher\\.Workflow\\.(Agent\\.Codex\\.(Client|Transport)|Agent\\.Ids|GitHub\\.Ids|EventLog\\.(Core|File\\.Core|Commit\\.Core)|Audit|Permission\\.Core)([[:space:]]|$|\\()" \
     src app test agent-workflow-core agent-workflow-codex agent-workflow-github
   ```

8. For `CodexWatcher.AppServerClient`, record whether each remaining import
   appears to use Codex client/session/transport behavior that can later move
   to `CodexWatcher.Workflow.Agent.Codex.Client` and/or
   `CodexWatcher.Workflow.Agent.Codex.Transport`. Mark blockers that need
   endpoint parsing, app-server protocol, session handling, command rendering,
   or failure-formatting evidence before migration.
9. For `CodexWatcher.Core.Ids`, record whether each remaining import needs
   agent ids, GitHub ids, or both. Mark combined users as blocked until a later
   slice proves parser/renderer stability for repo names, branch names, commit
   SHAs, PR numbers, issue numbers, thread ids, turn ids, request ids, and
   review thread ids as applicable.
10. For `CodexWatcher.Workflow.EventLog`, separate generic owner-module users
    from concrete moifold bridge users. Treat references that depend on
    `initializeMoifoldWorkflow`, `applyMoifoldWorkflowEvent`, or
    `replayMoifoldWorkflowEvents` as product-owned bridge evidence unless a
    later round proves a safe owner split. Record blockers for golden replay,
    event JSON `type` stability, old-log parsing, and transition/replay parity.
11. For `CodexWatcher.Workflow.Permission`, separate reusable
    `CodexWatcher.Workflow.Permission.Core` use from concrete moifold
    permission helpers such as `validateMoifoldEffectPlan` and
    `moifoldPermissionPolicy`. Record blockers for permission soundness,
    phase-validation errors, state/effect validation, concrete `MoifoldSpec`
    behavior, public API, and downstream-user evidence.
12. Record docs and policy references separately from imports. In particular,
    docs that describe preferred imports or deferred compatibility status are
    not migration, deprecation, Cabal exposure, or removal approval.
13. Record standalone package-candidate results for
    `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`
    separately from the main `moifold` library. If no selected facade imports
    are found there, state that as local candidate evidence only, not external
    downstream approval.
14. Compare the refreshed evidence to prior round artifacts only as history:
    `orchestrator/rounds/round-083/cleanup-inventory.md`,
    `orchestrator/rounds/round-085/implementation-notes.md`, and any cited
    policy docs. Do not copy stale counts forward without rerunning the current
    scans.
15. In the implementation notes, record exact command output summaries, the
    artifact paths written, and changed-path evidence. If any scan fails, record
    the failure and either rerun a corrected read-only scan or mark the missing
    evidence as a blocker.

### Verification

Run artifact-only verification after writing the inventory and implementation
notes:

```sh
git status --short --untracked-files=all
git diff --name-only
git diff --check
rg -n "deprecat|remov|migrat|delete|rename|approval|Cabal exposure" \
  orchestrator/rounds/round-097/facade-import-scan-refresh.md \
  orchestrator/rounds/round-097/implementation-notes.md
```

The reviewer should require changed-path evidence showing only round-097
orchestrator artifacts changed, expected to be:

- `orchestrator/rounds/round-097/facade-import-scan-refresh.md`
- `orchestrator/rounds/round-097/implementation-notes.md`

If the implementation touches production code, test code, package descriptors,
docs, fixtures, roadmap files, `orchestrator/state.json`, public API, runtime
compatibility files, or behavior surfaces, the artifact-only skip no longer
applies. The implementer must either remove those out-of-scope changes or run
the active roadmap baseline:

```sh
cabal build all
cabal test watcher-core-test
```

If staging occurs, also run:

```sh
git diff --cached --check
```
