### Source Round
- Round id: `round-097`
- Merged commit: `04a675c` (`Refresh compatibility facade import inventory`)
- Evidence: `orchestrator/rounds/round-097/selection.md` selected
  `round-097-facade-import-scan-refresh` under
  `milestone-003-import-convergence-package-boundaries` /
  `direction-009-facade-import-scan-refresh`;
  `orchestrator/rounds/round-097/plan.md` limited the round to artifact-only
  import and exposure inventory for
  `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`,
  `CodexWatcher.Workflow.EventLog`, and
  `CodexWatcher.Workflow.Permission`;
  `orchestrator/rounds/round-097/facade-import-scan-refresh.md` records the
  accepted current selected-facade import counts, Cabal exposure, standalone
  package-candidate absence, direct-owner package availability, per-facade
  classifications, corrected `Core.Ids` exact-token totals, and later
  convergence blockers; `orchestrator/rounds/round-097/review.md` and
  `orchestrator/rounds/round-097/review-record.json` approved the corrected
  artifact after rechecking the selected-facade counts, `Core.Ids`
  classification, `test/BoundaryPolicySpec.hs` GitHub-only result,
  `moifold.cabal` exposure, standalone package-candidate scan, no-overclaim
  boundaries, and diff hygiene; `orchestrator/rounds/round-097/merge.md`
  recorded the approved squash scope and repeated that the merge does not
  approve import migration, Cabal exposure changes, public deprecation, facade
  removal, runtime compatibility cleanup, release approval, or milestone
  completion.

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-001`
- Proposed revision: `rev-001`
- Files changed: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`; `orchestrator/roadmap-updates/round-097-roadmap-update.md`

### Rationale
The merged round provides the current accepted inventory for
`direction-009-facade-import-scan-refresh` under
`milestone-003-import-convergence-package-boundaries`. It records
selected-facade import counts of `CodexWatcher.AppServerClient`: 19 (`src`:
12, `test`: 7), `CodexWatcher.Core.Ids`: 44 (`src`: 31, `app`: 1, `test`:
12), `CodexWatcher.Workflow.EventLog`: 10 (`src`: 2, `test`: 8), and
`CodexWatcher.Workflow.Permission`: 7 (`test`: 7). It also records that
`moifold.cabal` still exposes all four selected compatibility facades and that
there are no exact selected-facade imports under `agent-workflow-core`,
`agent-workflow-codex`, or `agent-workflow-github`.

The corrected `Core.Ids` evidence is material for later sequencing: the
accepted exact-token scan classifies 3 GitHub-only candidates, 2 agent-only
candidates, and 39 combined users, and correctly classifies
`test/BoundaryPolicySpec.hs` as GitHub-only rather than combined. Later
`Core.Ids` convergence should start with single-domain users before combined
users.

The accepted inventory also preserves the next-slice blockers. Later
`AppServerClient` convergence still needs endpoint parsing, app-server
protocol, session handling, command rendering, fallback, timeout, and
failure-formatting checks. Later `Core.Ids` convergence still needs
parser/renderer, serialization, prompt/output, runtime-config, and fixture
stability evidence for combined users. Later `Workflow.EventLog` convergence
still needs generic event-log/audit uses separated from concrete moifold
wrapper uses, with golden replay, old-log parsing, event JSON `type`,
transition/replay parity, and wrapper behavior evidence. Later
`Workflow.Permission` convergence still needs reusable permission-core uses
separated from concrete moifold policy helpers, with permission soundness,
phase-validation, state/effect validation, public API, and downstream evidence.

Milestone 003 remains in progress, not complete. Round-097 is accepted
artifact-only evidence for the current import/exposure inventory; it does not
replace safe internal facade imports, approve import migration, approve Cabal
exposure changes, approve public deprecation, approve facade removal, approve
runtime compatibility cleanup, approve release/publication, or complete the
roadmap family.

No new roadmap revision is proposed because the merged evidence does not change
roadmap sequencing, dependencies, scope boundaries, verification gates, or
active roadmap metadata. It only records accepted progress against the existing
in-progress milestone, marks direction-009 complete as evidence, and leaves
later convergence directions pending in the active revision.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: not applicable; remains
  `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`
