### Goal
Migrate only `src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs` away from the `CodexWatcher.Core.Ids` compatibility facade by importing the existing ID types from their direct owner modules, while preserving issue-plan, implementation-turn, and final-review classification behavior exactly.

### Approach
Keep this as a single-file import convergence change. Replace the current `CodexWatcher.Core.Ids (CommitSha (..), PrNumber, ThreadId)` import with `CodexWatcher.Workflow.GitHub.Ids (CommitSha (..), PrNumber)` and `CodexWatcher.Workflow.Agent.Ids (ThreadId)`.

Do not change function bodies, data types, pattern matches, structured-turn outcome handling, final-review commit validation, reviewer prompt-version validation, missing-output handling, malformed JSON handling, or any existing error text. Do not edit package descriptors, compatibility facades, tests, docs, roadmap files, or controller state. This round has no worker fan-out because the ownership boundary is one production file and the implementation is sequential.

### Steps
1. Open `src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs` and confirm its only `CodexWatcher.Core.Ids` dependency is the import of `CommitSha (..)`, `PrNumber`, and `ThreadId`.
2. Replace that import with:
   - `import CodexWatcher.Workflow.Agent.Ids (ThreadId)`
   - `import CodexWatcher.Workflow.GitHub.Ids (CommitSha (..), PrNumber)`
3. Leave every declaration and function body in `TurnClassifier.hs` unchanged, especially `classifyIssuePlanTurn`, `classifyIssueImplementationTurn`, `classifyIssueFinalReviewTurn`, `classifyStructuredIssueImplementation`, `completedImplementationObservation`, `validateIssueFinalReviewReport`, `validateCompleteIssueFinalReviewReport`, and `commonIssueFinalReviewIncomplete`.
4. Do not create `orchestrator/rounds/round-166/worker-plan.json`.
5. Review the diff and confirm the only production code change is the import split in `src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`.

### Verification
Run the baseline checks from the active roadmap:

```sh
cabal build all
cabal test watcher-core-test
git diff --check
```

If any files are staged during the round, also run:

```sh
git diff --cached --check
```

Run focused import scans proving the selected file no longer imports the facade and now imports the direct owner modules:

```sh
rg -n "CodexWatcher\\.Core\\.Ids" src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs
rg -n "CodexWatcher\\.Workflow\\.Agent\\.Ids \\(ThreadId\\)" src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs
rg -n "CodexWatcher\\.Workflow\\.GitHub\\.Ids \\(CommitSha \\(\\.\\.\\), PrNumber\\)" src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs
```

The first scan must return no matches; the two direct-owner scans must each return the new import line.

Run a remaining `Core.Ids` user scan to record that other facade users still exist and are intentionally out of scope:

```sh
rg -n "CodexWatcher\\.Core\\.Ids" src app test
```

Run package exposure scans proving `CodexWatcher.Core.Ids` remains exposed and both owner modules remain exposed:

```sh
rg -n "CodexWatcher\\.Core\\.Ids" moifold.cabal
rg -n "CodexWatcher\\.Workflow\\.Agent\\.Ids" agent-workflow-codex/agent-workflow-codex.cabal
rg -n "CodexWatcher\\.Workflow\\.GitHub\\.Ids" agent-workflow-github/agent-workflow-github.cabal
```

The package exposure scans must show `CodexWatcher.Core.Ids` in `moifold.cabal`, `CodexWatcher.Workflow.Agent.Ids` in `agent-workflow-codex/agent-workflow-codex.cabal`, and `CodexWatcher.Workflow.GitHub.Ids` in `agent-workflow-github/agent-workflow-github.cabal`.
