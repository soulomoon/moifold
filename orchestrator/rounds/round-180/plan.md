### Goal

Migrate only `src/CodexWatcher/Cli/Types.hs` from the
`CodexWatcher.Core.Ids` compatibility facade to direct owner imports, while
preserving all CLI command constructors, record fields, derived instances,
`CliDomain` behavior, parser/rendering behavior, option names/errors, dry-run
text, fanout behavior, and child args exactly.

Roadmap lineage: `2026-05-11-00-highest-value-cleanup`, active revision
`rev-002`, milestone
`milestone-003-core-ids-production-import-burndown`, direction
`direction-011f-core-ids-cli-production-imports`, extracted item
`round-180-cli-types-core-ids-split-import-migration`.

### Approach

Keep this as a one-file, import-only production Core.Ids burndown slice. Replace
the current `CodexWatcher.Core.Ids` import in
`src/CodexWatcher/Cli/Types.hs` with direct owner imports for the ids actually
used by the file:

- `CodexWatcher.Workflow.Agent.Ids (ThreadId, TurnId)`
- `CodexWatcher.Workflow.GitHub.Ids (CommitSha, IssueNumber, PrNumber, RepoName, ReviewThreadId)`

Do not import `BranchName` unless local inspection after implementation proves
`src/CodexWatcher/Cli/Types.hs` uses it at the current head. Do not edit
exports, data declarations, record fields, derives, helper functions, parser
modules, command modules, `src/CodexWatcher/Cli/Command/IssueFanout.hs`, tests,
fixtures, Cabal exposure, docs, runtime compatibility files, roadmap state, or
the public `src/CodexWatcher/Core/Ids.hs` facade. Shared compatibility and
package-boundary invariants remain governed by
`orchestrator/project-contract.md`; this round is import convergence only and
does not approve deprecation, removal, Cabal cleanup, docs cleanup, runtime
compatibility cleanup, milestone completion, release approval, or terminal
completion.

Worker fan-out is not justified: the selected scope is one source file with a
single import replacement and one integrated verification path.

### Steps

1. Open `src/CodexWatcher/Cli/Types.hs` and confirm the only
   `CodexWatcher.Core.Ids` users in that file are `CommitSha`, `IssueNumber`,
   `PrNumber`, `RepoName`, `ReviewThreadId`, `ThreadId`, and `TurnId`. If
   `BranchName` appears during implementation, include it in the GitHub owner
   import and record the exact field/use that requires it.
2. Replace the `CodexWatcher.Core.Ids` import with the two direct owner imports
   listed above, using the existing import style from nearby completed
   direct-owner migrations.
3. Make no other edits to `Types.hs`: do not reorder the export list, rename or
   move constructors, change record field names, change strictness, change
   deriving clauses, alter `CliDomain`, or touch `cliDomainName` /
   `cliDomainToDomain`.
4. Do not edit parser or command modules to compensate for the import change.
   The compiler should prove that downstream parser/rendering/dry-run/fanout
   behavior still sees the same exported types and fields.
5. Run a local diff review and verify the source diff is import-only in
   `src/CodexWatcher/Cli/Types.hs`.
6. If the compiler proves an additional package dependency is required for this
   file, stop and record the exact compiler evidence before considering any
   package descriptor edit. Do not add package dependencies speculatively.
7. Record implementation notes with the exact changed file, import-only scope,
   behavior-preservation statement, verification commands, focused CLI evidence
   discovered, and remaining `CodexWatcher.Core.Ids` users classified by
   production versus tests/fixtures/docs/Cabal/public facade.

### Verification

Baseline checks:

- `cabal build all`
- `cabal test watcher-core-test`
- `git diff --check`
- `git diff --cached --check` if anything is staged

Selected-file Core.Ids absence scan:

- `rg -n "CodexWatcher\\.Core\\.Ids" src/CodexWatcher/Cli/Types.hs`
  must return no matches.

Selected-file direct owner import scans:

- `rg -n "CodexWatcher\\.Workflow\\.Agent\\.Ids" src/CodexWatcher/Cli/Types.hs`
  must show the direct `ThreadId`/`TurnId` owner import.
- `rg -n "CodexWatcher\\.Workflow\\.GitHub\\.Ids" src/CodexWatcher/Cli/Types.hs`
  must show the direct `CommitSha`/`IssueNumber`/`PrNumber`/`RepoName`/
  `ReviewThreadId` owner import, plus `BranchName` only if the file actually
  uses it after inspection.

Focused CLI behavior evidence:

- Inspect existing tests for `CodexWatcher.Cli.Types` consumers, especially
  `test/CliSpec.hs`, `test/ObserveCommandSpec.hs`,
  `test/AutomaticLoopRunnerSpec.hs`, `test/AppServerProbeSpec.hs`,
  `test/RuntimeCompatibilityFixtureSpec.hs`, and workflow specs importing
  `CodexWatcher.Cli.Types`.
- Use `cabal test watcher-core-test` as the required behavior gate for parser
  results, record-field construction, option names/errors, rendering, dry-run
  text, fanout-adjacent type plumbing, and child-arg type plumbing.
- If an easy focused selector for the relevant CLI specs is discoverable, run
  it in addition to the full suite and record the exact command. If no reliable
  focused selector is discoverable, record that focused behavior evidence is the
  full `watcher-core-test` run plus the import-only diff and the named test
  files inspected.

Broad remaining-user scan:

- Run a broad scan over production, app, tests, docs, Cabal, and package
  candidates for remaining `CodexWatcher.Core.Ids` imports, for example:
  `rg -n "import CodexWatcher\\.Core\\.Ids" src app test docs *.cabal agent-workflow-* 2>/dev/null || true`
- In implementation notes, separate remaining production users from
  tests/fixtures, docs/Cabal/package candidates, and the public facade module
  `src/CodexWatcher/Core/Ids.hs`.
- Confirm any remaining production CLI user, especially
  `src/CodexWatcher/Cli/Command/IssueFanout.hs`, remains out of scope for this
  round and is not edited or counted as resolved.
- Do not treat a clean selected-file scan or reduced remaining-user count as
  public facade deprecation/removal, Cabal exposure cleanup, docs cleanup,
  runtime compatibility cleanup, milestone completion, release approval, or
  terminal completion.
