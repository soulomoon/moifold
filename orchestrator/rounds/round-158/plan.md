### Goal

Migrate only `src/CodexWatcher/Cli/Parser/Observe.hs` away from the combined
`CodexWatcher.Core.Ids` compatibility facade by importing the existing
observe parser identifier constructors from their direct owner modules:
`CommitSha` and `PrNumber` from `CodexWatcher.Workflow.GitHub.Ids`, and
`TurnId` from `CodexWatcher.Workflow.Agent.Ids`.

This round is import convergence only. It must preserve the `observe-once`
parser surface and leave all public compatibility facades, package exposure,
docs, runtime compatibility files, and broader `Core.Ids` migration work
untouched.

### Approach

Keep the implementation to a single production import edit in
`src/CodexWatcher/Cli/Parser/Observe.hs`. Replace the one
`CodexWatcher.Core.Ids (CommitSha (..), PrNumber (..), TurnId (..))` import
with two direct owner imports:

- `CodexWatcher.Workflow.GitHub.Ids (CommitSha (..), PrNumber (..))`
- `CodexWatcher.Workflow.Agent.Ids (TurnId (..))`

Do not alter `observeOnceParser`, parser helper usage, option names, option
metavars, help text, optional field order, review-thread parsing, or
`ObserveOnceCli` construction. Do not touch other parser modules or package
descriptors.

This follows the project contract by moving reusable-package-oriented code
toward owner modules while preserving compatibility facade availability. It
does not imply deprecation, Cabal exposure cleanup, public removal approval, or
terminal milestone completion.

### Steps

1. Open `src/CodexWatcher/Cli/Parser/Observe.hs` and confirm the only intended
   production change is the identifier import block.
2. Replace the existing `CodexWatcher.Core.Ids` import with the two direct
   owner imports named in the approach.
3. Re-read the resulting import section and `observeOnceParser` to confirm no
   parser expression, constructor application, option name, help string,
   optional wrapper, or review-thread parser call changed.
4. Confirm the diff contains only
   `src/CodexWatcher/Cli/Parser/Observe.hs` plus this round plan artifact.
5. Record implementation notes in the round artifact after implementation,
   including the exact diff scope and validation commands/results.

### Verification

Required local checks for the worker:

- `git diff --check`
- `cabal build all`
- `cabal test watcher-core-test`

Focused manual checks:

- Confirm `src/CodexWatcher/Cli/Parser/Observe.hs` no longer imports
  `CodexWatcher.Core.Ids`.
- Confirm `CommitSha (..)` and `PrNumber (..)` come from
  `CodexWatcher.Workflow.GitHub.Ids`, and `TurnId (..)` comes from
  `CodexWatcher.Workflow.Agent.Ids`.
- Confirm `observeOnceParser` still constructs the same `ObserveOnceCli`
  fields in the same order.
- Confirm the `observe-once` options remain unchanged, including
  `implementation-turn-id`, `pr-number`, `commit-sha`, `merge-commit-sha`,
  `review-thread-ids`, and the optional thread/turn fields.
- Confirm there are no package descriptor, facade module, docs, runtime
  compatibility, command execution, parser helper, or test rewrites in the
  implementation diff.

### Worker Fan-Out

No worker fan-out is justified. The selected item is a single-file production
import migration with no independent ownership boundaries.
