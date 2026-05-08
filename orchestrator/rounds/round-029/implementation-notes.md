### Changes Made
- `src/CodexWatcher/Workflow/DocsMigration.hs`: added `docsMigrationDraftProducedDslTransition` and routed only the `DocsMigrationTurnActive` plus `DocsMigrationDraftProduced` apply path through the pure `WorkflowDSL.advance` helper. The transition still produces `DocsMigrationDraftReady` and the existing `WriteDocsMigrationDraft` then `RunDocsMigrationValidation` post-commit effects.
- `src/CodexWatcher/Workflow/Moifold/IssuePlanning/Indexed.hs`: added `projectIssuePlanningTurnCompletedDslTransition` and routed only `projectIssuePlanningTurnCompletedObservation` through the pure DSL helper. The projection preserves the existing `IssuePlanning/PlanMode` to `IssuePlanning/Complete` labels and lowers back to `IssuePlanningIndexedProjection`.
- `test/Main.hs`: added focused parity coverage for the two DSL-authored ports, including event, next state, planned effect partitioning, replay result, permission checks, phase-action validation, action ordering, and dry-run reports.

### Tests
- `test/Main.hs`: `workflowDslDocsMigrationDraftProducedPortParity` verifies the DocsMigration draft-produced DSL port preserves the selected transition's event, state, effects, replay, permission rejection for wrong state, compiled action order, and dry-run non-execution reports.
- `test/Main.hs`: `workflowDslIssuePlanningTurnCompletedPortParity` verifies the issue-planning turn-completed DSL port matches indexed and compatibility planning, replay, permission, phase-action validation, compiled action ordering, and dry-run reports.

### Notes
- No roadmap files, selection, plan, review artifacts, merge notes, parent checkout state, or `orchestrator/state.json` were edited.
- No event schemas, golden fixtures, compatibility facades, daemon transaction code, or interpreter behavior were changed.
- Deviations from plan: none. The two selected transitions had not drifted.
- Validation commands run:
  - `cabal test watcher-core-test` failed initially on missing `BlockArguments`-style parentheses around new DSL `do` blocks.
  - `cabal test watcher-core-test` failed next on test-only `Eq` comparisons for `PlannedTransition MoifoldSpec` and `SomeWatcherState`; assertions were narrowed to field and state-shape comparisons.
  - `cabal test watcher-core-test` passed after those fixes.
  - `cabal build all` passed.
  - `git diff --check` passed.
  - `git diff --cached --check` passed with no staged changes.
  - `git diff --no-index --check /dev/null orchestrator/rounds/round-029/implementation-notes.md` produced no whitespace errors for the untracked notes file.
