### Goal

Prove that moifold builds and tests while consuming the external package
candidates `agent-workflow-core`, `agent-workflow-codex`, and
`agent-workflow-github` through the intended local package mechanism, with
reviewable evidence for package wiring, compatibility facades, the local
consumer example, and current CLI/watcher workflows.

### Approach

Treat this as a validation and evidence round, not a package-layout or release
round. Start from the existing package descriptors, package-boundary tests,
consumer example, CLI parser tests, and framework docs. Run the package and
moifold validation commands exactly enough to prove the current tree, then
record the commands, relevant outputs, and any implementation notes in a new
evidence document under `docs/agentic-workflow-framework/`.

Expected write:

- `docs/agentic-workflow-framework/moifold-consumer-validation.md`

Files to inspect but not normally edit:

- `cabal.project`
- `moifold.cabal`
- `agent-workflow-core/agent-workflow-core.cabal`
- `agent-workflow-codex/agent-workflow-codex.cabal`
- `agent-workflow-github/agent-workflow-github.cabal`
- `scripts/validate-workflow-packages.sh`
- `examples/workflow-package-consumer/cabal.project`
- `examples/workflow-package-consumer/workflow-package-consumer.cabal`
- `examples/workflow-package-consumer/app/Main.hs`
- `examples/workflow-package-consumer/README.md`
- `src/CodexWatcher/AppServerClient.hs`
- `src/CodexWatcher/AppServerProtocol.hs`
- `src/CodexWatcher/Workflow/EventLog.hs`
- `src/CodexWatcher/Workflow/Execution.hs`
- `src/CodexWatcher/Workflow/Permission.hs`
- `src/CodexWatcher/Workflow/Types.hs`
- `src/CodexWatcher/Runtime/Compatibility.hs`
- `src/CodexWatcher/Cli/Parser.hs`
- `src/CodexWatcher/Cli/Parser/Loop.hs`
- `src/CodexWatcher/Cli/Parser/Fanout.hs`
- `src/CodexWatcher/Cli/Parser/Observe.hs`
- `src/CodexWatcher/Cli/Parser/Service.hs`
- `src/CodexWatcher/Cli/Command/IssueFanout.hs`
- `src/CodexWatcher/Cli/Command/Observe.hs`
- `src/CodexWatcher/Cli/Command/Replay.hs`
- `src/CodexWatcher/Cli/Command/Service.hs`
- `src/CodexWatcher/Cli/Command/RunnerGuard.hs`
- `src/CodexWatcher/Cli/Command/AppServerProbe.hs`
- `src/CodexWatcher/AutomaticLoop/Runner.hs`
- `src/CodexWatcher/AutomaticLoop/IssuePlanningFanout.hs`
- `src/CodexWatcher/AutomaticLoop/StartupThreads.hs`
- `src/CodexWatcher/AutomaticLoop/PrReviewHandoff.hs`
- `test/Main.hs`
- `test/CliSpec.hs`
- `test/HealthcheckSpec.hs`
- `test/RuntimeSpec.hs`
- `docs/agentic-workflow-framework/package-validation.md`
- `docs/agentic-workflow-framework/package-consumer-guide.md`
- `docs/agentic-workflow-framework/package-extraction-readiness.md`
- `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`
- `docs/agentic-workflow-framework/implemented-api-freeze.md`

Do not change package descriptors, source implementation, event schemas, golden
fixtures, compatibility facades, runtime behavior, healthcheck behavior, repair
behavior, prompt policy, CI, changelog/release notes, or source-distribution
artifacts unless a validation command exposes a concrete failure. If that
happens, make the smallest necessary fix in the failing surface and record the
failure, fix, and rerun evidence in the validation document.

### Steps

1. Confirm the starting scope and worktree safety.
   - Run `git status --short`.
   - Re-read `orchestrator/rounds/round-049/selection.md`,
     `orchestrator/roadmaps/2026-05-09-00-external-package-extraction/rev-001/verification.md`,
     and `orchestrator/project-contract.md`.
   - Note any pre-existing edits, especially `orchestrator/state.json`, and do
     not modify or revert them.

2. Inspect descriptor and local-package wiring.
   - Confirm `cabal.project` lists only the root package plus
     `agent-workflow-core`, `agent-workflow-codex`, and
     `agent-workflow-github`.
   - Confirm `moifold.cabal` main library and `watcher-core-test` depend on the
     standalone names `agent-workflow-core >=0.1 && <0.2`,
     `agent-workflow-codex >=0.1 && <0.2`, and
     `agent-workflow-github >=0.1 && <0.2`.
   - Confirm `moifold.cabal` no longer contains internal component names such
     as `library agent-workflow-core` or `moifold:agent-workflow-*`.
   - Confirm each standalone package descriptor exposes only its intended
     module set and approved dependency set.
   - Use focused scans:

```sh
rg -n "packages:|agent-workflow-(core|codex|github)|moifold:agent-workflow|library agent-workflow" cabal.project moifold.cabal agent-workflow-core/agent-workflow-core.cabal agent-workflow-codex/agent-workflow-codex.cabal agent-workflow-github/agent-workflow-github.cabal examples/workflow-package-consumer/cabal.project examples/workflow-package-consumer/workflow-package-consumer.cabal
rg -n "workflowMoifoldCabalConsumesStandaloneWorkflowPackages|workflowCabalProjectListsStandaloneWorkflowPackages|workflowCoreStandalonePackageKeepsPackageBoundary|workflowCodexStandalonePackageKeepsPackageBoundary|workflowGithubStandalonePackageKeepsPackageBoundary" test/Main.hs
```

3. Inspect package-boundary and import-scan evidence.
   - Verify `test/Main.hs` still contains recursive source-tree/package
     assertions rather than a hand-listed source subset.
   - Verify package source imports do not pull moifold lifecycle, runtime,
     healthcheck, repair, compatibility-file, or adapter ownership into the
     reusable packages.
   - Use focused scans and record whether each returns no matches:

```sh
rg -n "^import (CodexWatcher\\.(Core|Domain|Effects|EventLog|Observation|StateMachine|Runtime|GhGit|Daemon|DaemonLoop|ChildDaemon|Healthcheck|EventLogRepair|RunnerGuard|WatcherRuntimeStatus|Supervisor)|Data\\.Aeson)" agent-workflow-core/src
rg -n "^import CodexWatcher\\.(AppServerClient|ActionExecutor|ChildDaemon|Daemon|DaemonLoop|Domain|Effects|EventLog|EventLogRepair|GhGit|Healthcheck|Runtime|StateMachine|Workflow\\.GitHub|Workflow\\.Moifold|Workflow\\.Types)" agent-workflow-codex/src
rg -n "^import CodexWatcher\\.(AppServer|AppServerClient|AppServerProtocol|ChildDaemon|Cli|Core|Daemon|DaemonLoop|Domain|EffectInterpreter|Effects|EventLog|EventLogRepair|GhGit|Healthcheck|Json|Logging|Observation|Runtime|StateMachine|Supervisor|Turn|TurnOutput|Watcher|Workflow\\.Agent|Workflow\\.Daemon|Workflow\\.EventLog|Workflow\\.Execution|Workflow\\.Moifold|Workflow\\.Observation|Workflow\\.Permission|Workflow\\.Transaction|Workflow\\.Types)" agent-workflow-github/src
```

4. Inspect compatibility-facade availability and current moifold ownership.
   - Confirm `src/CodexWatcher/AppServerClient.hs` remains an available
     compatibility wrapper importing `Workflow.Agent.Codex.Client` and
     `Workflow.Agent.Codex.Transport`.
   - Confirm `test/Main.hs` still asserts
     `workflowMoifoldCabalLibraryDoesNotReexportAdapters`,
     `workflowFacadeReplayMatchesEventLog`,
     `workflowPermissionFacadeMatchesStateMachine`,
     `workflowExecutionFacadeDryRunMatchesExecutor`,
     `workflowPrReviewCheckingFacadeMatchesWatcher`, and
     `workflowPrReviewMergeabilityFacadeMatchesWatcher`.
   - Confirm `Runtime.Compatibility`, CLI replay/observe/automatic-loop code,
     and docs still treat compatibility files as moifold-owned.
   - Use focused scans:

```sh
rg -n "^module CodexWatcher\\.(AppServerClient|Workflow\\.(EventLog|Execution|Permission|Types))|import CodexWatcher\\.Workflow\\.(Agent\\.Codex\\.(Client|Transport)|EventLog\\.Core|Execution\\.Core|Permission\\.Core|Spec)" src/CodexWatcher/AppServerClient.hs src/CodexWatcher/Workflow/EventLog.hs src/CodexWatcher/Workflow/Execution.hs src/CodexWatcher/Workflow/Permission.hs src/CodexWatcher/Workflow/Types.hs
rg -n "workflowMoifoldCabalLibraryDoesNotReexportAdapters|workflowFacadeReplayMatchesEventLog|workflowPermissionFacadeMatchesStateMachine|workflowExecutionFacadeDryRunMatchesExecutor|workflowPrReviewCheckingFacadeMatchesWatcher|workflowPrReviewMergeabilityFacadeMatchesWatcher" test/Main.hs
rg -n "compatibilityStateWrites|writeCompatibility|issue-state\\.json|daemon-state\\.json|planning-state\\.json|block-state|repair-state|runtime-owner" src/CodexWatcher/Runtime/Compatibility.hs src/CodexWatcher/Cli/Command/Replay.hs src/CodexWatcher/Cli/Command/Observe.hs src/CodexWatcher/AutomaticLoop/Runner.hs src/CodexWatcher/AutomaticLoop/IssuePlanningFanout.hs src/CodexWatcher/AutomaticLoop/StartupThreads.hs src/CodexWatcher/AutomaticLoop/PrReviewHandoff.hs docs/agentic-workflow-framework/compatibility-deprecation-policy.md
```

5. Validate package candidates and local source distributions without any
   publication action.
   - Run `scripts/validate-workflow-packages.sh`.
   - Record the package check commands it runs, the local tarball paths under
     `dist-newstyle/sdist/`, and the script's final no-upload/no-publication
     statement in the evidence doc.
   - Do not commit or upload generated `dist-newstyle/` artifacts.

6. Validate the external-consumer example.
   - Inspect the example project and executable to confirm it depends on
     `agent-workflow-core`, `agent-workflow-codex`, and
     `agent-workflow-github` through local paths and does not depend on
     `moifold`.
   - Run:

```sh
(cd examples/workflow-package-consumer && cabal build all)
(cd examples/workflow-package-consumer && cabal run workflow-package-consumer)
```

   - Record the output sections proving the example exercised the core,
     Codex, and GitHub packages.

7. Validate moifold as the product consumer.
   - Run the roadmap baseline commands:

```sh
cabal build all
cabal test watcher-core-test
```

   - In the evidence doc, call out the specific tests in `test/Main.hs`,
     `test/CliSpec.hs`, `test/HealthcheckSpec.hs`, and `test/RuntimeSpec.hs`
     that cover package boundary scans, facade parity, CLI parser coverage,
     healthcheck lifecycle reporting, and GitHub command rendering.

8. Run safe repo-local CLI/watcher smoke checks.
   - Prefer parser/help/rendering commands that do not contact GitHub, do not
     start an app-server, and do not write product state.
   - Run:

```sh
cabal run exe:moifold -- --help
cabal run exe:moifold -- run-issue-planning --help
cabal run exe:moifold -- run-issue-implement --help
cabal run exe:moifold -- run-pr-review --help
cabal run exe:moifold -- issue-fanout --help
cabal run exe:moifold -- observe-once --help
cabal run exe:moifold -- render-service --name round-049-smoke --domain issue-planning --events /tmp/moifold-round-049/events.jsonl --state-dir /tmp/moifold-round-049/state --repo soulomoon/mlf2 --workdir /tmp/moifold-round-049/work --app-server-host 127.0.0.1 --app-server-port 3000 --thread-id planner-thread --executable /tmp/moifold-smoke
```

   - Optionally run a read-only empty-root healthcheck if the command is fast
     in the local environment:

```sh
tmp_state_root="$(mktemp -d)"
cabal run exe:moifold -- healthcheck --state-root "$tmp_state_root" --repo soulomoon/mlf2
```

   - Record that these are smoke checks for command availability and rendering,
     not live watcher/app-server integration or publication approval.

9. Write `docs/agentic-workflow-framework/moifold-consumer-validation.md`.
   - Include: status, date, scope, commands run, descriptor wiring evidence,
     boundary/import-scan evidence, compatibility-facade evidence, local
     consumer-example output, moifold build/test output, CLI/watcher smoke
     output, implementation notes, and explicit non-goals.
   - State clearly that no package upload, publication approval, release
     candidate bundle assembly, descriptor/version change, compatibility
     removal, event schema change, golden fixture change, runtime policy change,
     healthcheck policy change, repair policy change, or prompt-policy change
     occurred.
   - If any command fails, document the exact failing command and first useful
     error before deciding whether a narrow fix is in scope.

10. Finish with hygiene checks.
    - Run `git diff --check`.
    - Run `git diff -- docs/agentic-workflow-framework/moifold-consumer-validation.md`
      and confirm only the intended evidence doc changed unless a concrete
      validation failure required a narrow fix.
    - Do not stage, commit, push, or edit `orchestrator/state.json`.

### Verification

Required commands for a passing round:

```sh
scripts/validate-workflow-packages.sh
(cd examples/workflow-package-consumer && cabal build all)
(cd examples/workflow-package-consumer && cabal run workflow-package-consumer)
cabal build all
cabal test watcher-core-test
cabal run exe:moifold -- --help
cabal run exe:moifold -- run-issue-planning --help
cabal run exe:moifold -- run-issue-implement --help
cabal run exe:moifold -- run-pr-review --help
cabal run exe:moifold -- issue-fanout --help
cabal run exe:moifold -- observe-once --help
cabal run exe:moifold -- render-service --name round-049-smoke --domain issue-planning --events /tmp/moifold-round-049/events.jsonl --state-dir /tmp/moifold-round-049/state --repo soulomoon/mlf2 --workdir /tmp/moifold-round-049/work --app-server-host 127.0.0.1 --app-server-port 3000 --thread-id planner-thread --executable /tmp/moifold-smoke
git diff --check
```

Required evidence in
`docs/agentic-workflow-framework/moifold-consumer-validation.md`:

- `cabal.project` and `moifold.cabal` prove moifold consumes the standalone
  package names rather than internal sublibraries.
- Package cabals prove `agent-workflow-core`, `agent-workflow-codex`, and
  `agent-workflow-github` keep the intended exposed modules and dependency
  ownership.
- Boundary scans and `watcher-core-test` prove reusable package candidates do
  not import moifold lifecycle/runtime/compatibility ownership.
- Compatibility facade checks prove existing moifold import paths remain
  available and adapter modules are not reexported by the main library.
- The consumer example builds and runs through local package paths without a
  `moifold` dependency.
- CLI/watcher smoke checks prove current command surfaces still parse/render
  through moifold-owned workflow code.
- Non-goals explicitly rule out publication, release approval, release-candidate
  bundle assembly, descriptor/version changes, compatibility removal, event
  schema/golden fixture changes, and broad runtime/healthcheck/repair/prompt
  policy changes.

Optional validation, only if cheap and non-disruptive:

```sh
tmp_state_root="$(mktemp -d)"
cabal run exe:moifold -- healthcheck --state-root "$tmp_state_root" --repo soulomoon/mlf2
```

### Worker Fan-Out

No worker fan-out. This round is serial validation and evidence capture with a
single expected docs output, so splitting work would add coordination overhead
without a clear non-overlapping ownership boundary. Do not write
`worker-plan.json`.
