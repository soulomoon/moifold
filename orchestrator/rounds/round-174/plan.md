### Goal
Migrate the selected `IssueImplement.Indexed` production module off the
`CodexWatcher.Core.Ids` compatibility facade for this round's five ID types,
while preserving the indexed issue-implementation API, behavior, schemas, and
all compatibility surfaces.

### Approach
Make a single import-only edit in
`src/CodexWatcher/Workflow/Moifold/IssueImplement/Indexed.hs`: replace the
existing `CodexWatcher.Core.Ids` import for `BranchName`, `CommitSha`,
`PrNumber`, `ThreadId`, and `TurnId` with direct owner imports from
`CodexWatcher.Workflow.GitHub.Ids` and `CodexWatcher.Workflow.Agent.Ids`.

Do not touch exports, indexed state/effect/event/observation types,
projections, transition helpers, constructors, deriving clauses, function
bodies, tests, Cabal files, docs, fixtures, runtime compatibility files, or the
public `CodexWatcher.Core.Ids` facade. This is one migration slice for
`direction-011-core-ids-import-convergence`, not completion or removal of the
facade.

Worker fan-out is not used. The round has one implementation file, one import
change, no independent ownership boundary, and `max_parallel_rounds: 1` in the
active controller state.

### Steps
1. Open `src/CodexWatcher/Workflow/Moifold/IssueImplement/Indexed.hs` and
   locate the current import:
   `import CodexWatcher.Core.Ids (BranchName, CommitSha, PrNumber, ThreadId, TurnId)`.
2. Replace that import with:
   `import CodexWatcher.Workflow.GitHub.Ids (BranchName, CommitSha, PrNumber)`
   and
   `import CodexWatcher.Workflow.Agent.Ids (ThreadId, TurnId)`.
3. Leave the rest of the file byte-for-byte unchanged except for normal
   formatter-stable import ordering if the repository formatter requires it.
4. Confirm no other files changed as part of implementation.
5. Record in implementation notes that remaining `CodexWatcher.Core.Ids` users
   are intentionally out of scope and that public facade exposure remains
   intact.

### Verification
Run these checks after the implementation edit:

1. Show the exact implementation diff:
   `git diff -- src/CodexWatcher/Workflow/Moifold/IssueImplement/Indexed.hs`
2. Prove the selected file no longer imports the compatibility facade:
   `rg -n "CodexWatcher\\.Core\\.Ids" src/CodexWatcher/Workflow/Moifold/IssueImplement/Indexed.hs`
   and expect no matches.
3. Run the baseline build:
   `cabal build all`
4. Run the focused core test suite:
   `cabal test watcher-core-test`
5. Check unstaged/staged whitespace and conflict markers:
   `git diff --check`
6. If any files are staged, also run:
   `git diff --cached --check`
7. Scan remaining facade users to record this as one migration slice, not
   completion/removal:
   `rg -n "CodexWatcher\\.Core\\.Ids" src app test codex-watcher-hs.cabal`
   and summarize the remaining users without editing them.
