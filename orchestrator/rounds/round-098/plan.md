### Goal

Move the GitHub-only id usage in `test/BoundaryPolicySpec.hs` from the
combined compatibility facade `CodexWatcher.Core.Ids` to the direct owner
module `CodexWatcher.Workflow.GitHub.Ids`.

This round reduces one internal test dependency on the `Core.Ids`
compatibility facade without changing assertions, command-rendering behavior,
constructors, parsers, renderers, package descriptors, or public facade
exposure.

### Approach

Make the smallest source change in the selected test module:

- Replace `import CodexWatcher.Core.Ids` with
  `import CodexWatcher.Workflow.GitHub.Ids` in
  `test/BoundaryPolicySpec.hs`.
- Preserve every assertion, PASS/FAIL label, expected command argument, helper,
  and test aggregation path exactly as-is.
- Do not edit `moifold.cabal`, standalone package descriptors, public exposed
  modules, production source, fixtures, docs, roadmap files, or controller
  state.
- Treat this as import convergence only. It is not deprecation, removal,
  Cabal exposure cleanup, or approval to remove `CodexWatcher.Core.Ids`.

`agent-workflow-github` already exposes
`CodexWatcher.Workflow.GitHub.Ids`, and the `watcher-core-test` suite already
depends on `agent-workflow-github`, so no test-suite metadata change is
expected. If the build proves otherwise, limit any metadata change to the
minimal test-suite reachability fix and record why it was needed.

No worker fan-out is used. The implementation has one owned code file and one
straight-line verification path, so parallel workers would add coordination
without reducing risk.

### Steps

1. Open `test/BoundaryPolicySpec.hs` and replace the single
   `CodexWatcher.Core.Ids` import with
   `CodexWatcher.Workflow.GitHub.Ids`.
2. Confirm the only ids referenced in `test/BoundaryPolicySpec.hs` are GitHub
   id constructors or types: `BranchName`, `CommitSha`, `IssueNumber`,
   `PrNumber`, `RepoName`, and `ReviewThreadId`. The expected current used set
   is `BranchName`, `IssueNumber`, `PrNumber`, `RepoName`, and
   `ReviewThreadId`.
3. Confirm no agent id exports from `CodexWatcher.Core.Ids` are referenced in
   the file: `RequestId`, `ThreadId`, `TurnId`, or `nextRequestId`.
4. Leave all boundary-policy assertions and command parity checks unchanged,
   especially the `workflowGithubCommandFacadeMatchesRuntimeRender` checks
   that construct `RepoName`, `IssueNumber`, `PrNumber`, `BranchName`, and
   `ReviewThreadId`.
5. Do not edit public compatibility facade exposure. In particular, leave
   `CodexWatcher.Core.Ids` exposed from `moifold.cabal`.
6. Inspect the final diff and ensure the intended implementation diff is only
   the import replacement in `test/BoundaryPolicySpec.hs`, unless a build
   failure proved a minimal test-suite metadata fix was required.

### Verification

Run the focused import and token scans from the repository root:

```sh
rg -n '^import[[:space:]]+(qualified[[:space:]]+)?CodexWatcher\.Core\.Ids([[:space:]]|$|\()' test/BoundaryPolicySpec.hs
```

Expected result: no matches. This proves `BoundaryPolicySpec` no longer
imports the combined `Core.Ids` facade.

```sh
rg -n '^import[[:space:]]+CodexWatcher\.Workflow\.GitHub\.Ids([[:space:]]|$|\()' test/BoundaryPolicySpec.hs
```

Expected result: one direct owner import in `test/BoundaryPolicySpec.hs`.

```sh
rg -n '\b(BranchName|CommitSha|IssueNumber|PrNumber|RepoName|ReviewThreadId|RequestId|ThreadId|TurnId|nextRequestId)\b' test/BoundaryPolicySpec.hs
```

Expected result: matches are limited to GitHub id tokens. The acceptable
tokens are `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, `RepoName`,
and `ReviewThreadId`; the expected current used set is `BranchName`,
`IssueNumber`, `PrNumber`, `RepoName`, and `ReviewThreadId`.

```sh
rg -n '\b(RequestId|ThreadId|TurnId|nextRequestId)\b' test/BoundaryPolicySpec.hs
```

Expected result: no matches. This proves the file does not need the agent-id
half of `CodexWatcher.Core.Ids`.

Run behavior and baseline checks:

```sh
cabal test watcher-core-test
cabal build all
git diff --check
git diff --stat
git diff -- test/BoundaryPolicySpec.hs moifold.cabal
```

Expected result: `watcher-core-test` and `cabal build all` pass, diff hygiene
passes, `test/BoundaryPolicySpec.hs` shows only the import replacement, and
`moifold.cabal` has no diff. If staging occurs later in the orchestrator flow,
also run:

```sh
git diff --cached --check
```
