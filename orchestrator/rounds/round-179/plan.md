### Goal

Migrate only `src/CodexWatcher/Cli/Parser/Common.hs` from the
`CodexWatcher.Core.Ids` compatibility facade to direct owner imports for the id
types it uses, while preserving every exported parser helper, constructor use,
field accessor availability, parse result, option name, metavar/help text,
default, and parser error behavior.

Roadmap lineage: `2026-05-11-00-highest-value-cleanup`, active revision
`rev-002`, milestone
`milestone-003-core-ids-production-import-burndown`, direction
`direction-011f-core-ids-cli-production-imports`, extracted item
`round-179-cli-parser-common-core-ids-split-import-migration`.

### Approach

Keep this as a one-file, import-only production Core.Ids burndown slice. Replace
the current `CodexWatcher.Core.Ids` import in
`src/CodexWatcher/Cli/Parser/Common.hs` with direct owner imports:

- `CodexWatcher.Workflow.Agent.Ids (ThreadId (..), TurnId (..))`
- `CodexWatcher.Workflow.GitHub.Ids (IssueNumber (..), RepoName (..), ReviewThreadId (..))`

Do not edit parser definitions, exported helper names, command parsers, CLI
types, fanout code, command rendering, dry-run text, child args, manifests,
tests, fixtures, Cabal exposure, docs, runtime compatibility files, or the
public `CodexWatcher.Core.Ids` facade. Reference the repo-wide invariants in
`orchestrator/project-contract.md`; this round is import convergence only and
does not approve deprecation, removal, Cabal cleanup, docs cleanup, milestone
completion, release approval, or terminal completion.

Worker fan-out is not justified: the selected scope is one source file with a
single import replacement and one integrated verification path.

### Steps

1. Open `src/CodexWatcher/Cli/Parser/Common.hs` and confirm the only
   `CodexWatcher.Core.Ids` usages in that file are `IssueNumber`, `RepoName`,
   `ReviewThreadId`, `ThreadId`, and `TurnId` constructors/types used by the
   existing parser helpers.
2. Replace the `CodexWatcher.Core.Ids` import with the two direct owner imports
   listed above. Preserve import style used by nearby direct-owner migrations.
3. Make no other edits to `Common.hs`: do not reorder exports, change helper
   definitions, change parser combinators, change string literals, change
   defaults, or change error text.
4. Run a local diff review and verify the source diff is import-only in
   `src/CodexWatcher/Cli/Parser/Common.hs`.
5. If the compiler proves an additional package dependency is required for this
   file, stop and record the exact compiler evidence before considering any
   package descriptor edit. Do not add package dependencies speculatively.
6. Record implementation notes that explicitly state this round leaves
   `src/CodexWatcher/Cli/Types.hs`,
   `src/CodexWatcher/Cli/Command/IssueFanout.hs`, tests/fixtures,
   `src/CodexWatcher/Core/Ids.hs`, Cabal, docs, and runtime compatibility files
   untouched.

### Verification

Baseline checks:

- `cabal build all`
- `cabal test watcher-core-test`
- `git diff --check`
- `git diff --cached --check` if anything is staged

Selected-file import scans:

- `rg -n "CodexWatcher\\.Core\\.Ids" src/CodexWatcher/Cli/Parser/Common.hs`
  must return no matches.
- `rg -n "CodexWatcher\\.Workflow\\.Agent\\.Ids" src/CodexWatcher/Cli/Parser/Common.hs`
  must show the direct `ThreadId`/`TurnId` owner import.
- `rg -n "CodexWatcher\\.Workflow\\.GitHub\\.Ids" src/CodexWatcher/Cli/Parser/Common.hs`
  must show the direct `IssueNumber`/`RepoName`/`ReviewThreadId` owner import.

Focused CLI parser behavior evidence:

- Use existing `watcher-core-test` coverage that exercises `parseCliCommand`
  through the parser helpers in `Common.hs`, especially repo parsing, thread id
  parsing, planner thread parsing, scope issue parsing, and healthcheck/run-loop
  parser results in `test/CliSpec.hs`.
- If an easy focused test selector is discoverable, run it in addition to the
  full suite and record the exact command. If no reliable selector is
  discoverable, record that the behavior evidence is the full
  `cabal test watcher-core-test` run plus the unchanged import-only diff.

Broad remaining-user scan:

- Run a broad scan over production, app, tests, docs, Cabal, and package
  candidates for remaining `CodexWatcher.Core.Ids` imports, for example:
  `rg -n "import CodexWatcher\\.Core\\.Ids" src app test docs *.cabal agent-workflow-* 2>/dev/null || true`
- In the notes, separate remaining production users from tests/fixtures,
  docs/Cabal, package candidates, and the public facade module
  `src/CodexWatcher/Core/Ids.hs`.
- Do not treat a clean selected-file scan or reduced remaining-user count as
  public facade deprecation/removal, Cabal exposure cleanup, docs cleanup,
  runtime compatibility cleanup, milestone completion, release approval, or
  terminal completion.
