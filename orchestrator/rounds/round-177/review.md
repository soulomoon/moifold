### Checks Run
- Command: `jq '.' orchestrator/state.json`
  Result: pass. State lineage matches roadmap `2026-05-11-00-highest-value-cleanup`, revision `rev-001`, milestone `milestone-003-import-convergence-package-boundaries`, direction `direction-011-core-ids-import-convergence`, extracted item `round-177-event-log-replay-core-ids-split-import-migration`, stage `review`, `worker_mode: none`, and `merge_ready: false`.

- Command: `sed -n '1,240p' orchestrator/project-contract.md`
  Result: pass. The project contract preserves event schemas, golden replay fixtures, package boundaries, and public compatibility facades unless an explicit roadmap round authorizes migration/removal.

- Command: `git diff -- src/CodexWatcher/EventLog/Replay.hs`
  Result: pass. The selected file only removes `import CodexWatcher.Core.Ids (IssueNumber (..), ThreadId (..), TurnId (..))` and adds direct owner imports from `CodexWatcher.Workflow.Agent.Ids (ThreadId (..), TurnId (..))` and `CodexWatcher.Workflow.GitHub.Ids (IssueNumber (..))`.

- Command: `git diff --name-status`
  Result: pass for scoped review. Tracked dirty files are `orchestrator/state.json` and `src/CodexWatcher/EventLog/Replay.hs`. The `orchestrator/state.json` diff is controller active-round metadata. The implementation slice changes only `src/CodexWatcher/EventLog/Replay.hs` plus round artifacts; no tests, Cabal files, docs, roadmap files, runtime compatibility files, package descriptors, or public facade modules changed.

- Command: `git ls-files --others --exclude-standard orchestrator/rounds/round-177`
  Result: pass. Existing untracked round artifacts before this review were `selection.md`, `plan.md`, and `implementation-notes.md`; this review adds only `review.md` and `review-record.json`.

- Command: `cabal build all`
  Result: pass. Cabal built all targets with GHC 9.12.2, including `CodexWatcher.EventLog.Replay` and the `moifold` executable.

- Command: `cabal test watcher-core-test --test-options='--match "workflow event-log"'`
  Result: pass. The focused replay/event-log compatibility command was accepted and completed with `Test suite watcher-core-test: PASS`; the output included golden replay, runtime compatibility fixture, and event-log/replay checks.

- Command: `cabal test watcher-core-test`
  Result: pass. Full watcher baseline completed with `Test suite watcher-core-test: PASS`; `1 of 1 test suites (1 of 1 test cases) passed`.

- Command: `git diff --check`
  Result: pass. No whitespace or conflict-marker errors reported.

- Command: `if git diff --cached --quiet; then printf 'SKIPPED: no staged changes\n'; else git diff --cached --check; fi`
  Result: pass/skipped. Output: `SKIPPED: no staged changes`.

- Command: `rg -n "CodexWatcher\\.Core\\.Ids" src/CodexWatcher/EventLog/Replay.hs`
  Result: pass. No matches; `rg` exit code 1 is expected because the selected file no longer imports the compatibility facade.

- Command: `rg -n "CodexWatcher\\.Workflow\\.GitHub\\.Ids|CodexWatcher\\.Workflow\\.Agent\\.Ids" src/CodexWatcher/EventLog/Replay.hs`
  Result: pass. Matches show `CodexWatcher.Workflow.Agent.Ids (ThreadId (..), TurnId (..))` and `CodexWatcher.Workflow.GitHub.Ids (IssueNumber (..))`.

- Command: `rg -n "CodexWatcher\\.Core\\.Ids" $(git ls-files 'src/**' 'app/**' 'test/**' 'docs/**' 'agent-workflow-*/**' '*.cabal' 'cabal.project*')`
  Result: pass for scoped review. Remaining facade users exist outside the selected file, including docs, `moifold.cabal`, `src/CodexWatcher/Core/Ids.hs`, CLI modules, domain loop modules, `src/CodexWatcher/EventLog/Types.hs`, runtime compatibility, healthcheck, golden replay, and tests. This confirms the round is not removal, deprecation, milestone completion, or terminal completion.

### Plan Compliance
- Edit `src/CodexWatcher/EventLog/Replay.hs` import declarations only: met. The selected-file diff is import-only.

- Remove the selected `CodexWatcher.Core.Ids` import: met. The old import for `IssueNumber (..)`, `ThreadId (..)`, and `TurnId (..)` is gone.

- Import direct owners: met. `IssueNumber (..)` now comes from `CodexWatcher.Workflow.GitHub.Ids`; `ThreadId (..)` and `TurnId (..)` now come from `CodexWatcher.Workflow.Agent.Ids`.

- Preserve behavior and public surfaces: met. No function bodies, exports, constructors, replay initialization, event application, transition logic, replay failure text, event JSON shape, old-log parsing behavior, package descriptors, public facade exposure, runtime compatibility files, docs, roadmap files, or tests changed.

- Avoid deprecation/removal/completion claims: met. Selection, plan, and implementation notes keep the round framed as import convergence only, and the remaining-user scan confirms `CodexWatcher.Core.Ids` still has users outside this slice.

### Decision
**APPROVED**

### Evidence
The round is aligned to roadmap `2026-05-11-00-highest-value-cleanup` revision `rev-001` under `milestone-003-import-convergence-package-boundaries` and `direction-011-core-ids-import-convergence`. The active extracted item is `round-177-event-log-replay-core-ids-split-import-migration`.

The production diff for `src/CodexWatcher/EventLog/Replay.hs` is exactly the planned import split:

```diff
-import CodexWatcher.Core.Ids (IssueNumber (..), ThreadId (..), TurnId (..))
+import CodexWatcher.Workflow.Agent.Ids (ThreadId (..), TurnId (..))
+import CodexWatcher.Workflow.GitHub.Ids (IssueNumber (..))
```

The selected file has no remaining `CodexWatcher.Core.Ids` import. Build, full test, focused replay/event-log compatibility command, whitespace checks, focused selected-file scans, and broad remaining-user scan all passed. Approval does not imply `CodexWatcher.Core.Ids` deprecation, removal, Cabal exposure cleanup, runtime compatibility cleanup, milestone completion, or terminal roadmap completion.
