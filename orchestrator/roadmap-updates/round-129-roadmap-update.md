### Source Round
- Round id: `round-129`
- Merged commit: `d52fdfc` (`Remove unused workflow agent EventLog imports`)
- Evidence: `orchestrator/rounds/round-129/selection.md`, `orchestrator/rounds/round-129/implementation-notes.md`, `orchestrator/rounds/round-129/review.md`, `orchestrator/rounds/round-129/review-record.json`, `orchestrator/rounds/round-129/merge.md`, and the merged squash commit `d52fdfc`.

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-001`
- Proposed revision: `rev-001`
- Files changed: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`, `orchestrator/roadmap-updates/round-129-roadmap-update.md`

### Rationale
Round 129 completed the `round-129-workflow-agent-support-eventlog-import-removal` slice under `milestone-003-import-convergence-package-boundaries` / `direction-012-eventlog-permission-bridge-split-readiness` by removing only the unused exact `CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog` imports from `test/WorkflowAgentSpec.hs` and `test/TestSupport/Workflow.hs`. Direct owner imports from `CodexWatcher.Workflow.EventLog.Commit.Core` and `CodexWatcher.Workflow.EventLog.File.Core` remained in place, and workflow test behavior was preserved.

The merged change is status-only for the active roadmap revision. It records a concrete internal facade-import removal after rounds 127 and 128 closed the current known production source exact EventLog facade import subset. Round evidence shows the selected files no longer used or imported the exact `WorkflowEventLog` facade alias, while the broad import scan kept remaining out-of-scope test imports visible. Verification passed with the focused `workflowAgentTests` REPL preflight, `cabal test watcher-core-test`, `cabal build all`, diff checks, and selected/broad import scans.

This update does not change future coordination enough to require a new roadmap revision. It does, however, update the coordination signal for direction 012: when accepted evidence is already sufficient, future selections should favor additional concrete, lawful removal or migration slices over broad gate-only rounds. Milestone 003 and direction 012 remain in progress. Remaining exact EventLog facade imports in other out-of-scope tests, docs/policy references, public facade/exposure, and Cabal exposure remain out of scope, and Workflow.Permission migration remains unapproved. This update does not approve public facade removal/deprecation, Cabal exposure removal, package descriptor cleanup, public API cleanup, remaining EventLog facade migration, Workflow.Permission migration, release approval, milestone completion, terminal completion, or public compatibility removal.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
