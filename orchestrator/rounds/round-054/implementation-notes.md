### Changes Made
- `orchestrator/rounds/round-054/import-replacement-readiness.md`: added the round-local readiness artifact with current import scans, replacement paths, Cabal exposure, package-boundary expectations, protecting tests, missing evidence, and conservative `keep`/`defer` classifications for the six selected facades.
- `orchestrator/rounds/round-054/implementation-notes.md`: recorded implementation scope and verification results for this implementer round.

### Tests
- No source tests were added. Existing `test/Main.hs` assertions already protect the readiness claims used by the artifact: standalone workflow package boundaries, main-library facade exposure, app-server facade ownership, workflow event-log parity, workflow execution dry-run parity, and workflow permission policy parity.

### Notes
- Scope stayed evidence-only. No wrappers, deprecation pragmas, Cabal exposure, production imports, runtime compatibility-file behavior gates, cleanup policy, roadmap files, or project-contract files were changed.
- The literal plan import scan command was run, but it also matched replacement submodules because `\b` matches before `.` in names like `CodexWatcher.Workflow.EventLog.Core`. I recorded that result and used this stricter selected-facade scan for the artifact counts:

```sh
rg -n '^ *import +(qualified +)?CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(Types|EventLog|Execution|Permission))($| +|\()' src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github
```

- Verification commands run:

```sh
rg -n '^ *import +(qualified +)?CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(Types|EventLog|Execution|Permission))(\b| +as +| *$)' src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github
```

Result: passed with matches; includes selected facades and replacement submodule imports because of the boundary issue above.

```sh
rg -n '^ *import +(qualified +)?CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(Types|EventLog|Execution|Permission))($| +|\()' src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github
```

Result: passed with selected-facade matches only. Counts were `AppServerClient` 28, `Core.Ids` 65, `Workflow.Types` 10, `Workflow.EventLog` 3, `Workflow.Execution` 4, and `Workflow.Permission` 1.

```sh
rg -n 'CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(Types|EventLog|Execution|Permission)|Workflow\.Agent\.Codex\.(Client|Transport)|Workflow\.Agent\.Ids|Workflow\.GitHub\.Ids|Workflow\.Spec|Workflow\.EventLog\.Core|Workflow\.EventLog\.File\.Core|Workflow\.EventLog\.Commit\.Core|Workflow\.Execution\.Core|Workflow\.Permission\.Core)' README.md docs examples *.cabal */*.cabal agent-workflow-core agent-workflow-codex agent-workflow-github
```

Result: passed with expected docs, Cabal, source, and README matches.

```sh
rg -n 'exposed-modules|other-modules|CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(Types|EventLog|Execution|Permission)|Workflow\.Agent\.Codex\.(Client|Transport)|Workflow\.Agent\.Ids|Workflow\.GitHub\.Ids|Workflow\.Spec|Workflow\.EventLog\.Core|Workflow\.EventLog\.File\.Core|Workflow\.EventLog\.Commit\.Core|Workflow\.Execution\.Core|Workflow\.Permission\.Core)' *.cabal */*.cabal
```

Result: passed. `moifold.cabal` exposes selected facades; standalone package Cabal files expose replacement modules.

- Baseline checks:

```text
cabal build all: passed
cabal test watcher-core-test: passed
scripts/validate-workflow-packages.sh: passed; cabal check succeeded for all three standalone workflow packages and sdist tarballs were produced under dist-newstyle/sdist
git diff --check: passed
git diff --cached --check: passed; no files were staged
```
