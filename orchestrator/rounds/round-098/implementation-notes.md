### Changes Made
- `test/BoundaryPolicySpec.hs`: replaced the single `CodexWatcher.Core.Ids` import with `CodexWatcher.Workflow.GitHub.Ids` so the GitHub-only boundary-policy test uses the direct owner module.
- `orchestrator/rounds/round-098/implementation-notes.md`: recorded scoped changes and exact verification for round 098.

### Tests
- `test/BoundaryPolicySpec.hs`: assertions and command parity checks were left unchanged; `watcher-core-test` still reaches and compiles the module through the direct GitHub ids import.
- `rg -n '^import[[:space:]]+(qualified[[:space:]]+)?CodexWatcher\.Core\.Ids([[:space:]]|$|\()' test/BoundaryPolicySpec.hs`: no matches, as expected.
- `rg -n '^import[[:space:]]+CodexWatcher\.Workflow\.GitHub\.Ids([[:space:]]|$|\()' test/BoundaryPolicySpec.hs`: one match at line 9.
- `rg -n '\b(BranchName|CommitSha|IssueNumber|PrNumber|RepoName|ReviewThreadId|RequestId|ThreadId|TurnId|nextRequestId)\b' test/BoundaryPolicySpec.hs`: matches only GitHub id tokens: `RepoName`, `IssueNumber`, `PrNumber`, `BranchName`, and `ReviewThreadId`.
- `rg -n '\b(RequestId|ThreadId|TurnId|nextRequestId)\b' test/BoundaryPolicySpec.hs`: no matches, as expected.
- `cabal test watcher-core-test`: passed; `1 of 1 test suites (1 of 1 test cases) passed`.
- `cabal build all`: passed; built the `moifold` executable after reusing prior library/test artifacts.
- `git diff --check`: passed with no output.
- `git diff --stat`: reports `orchestrator/state.json | 47 ++++++++++++++++++++++++++++++++++++++--------` and `test/BoundaryPolicySpec.hs | 2 +-`; the state diff was present before this implementation and was not edited in this round.
- `git diff -- test/BoundaryPolicySpec.hs moifold.cabal`: shows only the import replacement in `test/BoundaryPolicySpec.hs`; `moifold.cabal` has no diff.

### Notes
No production code, package descriptor, public facade exposure, roadmap file, selection, plan, review, merge artifact, or controller state was edited. No test-suite metadata fix was required because `watcher-core-test` already reaches `agent-workflow-github`.
