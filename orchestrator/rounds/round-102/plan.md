### Goal
Move the `test/WorkflowDocsMigrationSpec.hs` agent id import from the combined `CodexWatcher.Core.Ids` compatibility facade to the direct owner module `CodexWatcher.Workflow.Agent.Ids (ThreadId, TurnId)`, while preserving the docs-migration workflow behavior tests and keeping `watcher-core-test` reachability intact.

Roadmap lineage: `2026-05-11-00-highest-value-cleanup` / `rev-001`, milestone `milestone-003-import-convergence-package-boundaries`, direction `direction-011-core-ids-import-convergence`, item `round-102-workflow-docs-migration-agent-ids-import-convergence`.

### Approach
Keep this round to one test import convergence only. `test/WorkflowDocsMigrationSpec.hs` currently imports `CodexWatcher.Core.Ids`; its selected visible id uses are `ThreadId` and `TurnId`, and the direct owner module is exposed by `agent-workflow-codex`. The `watcher-core-test` suite already lists `WorkflowDocsMigrationSpec` and depends on both `moifold` and `agent-workflow-codex`, so no package descriptor change is planned.

The implementer should not change docs-migration assertions, replay/application behavior, fixtures, event schemas, parsers, renderers, runtime compatibility files, public facade exposure, Cabal exposed modules, or roadmap/controller artifacts. `CodexWatcher.Core.Ids` remains available; this is not a deprecation, removal, release, milestone-completion, or terminal-completion round.

Worker fan-out is not justified. The selected work is a single import in a single test module plus verification, with no non-overlapping ownership boundary that would reduce risk or integration cost.

### Steps
1. Confirm the clean starting point for this slice without modifying state: inspect `git status --short` and note unrelated controller/round artifacts separately from implementation files.
2. Run focused import/id scans before editing:
   - `rg -n "import CodexWatcher\\.Core\\.Ids|import CodexWatcher\\.Workflow\\.Agent\\.Ids" test/WorkflowDocsMigrationSpec.hs`
   - `rg -n "\\b(ThreadId|TurnId|RequestId|nextRequestId|unThreadId|unTurnId)\\b" test/WorkflowDocsMigrationSpec.hs`
3. Confirm test-suite direct-owner reachability from descriptors, without changing them:
   - `rg -n "test-suite watcher-core-test|WorkflowDocsMigrationSpec|agent-workflow-codex" moifold.cabal cabal.project agent-workflow-codex/agent-workflow-codex.cabal`
   - confirm `agent-workflow-codex` exposes `CodexWatcher.Workflow.Agent.Ids`, and `watcher-core-test` depends on `agent-workflow-codex`.
4. Run the baseline behavior gate before the import edit: `cabal test watcher-core-test`.
5. Edit only `test/WorkflowDocsMigrationSpec.hs`: replace the unqualified `CodexWatcher.Core.Ids` import with `CodexWatcher.Workflow.Agent.Ids (ThreadId, TurnId)`. Do not modify assertions, helper functions, fixtures, behavior tests, or other imports unless compilation proves the selected id list must include constructors.
6. Re-run the focused scans from steps 2 and 3. Confirm `test/WorkflowDocsMigrationSpec.hs` no longer imports `CodexWatcher.Core.Ids`, still only uses the selected agent ids from this import, and no descriptor diff was introduced.
7. Check the implementation diff:
   - `git diff -- test/WorkflowDocsMigrationSpec.hs moifold.cabal cabal.project agent-workflow-codex/agent-workflow-codex.cabal`
   - `git diff --stat`
   The expected implementation diff is limited to `test/WorkflowDocsMigrationSpec.hs`; package descriptors should remain unchanged unless compile proof shows a minimal test-suite dependency is required.
8. Run verification sequentially in this checkout:
   - `cabal test watcher-core-test`
   - `cabal build all`
   - `git diff --check`
   - `git diff --cached --check`

### Verification
Required evidence for review:
- Focused before/after import scans for `test/WorkflowDocsMigrationSpec.hs`.
- Descriptor reachability evidence showing `watcher-core-test` still owns `WorkflowDocsMigrationSpec` and can reach `CodexWatcher.Workflow.Agent.Ids` through the current package graph.
- Baseline `cabal test watcher-core-test` before the edit.
- Post-edit `cabal test watcher-core-test`.
- Post-edit `cabal build all`.
- `git diff --check`.
- `git diff --cached --check`.
- A diff summary confirming no package descriptor, public facade exposure, compatibility file, event schema, fixture, docs-migration behavior, roadmap, or controller-state change was made for this slice.
