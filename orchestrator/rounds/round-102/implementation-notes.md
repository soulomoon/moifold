### Changes Made
- `test/WorkflowDocsMigrationSpec.hs`: replaced the `CodexWatcher.Core.Ids` compatibility facade import with the direct owner import `CodexWatcher.Workflow.Agent.Ids (ThreadId (..), TurnId (..))`. The constructor import was required by compile proof because the existing docs-migration fixtures construct `ThreadId "docs-thread"` and `TurnId "docs-turn"` at term level.

### Tests
- `test/WorkflowDocsMigrationSpec.hs`: existing docs-migration workflow assertions, fixtures, replay/application behavior, codec checks, permission checks, dry-run checks, adapter checks, and watcher-core reachability were preserved unchanged.

### Notes
Verification summary:
- Starting status: `git status --short` showed pre-existing `M orchestrator/state.json` and untracked `orchestrator/rounds/round-102/`; implementation changed only `test/WorkflowDocsMigrationSpec.hs` and this notes file.
- Pre-edit import scan: `rg -n "import CodexWatcher\\.Core\\.Ids|import CodexWatcher\\.Workflow\\.Agent\\.Ids" test/WorkflowDocsMigrationSpec.hs` found `66:import CodexWatcher.Core.Ids`.
- Pre-edit id scan: `rg -n "\\b(ThreadId|TurnId|RequestId|nextRequestId|unThreadId|unTurnId)\\b" test/WorkflowDocsMigrationSpec.hs` found only `ThreadId` and `TurnId` uses in this file.
- Descriptor reachability scan: `rg -n "test-suite watcher-core-test|WorkflowDocsMigrationSpec|agent-workflow-codex|CodexWatcher\\.Workflow\\.Agent\\.Ids" moifold.cabal cabal.project agent-workflow-codex/agent-workflow-codex.cabal` showed `cabal.project` includes `agent-workflow-codex`, `agent-workflow-codex.cabal` exposes `CodexWatcher.Workflow.Agent.Ids`, and `watcher-core-test` lists `WorkflowDocsMigrationSpec` and depends on `agent-workflow-codex`.
- Pre-edit `cabal test watcher-core-test`: PASS, 1 of 1 test suites passed.
- First post-edit `cabal test watcher-core-test` with `ThreadId, TurnId`: failed because constructors were needed for existing term-level fixture construction; import was adjusted to `ThreadId (..), TurnId (..)` without changing behavior.
- Post-edit import scan: found `66:import CodexWatcher.Workflow.Agent.Ids (ThreadId (..), TurnId (..))` and no `CodexWatcher.Core.Ids` import in `test/WorkflowDocsMigrationSpec.hs`.
- Post-edit id scan: still found only `ThreadId` and `TurnId` id uses in this file.
- Post-edit descriptor reachability scan: unchanged; no descriptor edits were made.
- `git diff -- test/WorkflowDocsMigrationSpec.hs moifold.cabal cabal.project agent-workflow-codex/agent-workflow-codex.cabal`: limited to the single import replacement in `test/WorkflowDocsMigrationSpec.hs`; no package descriptor diff.
- `git diff --stat`: reports pre-existing `orchestrator/state.json` plus the implementation import change; no roadmap, production code, public facade module, compatibility file, event schema, fixture, docs-migration behavior, or package descriptor changes were made by this slice.
- Post-edit `cabal test watcher-core-test`: PASS, 1 of 1 test suites passed.
- Post-edit `cabal build all`: PASS.
- `git diff --check`: PASS.
- `git diff --cached --check`: PASS; no files were staged.
