### Checks Run
- Command: `cabal test watcher-core-test --test-options='--pattern workflow'`
  Result: pass. The focused workflow regression target passed, including the bridge source scans, indexed DocsMigration law/fixture checks, and PR-review indexed compatibility coverage.
- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`.
- Command: `cabal test watcher-core-test`
  Result: pass. The full `watcher-core-test` suite passed.
- Command: `git diff --check`
  Result: pass. No whitespace errors reported.
- Command: `git diff --cached --check`
  Result: pass. No staged diff errors reported; there are no staged changes.
- Command: `rg -n "Workflow\\.Moifold|CodexWatcher\\.Moifold|CodexWatcher\\.Watcher|WatcherEvent|SomeWatcherState|Data\\.Aeson|System\\.Directory|System\\.Process|CodexWatcher\\.AppServer|CodexWatcher\\.GitHub" agent-workflow-core/src/CodexWatcher/Workflow/Indexed/Spec.hs`
  Result: pass. No forbidden moifold, adapter, runtime, event-codec, filesystem, or process imports/tokens found in the core indexed spec bridge file.
- Command: `sed -n '28,48p' moifold.cabal`
  Result: pass. `agent-workflow-core` still exposes `CodexWatcher.Workflow.Indexed.Spec` and `CodexWatcher.Workflow.Spec`; no compatibility module removal was introduced by this round.
- Command: `git diff --name-only -- 'golden/**' 'test/golden/**' 'fixtures/**' '**/*.golden' '**/*.jsonl' | sort`
  Result: pass. No golden, fixture, or event-log files changed.
- Command: `git diff --name-only -- 'orchestrator/roadmaps/**' 'orchestrator/rounds/round-026/selection.md' 'orchestrator/rounds/round-026/plan.md' 'orchestrator/rounds/round-026/implementation-notes.md' | sort`
  Result: pass. No active roadmap, selection, plan, or implementation-notes files changed during review.
- Command: `git diff --name-only -- 'src/**/Daemon*' 'src/**/*Daemon*' 'src/**/Runtime*' 'src/**/*Runtime*' 'src/**/Codec*' 'src/**/*Codec*' | sort`
  Result: pass. No daemon, runtime, or codec files changed.

### Plan Compliance
- Step 1: met. The diff is limited to `agent-workflow-core/src/CodexWatcher/Workflow/Indexed/Spec.hs`, `src/CodexWatcher/Workflow/DocsMigration.hs`, `src/CodexWatcher/Workflow/Moifold/PrReview/Checking/Indexed.hs`, `test/Main.hs`, and controller state metadata.
- Step 2: met. `WorkflowSpecIndexedBridge` and delegate helpers were added in the generic indexed core spec surface.
- Step 3: met. The new bridge is exported from `CodexWatcher.Workflow.Indexed.Spec`; existing `WorkflowSpec`, `IndexedWorkflowSpec`, existential wrappers, and compatibility helper exports remain.
- Step 4: met. `DocsMigrationSpec` now delegates indexed hooks through `docsMigrationIndexedBridge`; event codecs, fixture contracts, daemon helpers, dry-run helpers, and public constructors are not changed.
- Step 5: met. The representative moifold PR-review checking indexed adapter now delegates through `prReviewCheckingIndexedBridge` while keeping its wrapper types.
- Step 6: met. `test/Main.hs` includes new bridge source scans and existing indexed DocsMigration and PR-review tests passed for labels, replay projection, terminal behavior, validation, permissions, and effect labels.
- Step 7: met. Source-scan coverage proves the bridge is in generic core, checks DocsMigration and PR-review checking migration usage, and keeps core package-boundary import scans active.
- Step 8: met. No event JSON type labels, golden fixtures, daemon/runtime behavior, active roadmap files, selection, plan, or implementation notes changed. `orchestrator/state.json` is modified only as controller round metadata for this review-stage worktree and was not edited by this reviewer.

### Decision
**APPROVED**

### Evidence
The integrated diff implements an additive compatibility bridge in `agent-workflow-core` and migrates exactly the planned DocsMigration and representative PR-review checking indexed adapters. The bridge delegates initial/apply/observe/plan/replay/validate/permission/terminal/label/effect projection hooks to the underlying `WorkflowSpec`, preserving wrapper label projection in the indexed adapters.

Contract checks passed: `agent-workflow-core/src/CodexWatcher/Workflow/Indexed/Spec.hs` imports only the generic unindexed spec plus `Data.Kind` and `Data.Text`; no moifold lifecycle policy, Codex app-server transport, GitHub adapter, Aeson codec, daemon/runtime interpreter, filesystem, process, `WatcherEvent`, or `SomeWatcherState` references were found. `moifold.cabal` still exposes the existing core spec modules.

Compatibility evidence passed in the test suite: indexed DocsMigration replay/terminal/permission/fixture/dry-run coverage, PR-review checking indexed compatibility cases, workflow law tests, golden event-log replay checks, action-ordering checks, dry-run no-interpreter checks, and package-boundary source scans. No golden, fixture, event-log, daemon, runtime, codec, roadmap, selection, plan, or implementation-notes files changed.
