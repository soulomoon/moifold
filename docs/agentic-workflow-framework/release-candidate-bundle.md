# Release Candidate Evidence Bundle

Status: release-candidate evidence bundle; evidence only.

Date: 2026-05-09 Asia/Shanghai.

This bundle assembles current local evidence for the `agent-workflow-core`,
`agent-workflow-codex`, and `agent-workflow-github` package candidates. It is
input for the later terminal publication gate. It does not choose whether to
publish or hold, does not authorize package upload, does not tag a release, and
does not change package descriptors, source modules, event schemas, runtime
behavior, compatibility facades, CI behavior, changelog material, or release
notes.

## Evidence Sources Inspected

Current source and configuration:

- `cabal.project`
- `moifold.cabal`
- `agent-workflow-core/agent-workflow-core.cabal`
- `agent-workflow-codex/agent-workflow-codex.cabal`
- `agent-workflow-github/agent-workflow-github.cabal`
- `.github/workflows/ci.yml`
- `scripts/validate-workflow-packages.sh`
- `test/Main.hs`
- `agent-workflow-core/README.md`
- `agent-workflow-codex/README.md`
- `agent-workflow-github/README.md`
- `examples/workflow-package-consumer`
- `docs/agentic-workflow-framework/package-identity-versioning-contract.md`
- `docs/agentic-workflow-framework/release-metadata-policy.md`
- `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`
- `docs/agentic-workflow-framework/package-extraction-readiness.md`
- `docs/agentic-workflow-framework/implemented-api-freeze.md`
- `docs/agentic-workflow-framework/package-validation.md`
- `docs/agentic-workflow-framework/package-consumer-guide.md`
- `docs/agentic-workflow-framework/changelog.md`
- `docs/agentic-workflow-framework/release-notes.md`
- `docs/agentic-workflow-framework/moifold-consumer-validation.md`

Prior round artifacts inspected:

- `round-036`: package identity and versioning contract.
- `round-037`: release metadata policy.
- `round-038`: compatibility and deprecation policy.
- `round-039`: `agent-workflow-core` standalone descriptor layout.
- `round-040`: `agent-workflow-codex` standalone descriptor layout.
- `round-041`: `agent-workflow-github` standalone descriptor layout.
- `round-042`: moifold local consumer wiring.
- `round-043`: package `cabal check` and source-distribution validation.
- `round-044`: CI matrix package validation.
- `round-045`: recursive package boundary tests.
- `round-046`: package READMEs and Haddock module headers.
- `round-047`: consumer guide and buildable consumer example.
- `round-048`: changelog and release-note material.
- `round-049`: moifold consumer validation evidence.

Prior approvals are treated as provenance, not as proof that the current tree
still passes. Current validation results are recorded below.

## Current Validation Results

| Check | Result | Evidence |
| --- | --- | --- |
| Descriptor/project wiring scan | Passed | `cabal.project` lists `.`, `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`; `moifold.cabal` consumes the standalone package names; the scan found no `moifold:agent-workflow-*` dependency and no `library agent-workflow-*` internal component definition. |
| Descriptor metadata/exposed-modules/build-depends scan | Passed | All three descriptors record `version: 0.1.0.0`, `license: MIT`, `author: soulomoon`, `maintainer: soulomoon`, `category: Development`, and `source-repository head` at `https://github.com/soulomoon/moifold.git`; exposed modules and dependency sets are package-specific. |
| Package boundary tests present | Passed | `test/Main.hs` contains `workflowCabalProjectListsStandaloneWorkflowPackages`, `workflowMoifoldCabalConsumesStandaloneWorkflowPackages`, `workflowCoreStandalonePackageKeepsPackageBoundary`, `workflowCodexStandalonePackageKeepsPackageBoundary`, `workflowGithubStandalonePackageKeepsPackageBoundary`, and `workflowMoifoldCabalLibraryDoesNotReexportAdapters`. |
| Reusable package forbidden-import scans | Passed | The required `rg` scans returned no matches for forbidden moifold lifecycle/runtime imports in `agent-workflow-core/src`, `agent-workflow-codex/src`, and `agent-workflow-github/src`. |
| Compatibility facade scan | Passed | The main `moifold` library no longer exposes `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.EventLog`, or `CodexWatcher.Workflow.Permission`; `CodexWatcher.Workflow.Types` and `CodexWatcher.Workflow.Execution` remain available as moifold-facing product surfaces. |
| `scripts/validate-workflow-packages.sh` | Passed | Ran `cabal check` for all three packages, generated local sdists, verified package roots and Cabal descriptors, and ended with `No upload or package publication command was run.` |
| `cabal build all` | Passed | Built `agent-workflow-core`, `agent-workflow-github`, `agent-workflow-codex`, the `moifold` library, and `exe:moifold` with GHC 9.12.2. |
| `cabal test watcher-core-test` | Passed | Built and ran the suite; Cabal reported `Test suite watcher-core-test: PASS` and `1 of 1 test suites (1 of 1 test cases) passed.` |
| `cabal haddock agent-workflow-core agent-workflow-codex agent-workflow-github --haddock-all` | Passed with doc follow-up | Haddock generated docs for all three packages. Output still reports missing per-export documentation and some link-destination warnings. |
| Consumer example build | Passed | `(cd examples/workflow-package-consumer && cabal build all)` built the three workflow packages and `workflow-package-consumer` from the example-local project. |
| Consumer example run | Passed | `(cd examples/workflow-package-consumer && cabal run workflow-package-consumer)` printed core planning output, Codex request construction, and GitHub command specs. |
| CI config scan | Passed locally | `.github/workflows/ci.yml` has a single matrix row for GHC `9.12.2` and Cabal `3.14.2.0`, installs `ripgrep`, and runs `cabal build all`, `cabal test watcher-core-test`, and `scripts/validate-workflow-packages.sh`. |
| Hosted CI status | Not observed for this branch | `gh auth status` succeeded, but `gh run list --workflow=CI --branch "$(git branch --show-current)" --limit 5` printed no rows. The JSON form returned `[]`. |

The package validation script wrote these ignored local artifacts:

- `dist-newstyle/sdist/agent-workflow-core-0.1.0.0.tar.gz`
- `dist-newstyle/sdist/agent-workflow-codex-0.1.0.0.tar.gz`
- `dist-newstyle/sdist/agent-workflow-github-0.1.0.0.tar.gz`

These artifacts are local evidence only.

## `agent-workflow-core`

| Area | Evidence |
| --- | --- |
| Package artifact and descriptor | `agent-workflow-core/agent-workflow-core.cabal` defines package `agent-workflow-core` at `0.1.0.0` with synopsis `Typed workflow kernel, replay, and effect plans`, `license: MIT`, `author: soulomoon`, `maintainer: soulomoon`, `category: Development`, `extra-doc-files: README.md`, and source repository `https://github.com/soulomoon/moifold.git`. |
| Exposed modules | The descriptor exposes 13 generic workflow modules: audit, codec, daemon core, DSL, event-log commit/core/file helpers, execution core, failure, indexed spec, permission core, spec, and transaction core. |
| Dependencies | `base >=4.18 && <5`, `bytestring >=0.12 && <0.13`, and `text >=2.0 && <3`. No adapter, Aeson, filesystem, process, runtime, or moifold dependency is present. |
| Package checks and sdist | `scripts/validate-workflow-packages.sh` ran `(cd agent-workflow-core && cabal check)`, generated `dist-newstyle/sdist/agent-workflow-core-0.1.0.0.tar.gz`, and verified the archive contains `agent-workflow-core-0.1.0.0/agent-workflow-core.cabal`. |
| Docs and Haddock | `agent-workflow-core/README.md` documents the workflow-kernel thesis, architecture, guarantees, non-goals, and evidence links. Haddock generated HTML for the package, with missing per-export documentation still reported. |
| Changelog and release-note evidence | `docs/agentic-workflow-framework/changelog.md` and `release-notes.md` describe the local `0.1.0.0` core candidate, pre-1.0 status, metadata, validation path, and moifold-owned exclusions. |
| Consumer validation | The consumer example uses `WorkflowSpec`, `workflowPlanObservation`, `WorkflowM`, `advance`, `emit`, and transition helpers; the run printed `observation -> event=review-accepted, effects=record-decision` and matching DSL output. |
| Compatibility and deprecation notes | Core package APIs are preferred for reusable consumers. `CodexWatcher.Workflow.EventLog` and `CodexWatcher.Workflow.Permission` have been removed from the main public surface; `CodexWatcher.Workflow.Types` and `Workflow.Execution` remain moifold product-facing surfaces. |
| Remaining follow-ups | Terminal gate should decide whether the current per-export Haddock gaps are acceptable for the intended release, and should rerun the current validation path immediately before any publication action. |

## `agent-workflow-codex`

| Area | Evidence |
| --- | --- |
| Package artifact and descriptor | `agent-workflow-codex/agent-workflow-codex.cabal` defines package `agent-workflow-codex` at `0.1.0.0` with synopsis `Codex app-server protocol and typed agent adapter`, `license: MIT`, `author: soulomoon`, `maintainer: soulomoon`, `category: Development`, `extra-doc-files: README.md`, and source repository `https://github.com/soulomoon/moifold.git`. |
| Exposed modules | The descriptor exposes 10 Codex/app-server modules: `CodexWatcher.AppServerProtocol`, typed agent modules, Codex client/interpreter/protocol/transport modules, and agent observation helpers. |
| Dependencies | `aeson >=2.2 && <3`, `agent-workflow-core >=0.1 && <0.2`, `base >=4.18 && <5`, `bytestring >=0.12 && <0.13`, `text >=2.0 && <3`, and `websockets >=0.13 && <0.14`. |
| Package checks and sdist | `scripts/validate-workflow-packages.sh` ran `(cd agent-workflow-codex && cabal check)`, generated `dist-newstyle/sdist/agent-workflow-codex-0.1.0.0.tar.gz`, and verified the archive contains `agent-workflow-codex-0.1.0.0/agent-workflow-codex.cabal`. |
| Docs and Haddock | `agent-workflow-codex/README.md` documents the Codex adapter boundary, request construction, typed ids/plans, transport helpers, and non-goals. Haddock generated HTML, with missing per-export documentation and link warnings still reported. |
| Changelog and release-note evidence | `changelog.md` and `release-notes.md` describe the local `0.1.0.0` Codex candidate, pre-1.0 status, dependency on core, adapter scope, compatibility status, and moifold-owned exclusions. |
| Consumer validation | The consumer example constructs `thread/start`, `turn/start`, and `thread/read` JSON-RPC requests through package-facing APIs. The run printed request ids 1, 2, and 3 plus JSON payloads. |
| Compatibility and deprecation notes | `CodexWatcher.AppServerClient` has been removed from the main public surface. Consumers should import `CodexWatcher.Workflow.Agent.Codex.Client` and `CodexWatcher.Workflow.Agent.Codex.Transport` directly. |
| Remaining follow-ups | Terminal gate should classify the Haddock gaps, verify hosted CI, and confirm that app-server startup policy, prompts, structured-output acceptance, and lifecycle routing remain moifold-owned in final wording. |

## `agent-workflow-github`

| Area | Evidence |
| --- | --- |
| Package artifact and descriptor | `agent-workflow-github/agent-workflow-github.cabal` defines package `agent-workflow-github` at `0.1.0.0` with synopsis `GitHub identifiers, remote metadata, and command specs`, `license: MIT`, `author: soulomoon`, `maintainer: soulomoon`, `category: Development`, `extra-doc-files: README.md`, and source repository `https://github.com/soulomoon/moifold.git`. |
| Exposed modules | The descriptor exposes `CodexWatcher.Workflow.GitHub.Command`, `CodexWatcher.Workflow.GitHub.Ids`, and `CodexWatcher.Workflow.GitHub.Remote`. |
| Dependencies | `aeson >=2.2 && <3`, `base >=4.18 && <5`, and `text >=2.0 && <3`. It does not depend on core, Codex, or moifold. |
| Package checks and sdist | `scripts/validate-workflow-packages.sh` ran `(cd agent-workflow-github && cabal check)`, generated `dist-newstyle/sdist/agent-workflow-github-0.1.0.0.tar.gz`, and verified the archive contains `agent-workflow-github-0.1.0.0/agent-workflow-github.cabal`. |
| Docs and Haddock | `agent-workflow-github/README.md` documents typed identifiers, pure remote parsers/classifiers, pure `gh`/`git` command specs, and command-execution non-goals. Haddock generated HTML, with missing per-export documentation and link warnings still reported. |
| Changelog and release-note evidence | `changelog.md` and `release-notes.md` describe the local `0.1.0.0` GitHub candidate, metadata, pure adapter scope, validation path, and moifold-owned exclusions. |
| Consumer validation | The consumer example constructs pure command specs for `gh pr list`, `gh pr view`, and `git push --dry-run`; no command is executed. |
| Compatibility and deprecation notes | New reusable consumers should import the GitHub package modules directly. Moifold still owns command execution, issue/PR lifecycle decisions, merge readiness, review publication policy, healthcheck, repair, and runtime ownership. |
| Remaining follow-ups | Terminal gate should confirm the pure command-spec surface is documented enough for the intended release and should not treat command execution policy as part of this package. |

## Shared Moifold-Owned Policy

The following remain moifold-owned and outside reusable package promises:

- concrete `WatcherEvent` values, event JSON `type` fields, schema version
  policy, event codecs, and golden replay logs;
- compatibility files and compatibility facade lifecycle policy, including
  `issue-state.json`, `daemon-state.json`, PR URL/state files, block state,
  repair state, and runtime owner files;
- issue planning, issue implementation, PR review, merge readiness, review
  publication, child fanout, terminal-state lifecycle choices, and operator
  runbooks;
- role prompts, structured-output policy, evidence rules, retry escalation,
  classifier compatibility, and prompt policy;
- filesystem writes, process execution, PID files, locks, leases, command
  execution, runtime ownership, daemon loops, app-server startup, watcher
  supervision, healthcheck, and repair;
- package upload, tag creation, release actions, and terminal publication-gate
  approval.

The current boundary scans and `watcher-core-test` coverage support this split:
reusable package source trees do not import forbidden moifold lifecycle/runtime
modules, and removed compatibility wrappers are no longer exposed by the main
moifold library.

## Remaining Blockers For The Publication Gate

- Hosted GitHub Actions status for branch
  `orchestrator/round-050-external-package-slice` was not observed. The `gh run
  list` command returned no rows and the JSON form returned `[]`.
- Haddock exits successfully, but per-export documentation coverage remains
  sparse across all three packages and link-destination warnings remain. The
  terminal gate should explicitly classify whether this is acceptable or must
  be fixed first.
- The terminal gate must rerun or accept freshly attached evidence for:
  `scripts/validate-workflow-packages.sh`, `cabal build all`, `cabal test
  watcher-core-test`, Haddock, and the consumer example build/run.
- The terminal gate must review descriptor metadata, README/Haddock claims,
  changelog material, release-note material, CI status, compatibility-facade
  status, no-upload evidence, and moifold-owned policy wording together.
- No package upload command, tag command, GitHub release command, or terminal
  publish/hold choice was run or made.
