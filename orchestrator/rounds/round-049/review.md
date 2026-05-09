### Checks Run
- Command: `sed -n '1,240p' orchestrator/roles/reviewer.md`
  Result: pass. Confirmed reviewer duties: run baseline and task-specific checks, compare integrated diff to plan, do not fix implementation directly, and write review artifacts with an explicit approve/reject decision.

- Command: `sed -n '1,260p' orchestrator/roadmaps/2026-05-09-00-external-package-extraction/rev-001/verification.md`
  Result: pass. Confirmed roadmap `2026-05-09-00-external-package-extraction`, revision `rev-001`, baseline checks, release-gate restrictions, package ownership, compatibility, event-compatibility, and docs/release non-goals.

- Command: `sed -n '1,260p' orchestrator/project-contract.md`
  Result: pass. Confirmed stable ownership split: generic workflow kernel in `agent-workflow-core`, Codex app-server protocol/adapters in `agent-workflow-codex`, GitHub identifiers/command rendering in `agent-workflow-github`, and concrete moifold lifecycle/runtime/healthcheck/repair/compatibility ownership in the main library.

- Command: `git status --short`
  Result: pass. Staged payload is `docs/agentic-workflow-framework/moifold-consumer-validation.md`, `orchestrator/rounds/round-049/implementation-notes.md`, `orchestrator/rounds/round-049/plan.md`, and `orchestrator/rounds/round-049/selection.md`; `orchestrator/state.json` is modified but unstaged controller bookkeeping.

- Command: `git diff --cached --name-only`
  Result: pass. Output:
  ```text
  docs/agentic-workflow-framework/moifold-consumer-validation.md
  orchestrator/rounds/round-049/implementation-notes.md
  orchestrator/rounds/round-049/plan.md
  orchestrator/rounds/round-049/selection.md
  ```
  The staged payload excludes `orchestrator/state.json`, package descriptors, root `cabal.project`, CI, source modules, roadmap files, changelog/release notes, and generated artifacts.

- Command: `git diff --cached --stat`
  Result: pass. Output showed 4 staged files, 732 insertions: the consumer-validation evidence doc plus selection/plan/implementation notes.

- Command: `git diff --check`
  Result: pass. No whitespace errors.

- Command: `git diff --cached --check`
  Result: pass. No staged whitespace errors.

- Command: `git diff --name-only | rg -v '^(docs/agentic-workflow-framework/moifold-consumer-validation\.md|orchestrator/rounds/round-049/(selection|plan|implementation-notes|review|review-record)\.md)$' || true`
  Result: pass. Output only `orchestrator/state.json`, which is outside implementation payload and intentionally dirty controller state.

- Command: `rg -n "packages:|agent-workflow-(core|codex|github)|moifold:agent-workflow|library agent-workflow" cabal.project moifold.cabal agent-workflow-core/agent-workflow-core.cabal agent-workflow-codex/agent-workflow-codex.cabal agent-workflow-github/agent-workflow-github.cabal examples/workflow-package-consumer/cabal.project examples/workflow-package-consumer/workflow-package-consumer.cabal`
  Result: pass. Confirmed root `cabal.project` lists `.`, `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`; `moifold.cabal` depends on standalone package names with `>=0.1 && <0.2`; no `moifold:agent-workflow-*` or `library agent-workflow-*` matches appeared.

- Command: `sed -n '1,110p' agent-workflow-core/agent-workflow-core.cabal && sed -n '1,115p' agent-workflow-codex/agent-workflow-codex.cabal && sed -n '1,90p' agent-workflow-github/agent-workflow-github.cabal`
  Result: pass. Confirmed standalone package descriptors expose the intended module sets and dependencies: core uses `base`, `bytestring`, `text`; Codex uses `aeson`, `agent-workflow-core`, `base`, `bytestring`, `text`, `websockets`; GitHub uses `aeson`, `base`, `text`.

- Command: `rg -n "workflowMoifoldCabalConsumesStandaloneWorkflowPackages|workflowCabalProjectListsStandaloneWorkflowPackages|workflowCoreStandalonePackageKeepsPackageBoundary|workflowCodexStandalonePackageKeepsPackageBoundary|workflowGithubStandalonePackageKeepsPackageBoundary" test/Main.hs`
  Result: pass. Found the package wiring and boundary assertions in `test/Main.hs`.

- Command: `rg -n "sourceFilesUnder|sourceModulesUnder|sourceImportViolationsUnder|sourceTextNeedleViolationsUnder" test/Main.hs`
  Result: pass. Confirmed recursive source-tree helper assertions remain present.

- Command: `rg -n "^import (CodexWatcher\.(Core|Domain|Effects|EventLog|Observation|StateMachine|Runtime|GhGit|Daemon|DaemonLoop|ChildDaemon|Healthcheck|EventLogRepair|RunnerGuard|WatcherRuntimeStatus|Supervisor)|Data\.Aeson)" agent-workflow-core/src`
  Result: pass. No matches; core package does not import forbidden moifold lifecycle/runtime modules or `Data.Aeson`.

- Command: `rg -n "^import CodexWatcher\.(AppServerClient|ActionExecutor|ChildDaemon|Daemon|DaemonLoop|Domain|Effects|EventLog|EventLogRepair|GhGit|Healthcheck|Runtime|StateMachine|Workflow\.GitHub|Workflow\.Moifold|Workflow\.Types)" agent-workflow-codex/src`
  Result: pass. No matches; Codex package does not import forbidden moifold lifecycle/runtime/compatibility modules.

- Command: `rg -n "^import CodexWatcher\.(AppServer|AppServerClient|AppServerProtocol|ChildDaemon|Cli|Core|Daemon|DaemonLoop|Domain|EffectInterpreter|Effects|EventLog|EventLogRepair|GhGit|Healthcheck|Json|Logging|Observation|Runtime|StateMachine|Supervisor|Turn|TurnOutput|Watcher|Workflow\.Agent|Workflow\.Daemon|Workflow\.EventLog|Workflow\.Execution|Workflow\.Moifold|Workflow\.Observation|Workflow\.Permission|Workflow\.Transaction|Workflow\.Types)" agent-workflow-github/src`
  Result: pass. No matches; GitHub package does not import forbidden moifold lifecycle/runtime/workflow ownership modules.

- Command: `rg -n "^module CodexWatcher\.(AppServerClient|Workflow\.(EventLog|Execution|Permission|Types))|import CodexWatcher\.Workflow\.(Agent\.Codex\.(Client|Transport)|EventLog\.Core|Execution\.Core|Permission\.Core|Spec)" src/CodexWatcher/AppServerClient.hs src/CodexWatcher/Workflow/EventLog.hs src/CodexWatcher/Workflow/Execution.hs src/CodexWatcher/Workflow/Permission.hs src/CodexWatcher/Workflow/Types.hs`
  Result: pass. Confirmed compatibility modules remain available and import the package-owned core/adapter modules.

- Command: `rg -n "workflowMoifoldCabalLibraryDoesNotReexportAdapters|workflowFacadeReplayMatchesEventLog|workflowPermissionFacadeMatchesStateMachine|workflowExecutionFacadeDryRunMatchesExecutor|workflowPrReviewCheckingFacadeMatchesWatcher|workflowPrReviewMergeabilityFacadeMatchesWatcher" test/Main.hs`
  Result: pass. Confirmed facade parity and adapter reexport assertions remain in `watcher-core-test`.

- Command: `rg -n "compatibilityStateWrites|writeCompatibility|issue-state\.json|daemon-state\.json|planning-state\.json|block-state|repair-state|runtime-owner" src/CodexWatcher/Runtime/Compatibility.hs src/CodexWatcher/Cli/Command/Replay.hs src/CodexWatcher/Cli/Command/Observe.hs src/CodexWatcher/AutomaticLoop/Runner.hs src/CodexWatcher/AutomaticLoop/IssuePlanningFanout.hs src/CodexWatcher/AutomaticLoop/StartupThreads.hs src/CodexWatcher/AutomaticLoop/PrReviewHandoff.hs docs/agentic-workflow-framework/compatibility-deprecation-policy.md`
  Result: pass. Confirmed compatibility file ownership remains in moifold runtime/CLI/automatic-loop paths and the compatibility policy doc.

- Command: `scripts/validate-workflow-packages.sh`
  Result: pass. Ran `cabal check` for all three workflow package candidates, generated and validated local sdists under `dist-newstyle/sdist/`, and ended with `No upload or package publication command was run.`

- Command: `(cd examples/workflow-package-consumer && cabal build all)`
  Result: pass. Cabal reported `Up to date`, confirming the example consumer builds against the local standalone package candidates.

- Command: `(cd examples/workflow-package-consumer && cabal run workflow-package-consumer)`
  Result: pass. Output included `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github` sections, JSON-RPC request construction for `thread/start`, `turn/start`, `thread/read`, and GitHub command rendering.

- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`; the full package set remains buildable.

- Command: `cabal test watcher-core-test`
  Result: pass. Test suite completed with `Test suite watcher-core-test: PASS` and `1 of 1 test suites (1 of 1 test cases) passed.`

- Command: `cabal run exe:moifold -- --help`
  Result: pass. Top-level help rendered current commands including `render-service`, `issue-fanout`, `observe-once`, `run-pr-review`, `run-issue-implement`, `run-issue-planning`, guards, healthcheck, and repair.

- Command: `cabal run exe:moifold -- run-issue-planning --help`
  Result: pass. Issue-planning loop help rendered expected `--events`, `--state-dir`, `--repo`, app-server, execution, loop, scope, fanout, workdir, branch, and thread options.

- Command: `cabal run exe:moifold -- run-issue-implement --help`
  Result: pass. Issue-implementation loop help rendered.

- Command: `cabal run exe:moifold -- run-pr-review --help`
  Result: pass. PR-review loop help rendered.

- Command: `cabal run exe:moifold -- issue-fanout --help`
  Result: pass. Issue-fanout help rendered expected repo/root/parallelism/app-server/workdir options.

- Command: `cabal run exe:moifold -- observe-once --help`
  Result: pass. Observe-once help rendered expected domain, observation, app-server, PR, commit, plan, review-thread, and comment options.

- Command: `cabal run exe:moifold -- render-service --name round-049-smoke --domain issue-planning --events /tmp/moifold-round-049/events.jsonl --state-dir /tmp/moifold-round-049/state --repo soulomoon/mlf2 --workdir /tmp/moifold-round-049/work --app-server-host 127.0.0.1 --app-server-port 3000 --thread-id planner-thread --executable /tmp/moifold-smoke`
  Result: pass. Rendered systemd and logrotate output; `ExecStart` targets `/tmp/moifold-smoke run-issue-planning ... --execute --loop`.

- Command: `tmp_state_root="$(mktemp -d)"; cabal run exe:moifold -- healthcheck --state-root "$tmp_state_root" --repo soulomoon/mlf2`
  Result: pass. Empty-root healthcheck returned JSON with `"status":"ok"`, no problems, zero configs/watchers, and read-only notes.

- Command: `rg -n "package upload|publication|release approval|release-candidate|descriptor|version|compatibility facade removal|event schema|golden|runtime policy|healthcheck policy|repair policy|prompt-policy|CI changes|changelog|release-note|source-distribution artifact" docs/agentic-workflow-framework/moifold-consumer-validation.md`
  Result: pass. Manual inspection plus scan confirmed the evidence doc names these as non-goals and does not approve release, upload, descriptor/version changes, compatibility removal, event/golden changes, runtime/healthcheck/repair/prompt policy changes, CI changes, changelog/release-note changes, or committed source-distribution artifacts.

### Plan Compliance
- Step 1, starting scope and worktree safety: met. `git status --short`, selection, verification, and project contract were reviewed. `orchestrator/state.json` was left untouched and remains unstaged.

- Step 2, descriptor and local-package wiring: met. Root `cabal.project` lists only the root package plus the three standalone workflow packages; `moifold.cabal` consumes standalone package names with approved bounds; no internal workflow sublibrary names or dependencies are present.

- Step 3, package-boundary and import-scan evidence: met. `test/Main.hs` has recursive source-tree/package assertions, and forbidden import scans for core, Codex, and GitHub package source trees returned no matches.

- Step 4, compatibility-facade availability and moifold ownership: met. `CodexWatcher.AppServerClient` and `CodexWatcher.Workflow.*` facades remain available; facade parity and no-adapter-reexport assertions remain in `test/Main.hs`; compatibility file writes remain in moifold runtime/CLI/automatic-loop code.

- Step 5, package validation without publication: met. `scripts/validate-workflow-packages.sh` passed, produced local ignored sdists, validated their cabal files, and explicitly did not upload or publish.

- Step 6, external-consumer example: met. The example builds and runs, exercises the core, Codex, and GitHub package APIs, and does not depend on `moifold`.

- Step 7, moifold product consumer validation: met. `cabal build all` and `cabal test watcher-core-test` passed.

- Step 8, safe CLI/watcher smoke checks: met. Top-level help, all recorded loop/fanout/observe help commands, render-service, and empty-root healthcheck passed without live GitHub mutation, app-server startup, or product state writes.

- Step 9, evidence document: met. `docs/agentic-workflow-framework/moifold-consumer-validation.md` records scope, command evidence, descriptor wiring, boundary/import scans, compatibility facade checks, consumer example output, moifold build/test output, CLI/watcher smoke output, implementation notes, and explicit non-goals.

- Step 10, hygiene checks: met. `git diff --check` and `git diff --cached --check` passed. Staged payload is limited to the evidence doc and round selection/plan/implementation notes; the only non-payload dirty file is controller-owned `orchestrator/state.json`.

### Decision
**APPROVED**

### Evidence
Roadmap metadata reviewed for this decision:

- Roadmap id: `2026-05-09-00-external-package-extraction`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-09-00-external-package-extraction/rev-001`
- Milestone: `milestone-005-consumer-release-gate`
- Direction: `direction-014-moifold-consumer-validation`
- Extracted item: `item-049-moifold-consumer-validation`

The integrated staged result is evidence-only. It contains the expected consumer-validation doc and round notes, and it excludes implementation payload changes to controller state, package descriptors, root `cabal.project`, CI, source modules, roadmap files, changelog/release notes, and generated artifacts.

Baseline checks passed: `git diff --check`, `git diff --cached --check`, `cabal build all`, and `cabal test watcher-core-test`.

Task-specific checks passed: package validation, external consumer example build/run, descriptor/wiring scan, forbidden package import scans, compatibility facade scans, CLI help/rendering smoke checks, and empty-root healthcheck.

Manual evidence inspection found no release approval, package upload, release-candidate bundle assembly, descriptor/version changes, compatibility facade removal, event schema/golden changes, runtime/healthcheck/repair/prompt policy changes, CI changes, changelog/release-note changes, source-distribution artifact commits, roadmap edits, or controller-state payload changes.
