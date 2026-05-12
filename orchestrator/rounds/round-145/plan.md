### Goal

Move only `test/WorkflowDocsMigrationSpec.hs` off the
`CodexWatcher.AppServerClient` compatibility facade for `AppServerTurn (..)`,
using the direct owner import
`CodexWatcher.Workflow.Agent.Codex.Client`, while preserving
`workflowDocsMigrationAgentRoleClassifiesCompleteOutput` and
`workflowDocsMigrationTests`.

### Approach

Make a single import-only migration in the selected test module. Do not change
test bodies, helper modules, test-suite wiring, package descriptors, docs,
policy, public facade exports, direct-owner module exports, production files,
deprecation/removal state, Cabal exposure, or milestone status.

Worker fan-out is not used. The selected scope is one file and one import
boundary, so splitting work would add coordination risk without independent
ownership.

### Steps

1. Confirm the selected file still imports the compatibility facade and uses it
   only for `AppServerTurn`:
   `rg -n "CodexWatcher\\.AppServerClient|AppServerTurn" test/WorkflowDocsMigrationSpec.hs`.
2. In `test/WorkflowDocsMigrationSpec.hs`, replace
   `import CodexWatcher.AppServerClient` with
   `import CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn (..))`.
3. Leave `workflowDocsMigrationAgentRoleClassifiesCompleteOutput`,
   `workflowDocsMigrationTests`, and all other test bodies unchanged.
4. Do not touch any other file, including `test/Main.hs`,
   `test/TestSupport/Workflow.hs`, `test/FacadeImportPolicySpec.hs`,
   `moifold.cabal`, `src/CodexWatcher/AppServerClient.hs`, docs, or roadmap
   artifacts outside the normal implementation notes/review artifacts.
5. Record the broad `CodexWatcher.AppServerClient` scan output as remaining
   out-of-scope users; do not migrate those users in this round.

### Verification

Run the checks below after the import change.

Selected-file import evidence:

```sh
if rg -n "^import CodexWatcher\\.AppServerClient\\b" test/WorkflowDocsMigrationSpec.hs; then
  echo "unexpected selected-file AppServerClient import remains"
  exit 1
else
  echo "selected file no longer imports CodexWatcher.AppServerClient"
fi

rg -n "^import CodexWatcher\\.Workflow\\.Agent\\.Codex\\.Client \\(AppServerTurn \\(\\.\\.\\)\\)" test/WorkflowDocsMigrationSpec.hs
rg -n "workflowDocsMigrationAgentRoleClassifiesCompleteOutput|workflowDocsMigrationTests|AppServerTurn" test/WorkflowDocsMigrationSpec.hs
```

Broad remaining-facade inventory for reviewer context:

```sh
rg -n "CodexWatcher\\.AppServerClient" src app test docs agent-workflow-core agent-workflow-codex agent-workflow-github examples *.cabal cabal.project 2>/dev/null || true
```

Diff scope:

```sh
git diff -- test/WorkflowDocsMigrationSpec.hs
git diff --name-only
```

Required baseline checks:

```sh
cabal test watcher-core-test
cabal build all
git diff --check
git diff --cached --check
```

Optional focused check, if the local GHCi test-suite target loads cleanly; this
does not replace `cabal test watcher-core-test`:

```sh
cabal repl watcher-core-test --repl-options=-ignore-dot-ghci <<'EOF'
:module + WorkflowDocsMigrationSpec
workflowDocsMigrationTests
:quit
EOF
```
