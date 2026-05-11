### Goal

Move the single `src/CodexWatcher/Core/State.hs` dependency on the combined
`CodexWatcher.Core.Ids` compatibility facade to the direct owner module
`CodexWatcher.Workflow.GitHub.Ids` for the GitHub-only identifiers
`CommitSha` and `PrNumber`.

The round preserves `CompletionEvidence`, `WatcherState`,
`SomeWatcherState`, deriving behavior, constructors, parser/renderer output,
command output, package descriptors, and public compatibility facade exposure.
It is import convergence only; it does not claim deprecation, migration,
facade removal, Cabal exposure removal, release approval, milestone
completion, or terminal completion.

### Approach

Keep the implementation to one source-file import edit in
`src/CodexWatcher/Core/State.hs`. Replace the broad
`CodexWatcher.Core.Ids` import with a narrow import from
`CodexWatcher.Workflow.GitHub.Ids` that brings only `CommitSha` and
`PrNumber` into scope.

Use the round-097 inventory as supporting evidence that this file is a
GitHub-only `Core.Ids` candidate, then refresh the relevant scans at current
HEAD before and after the edit. Confirm that `CodexWatcher.Workflow.GitHub.Ids`
is already exposed by the existing package graph, and confirm no package
descriptor change appears in the round diff.

### Steps

1. Re-read the active coordination inputs:
   `orchestrator/state.json`,
   `orchestrator/rounds/round-100/selection.md`,
   `orchestrator/project-contract.md`, and
   `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`.
2. Reconfirm the selected source-file id usage before editing:
   ```sh
   rg -n "CodexWatcher\\.Core\\.Ids|CommitSha|PrNumber|RequestId|ThreadId|TurnId|nextRequestId|RepoName|IssueNumber|BranchName|ReviewThreadId" \
     src/CodexWatcher/Core/State.hs
   ```
   The expected result is that `src/CodexWatcher/Core/State.hs` imports
   `CodexWatcher.Core.Ids` and uses only `CommitSha` and `PrNumber` from that
   facade.
3. Confirm the direct owner module is already exposed and no descriptor edit is
   needed:
   ```sh
   rg -n "exposed-modules:|CodexWatcher\\.Core\\.Ids|CodexWatcher\\.Core\\.State|CodexWatcher\\.Workflow\\.GitHub\\.Ids" \
     moifold.cabal agent-workflow-github/agent-workflow-github.cabal \
     agent-workflow-core/agent-workflow-core.cabal \
     agent-workflow-codex/agent-workflow-codex.cabal cabal.project
   ```
4. Edit only `src/CodexWatcher/Core/State.hs`: remove the import of
   `CodexWatcher.Core.Ids` and add:
   ```haskell
   import CodexWatcher.Workflow.GitHub.Ids (CommitSha, PrNumber)
   ```
   Do not edit constructors, exported names, deriving clauses, command
   rendering, parsers, fixtures, tests, package descriptors, public facade
   modules, roadmap files, controller state, or prior artifacts.
5. Re-run the focused source scan:
   ```sh
   rg -n "CodexWatcher\\.Core\\.Ids|CodexWatcher\\.Workflow\\.GitHub\\.Ids|CommitSha|PrNumber|RequestId|ThreadId|TurnId|nextRequestId|RepoName|IssueNumber|BranchName|ReviewThreadId" \
     src/CodexWatcher/Core/State.hs
   ```
   The expected result is one direct-owner import and no remaining
   `CodexWatcher.Core.Ids` import in the selected file.
6. Refresh the facade import scan over the active cleanup surfaces and record
   that `src/CodexWatcher/Core/State.hs` is no longer a `Core.Ids` importer
   while other users remain intentionally untouched:
   ```sh
   rg -n "^import[[:space:]]+(qualified[[:space:]]+)?CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.EventLog|Workflow\\.Permission)([[:space:]]|$|\\()" \
     src app test agent-workflow-core agent-workflow-codex agent-workflow-github
   ```
7. Check the package-descriptor diff is empty:
   ```sh
   git diff -- moifold.cabal agent-workflow-core/agent-workflow-core.cabal \
     agent-workflow-codex/agent-workflow-codex.cabal \
     agent-workflow-github/agent-workflow-github.cabal cabal.project
   ```
8. Check the round diff is limited to the selected source import and this
   round artifact:
   ```sh
   git diff --stat
   git diff -- src/CodexWatcher/Core/State.hs orchestrator/rounds/round-100/plan.md
   ```

### Verification

Run the focused and baseline gates from the active verification bundle:

```sh
cabal test watcher-core-test
cabal build all
git diff --check
git diff --cached --check
```

Also verify the package descriptor diff remains empty:

```sh
git diff -- moifold.cabal agent-workflow-core/agent-workflow-core.cabal \
  agent-workflow-codex/agent-workflow-codex.cabal \
  agent-workflow-github/agent-workflow-github.cabal cabal.project
```

The implementation report should call out:

- `src/CodexWatcher/Core/State.hs` now imports `CommitSha` and `PrNumber`
  from `CodexWatcher.Workflow.GitHub.Ids`.
- `CodexWatcher.Core.Ids` remains exposed and available.
- No package descriptors changed.
- Remaining facade users are expected and out of scope for this round.
- No deprecation, removal, migration, release, milestone completion, or
  terminal completion claim is made.

### Worker Fan-Out

No worker fan-out is justified. The selected extraction has one implementation
edit in one source file, a serial controller state with `max_parallel_rounds:
1`, and verification that must be interpreted against one small diff. Do not
write `orchestrator/rounds/round-100/worker-plan.json`.
