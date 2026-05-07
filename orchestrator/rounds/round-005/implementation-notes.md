### Changes Made
- `src/CodexWatcher/Workflow/DocsMigration.hs`: added a DocsMigration-owned `IndexedWorkflowSpec DocsMigrationSpec` adapter with internal phase marker types and wrappers for indexed state, event, observation, observed tick, effect, effect plan, and replay result. The adapter delegates to the existing DocsMigration `WorkflowSpec` implementation for initial/apply/observe/replay/permission/terminal/label behavior, and preserves the existing planned-transition post-commit partitioning.
- `test/Main.hs`: added focused indexed DocsMigration parity coverage for draft production, validation success, blocked output, permission checks, fixture codec replay, dry-run output, daemon execute output, committed-event audit labels, and action/effect ordering.
- `orchestrator/rounds/round-005/implementation-notes.md`: recorded the implementation summary and verification evidence for round-005.

### Tests
- `test/Main.hs`: `workflowDocsMigrationIndexedSpecMatchesCompatibilityForDraft` verifies indexed observe/plan/replay parity for the agent-complete draft path, including event, next state, no pre-commit effects, post-commit effects `[WriteDocsMigrationDraft, RunDocsMigrationValidation]`, effect labels, and replay effect history.
- `test/Main.hs`: `workflowDocsMigrationIndexedSpecMatchesCompatibilityForValidationAndBlocked` verifies indexed validation success and blocked nonterminal paths preserve `StopDocsMigrationDaemon` as the post-commit effect and keep `validated`/`blocked` labels and terminal behavior aligned with the compatibility facade.
- `test/Main.hs`: `workflowDocsMigrationIndexedSpecPreservesPermissionsAndFixtureCodec` verifies indexed validation/effect-allowed decisions against `WorkflowSpec` and `WorkflowPermission.validateWorkflowEffectPlanCore` for allowed, partial, wrong-target, and disallowed-state plans, and rechecks the DocsMigration event codec fixture contract.
- `test/Main.hs`: `workflowDocsMigrationIndexedDryRunAndDaemonParity` verifies dry-run and execute helpers still expose the same event, state, compiled actions, action reports, committed events, audit committed-event label, and action order while the indexed plan exposes the same post-commit effects.

### Notes
Verification run from the round-005 worktree:

- `cabal build all`: passed.
- `cabal test watcher-core-test`: passed, including the new focused indexed DocsMigration parity assertions.
- `git diff --check`: passed.
- `git diff --cached --check`: passed; no staged changes were present.

The DocsMigration event codec, fixture event order, schema labels/fields, dry-run helpers, daemon result record shape, and existing compatibility facade remain delegated to the pre-existing implementation. No roadmap, review, merge, or committed git state was edited by this implementation pass.
