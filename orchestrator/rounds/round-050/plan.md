### Goal

Assemble a source-backed release-candidate evidence bundle for
`agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`
that is reviewable input for the later final go/no-go gate. The bundle should
summarize package artifacts, checks, docs, changelog/release-note evidence, CI
status, compatibility and deprecation notes, moifold consumer validation, and
remaining blockers without uploading packages or making a final publication or
hold decision.

### Approach

Treat this as an evidence rollup round. Do not change package descriptors,
versions, source modules, event schemas, runtime behavior, compatibility
facades, CI behavior, or release machinery unless a concrete evidence mismatch
is discovered and the smallest safe correction is required. The expected
implementation output is a new docs artifact organized by package, plus normal
round implementation notes.

Likely files to change:

- Add `docs/agentic-workflow-framework/release-candidate-bundle.md`.
- Optionally update `docs/agentic-workflow-framework/README.md` with one index
  link to the bundle if the implementer keeps the diff documentation-only.
- Write `orchestrator/rounds/round-050/implementation-notes.md`.

Files to inspect but not normally edit:

- `orchestrator/rounds/round-050/selection.md`
- `orchestrator/roadmaps/2026-05-09-00-external-package-extraction/rev-001/verification.md`
- `orchestrator/project-contract.md`
- `orchestrator/state.json`
- `cabal.project`
- `moifold.cabal`
- `agent-workflow-core/agent-workflow-core.cabal`
- `agent-workflow-codex/agent-workflow-codex.cabal`
- `agent-workflow-github/agent-workflow-github.cabal`
- `.github/workflows/ci.yml`
- `scripts/validate-workflow-packages.sh`
- `test/Main.hs`
- `test/CliSpec.hs`
- `test/HealthcheckSpec.hs`
- `test/RuntimeSpec.hs`
- `agent-workflow-core/README.md`
- `agent-workflow-codex/README.md`
- `agent-workflow-github/README.md`
- `examples/workflow-package-consumer/README.md`
- `examples/workflow-package-consumer/cabal.project`
- `examples/workflow-package-consumer/workflow-package-consumer.cabal`
- `examples/workflow-package-consumer/app/Main.hs`
- `docs/agentic-workflow-framework/README.md`
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

Prior round artifacts to inspect as evidence, with emphasis on
`implementation-notes.md`, `review.md`, and `merge.md`:

- `orchestrator/rounds/round-036/`: package identity and versioning contract.
- `orchestrator/rounds/round-037/`: release metadata policy.
- `orchestrator/rounds/round-038/`: compatibility and deprecation policy.
- `orchestrator/rounds/round-039/`: `agent-workflow-core` descriptor layout.
- `orchestrator/rounds/round-040/`: `agent-workflow-codex` descriptor layout.
- `orchestrator/rounds/round-041/`: `agent-workflow-github` descriptor layout.
- `orchestrator/rounds/round-042/`: moifold local consumer wiring.
- `orchestrator/rounds/round-043/`: package `cabal check` and local sdist
  validation.
- `orchestrator/rounds/round-044/`: CI matrix package validation.
- `orchestrator/rounds/round-045/`: boundary test refresh.
- `orchestrator/rounds/round-046/`: package READMEs and Haddock headers.
- `orchestrator/rounds/round-047/`: examples and consumer guide.
- `orchestrator/rounds/round-048/`: changelog and release-note material.
- `orchestrator/rounds/round-049/`: moifold consumer validation.

The bundle should not say "go", "no-go", "approved for publication",
"release-ready", "uploaded", or "published" except when explicitly negating
those claims or describing that a later release-gate review must decide them.
For CI, distinguish local workflow/config validation from hosted GitHub Actions
state. If there is no current hosted run for this branch, record that absence
instead of claiming remote CI passed.

### Steps

1. Confirm starting scope and worktree safety.
   - Run `git status --short --branch`.
   - Re-read `orchestrator/rounds/round-050/selection.md`,
     `orchestrator/roadmaps/2026-05-09-00-external-package-extraction/rev-001/verification.md`,
     `orchestrator/project-contract.md`, and `orchestrator/state.json`.
   - Note pre-existing dirty controller files, especially
     `orchestrator/state.json`, and do not edit or revert them.

2. Build the prior-round evidence inventory before drafting prose.
   - Read the `implementation-notes.md`, `review.md`, and `merge.md` files for
     rounds 036 through 049 listed above.
   - Extract, by package, the exact evidence each round already approved:
     package identity and metadata, descriptor layout, dependency ownership,
     local package wiring, validation commands, CI configuration, boundary
     tests, README/Haddock docs, consumer example, changelog/release notes, and
     moifold consumer validation.
   - Do not use an approved prior round as proof that the current tree still
     passes; current validation commands still need to run or be explicitly
     marked not run.

3. Inspect current package artifacts and descriptor truth.
   - Confirm the root project lists the root package and the three standalone
     package candidates.
   - Confirm each package descriptor records the current package name, version
     `0.1.0.0`, synopsis, license, author, maintainer, category, source
     repository, exposed modules, and dependency set.
   - Confirm moifold consumes the standalone package names and does not still
     depend on `moifold:agent-workflow-*` internal sublibraries.
   - Use these scans:

```sh
rg -n "^packages:|with-compiler|agent-workflow-(core|codex|github)|moifold:agent-workflow|library agent-workflow" cabal.project moifold.cabal agent-workflow-core/agent-workflow-core.cabal agent-workflow-codex/agent-workflow-codex.cabal agent-workflow-github/agent-workflow-github.cabal examples/workflow-package-consumer/cabal.project examples/workflow-package-consumer/workflow-package-consumer.cabal

rg -n "^(name|version|synopsis|description|license|author|maintainer|category):|source-repository|location:|exposed-modules:|build-depends:" agent-workflow-core/agent-workflow-core.cabal agent-workflow-codex/agent-workflow-codex.cabal agent-workflow-github/agent-workflow-github.cabal
```

4. Inspect current package-boundary and compatibility evidence.
   - Confirm `test/Main.hs` still contains the package wiring and recursive
     boundary assertions for all three packages.
   - Confirm package source trees do not import moifold lifecycle, runtime,
     healthcheck, repair, compatibility-file, or wrong adapter ownership.
   - Confirm compatibility facades remain available and are documented as
     compatibility-only where applicable, not removed or deprecated by this
     bundle.
   - Use these scans and record whether negative scans return no matches:

```sh
rg -n "workflowMoifoldCabalConsumesStandaloneWorkflowPackages|workflowCabalProjectListsStandaloneWorkflowPackages|workflowCoreStandalonePackageKeepsPackageBoundary|workflowCodexStandalonePackageKeepsPackageBoundary|workflowGithubStandalonePackageKeepsPackageBoundary|workflowMoifoldCabalLibraryDoesNotReexportAdapters" test/Main.hs

rg -n "^import (CodexWatcher\\.(Core|Domain|Effects|EventLog|Observation|StateMachine|Runtime|GhGit|Daemon|DaemonLoop|ChildDaemon|Healthcheck|EventLogRepair|RunnerGuard|WatcherRuntimeStatus|Supervisor)|Data\\.Aeson)" agent-workflow-core/src

rg -n "^import CodexWatcher\\.(AppServerClient|ActionExecutor|ChildDaemon|Daemon|DaemonLoop|Domain|Effects|EventLog|EventLogRepair|GhGit|Healthcheck|Runtime|StateMachine|Workflow\\.GitHub|Workflow\\.Moifold|Workflow\\.Types)" agent-workflow-codex/src

rg -n "^import CodexWatcher\\.(AppServer|AppServerClient|AppServerProtocol|ChildDaemon|Cli|Core|Daemon|DaemonLoop|Domain|EffectInterpreter|Effects|EventLog|EventLogRepair|GhGit|Healthcheck|Json|Logging|Observation|Runtime|StateMachine|Supervisor|Turn|TurnOutput|Watcher|Workflow\\.Agent|Workflow\\.Daemon|Workflow\\.EventLog|Workflow\\.Execution|Workflow\\.Moifold|Workflow\\.Observation|Workflow\\.Permission|Workflow\\.Transaction|Workflow\\.Types)" agent-workflow-github/src

rg -n "^module CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.(EventLog|Execution|Permission|Types))|import CodexWatcher\\.Workflow\\.(Agent\\.Codex\\.(Client|Transport)|Agent\\.Ids|GitHub\\.Ids|EventLog\\.Core|Execution\\.Core|Permission\\.Core|Spec)" src/CodexWatcher/AppServerClient.hs src/CodexWatcher/Core/Ids.hs src/CodexWatcher/Workflow/EventLog.hs src/CodexWatcher/Workflow/Execution.hs src/CodexWatcher/Workflow/Permission.hs src/CodexWatcher/Workflow/Types.hs
```

5. Refresh package validation evidence without publication.
   - Run:

```sh
scripts/validate-workflow-packages.sh
```

   - Record the `cabal check` coverage, local source-distribution paths under
     `dist-newstyle/sdist/`, descriptor-in-archive checks, and the script's
     final no-upload/no-publication statement.
   - Do not stage, commit, upload, or otherwise treat `dist-newstyle/` outputs
     as release artifacts.

6. Refresh build, test, docs, and consumer-example evidence.
   - Run:

```sh
cabal build all
cabal test watcher-core-test
cabal haddock agent-workflow-core agent-workflow-codex agent-workflow-github --haddock-all
(cd examples/workflow-package-consumer && cabal build all)
(cd examples/workflow-package-consumer && cabal run workflow-package-consumer)
```

   - If Haddock still reports missing per-export documentation while the
     command exits successfully, record that as a documentation blocker or
     follow-up note rather than rewriting source docs in this round.
   - Summarize the consumer example output by package: core planning,
     Codex request construction, and GitHub command specs.

7. Inspect CI status and CI configuration truthfully.
   - Inspect `.github/workflows/ci.yml` for the supported matrix and required
     commands:

```sh
rg -n "strategy:|matrix:|ghc-version|cabal-version|ripgrep|cabal build all|cabal test watcher-core-test|validate-workflow-packages" .github/workflows/ci.yml
```

   - If `gh` is authenticated and remote workflow data is available, capture
     hosted CI status for the current branch without triggering a workflow:

```sh
gh run list --workflow=CI --branch "$(git branch --show-current)" --limit 5
```

   - If there is no hosted run for the branch or the command cannot retrieve
     CI state, record that explicitly as "hosted CI not observed in this
     bundle" while still recording local CI-config inspection and local command
     results. Do not claim remote CI passed unless it was actually observed.

8. Draft `docs/agentic-workflow-framework/release-candidate-bundle.md`.
   - Use a top-level status such as "release-candidate evidence bundle" and
     state that it is not a publication decision, upload approval, final
     go/no-go, or hold decision.
   - Include an evidence-source section that names the current docs, package
     descriptors, CI workflow, validation script, consumer example, and prior
     round artifacts inspected.
   - Add one package section each for `agent-workflow-core`,
     `agent-workflow-codex`, and `agent-workflow-github`.
   - For each package, include subsections or a table covering:
     package artifact and descriptor evidence, package checks and sdist
     evidence, docs/Haddock evidence, changelog/release-note evidence, CI
     coverage/status, compatibility/deprecation notes, moifold consumer
     validation evidence, and remaining blockers or follow-ups.
   - Add a cross-package section for shared moifold-owned policy that remains
     outside reusable package promises: concrete event schemas, golden logs,
     compatibility files, prompt policy, runtime ownership, healthcheck,
     repair, lifecycle decisions, command execution, and final release
     approval.
   - Add a final "Remaining Blockers For The Publication Gate" section that
     feeds the later `direction-016-explicit-publication-gate` without making
     the decision. Include any stale or unavailable evidence, such as absent
     hosted CI, as a blocker or reviewer note.

9. If adding the docs index link, keep it narrow.
   - Add one bullet for
     `docs/agentic-workflow-framework/release-candidate-bundle.md` in
     `docs/agentic-workflow-framework/README.md`.
   - Do not alter package READMEs, changelog, release notes, package
     descriptors, CI, source, examples, tests, compatibility facades, or
     roadmap files unless a specific evidence mismatch from the prior steps
     requires a narrow correction.

10. Run overclaim and no-upload scans, then manually classify every match.
    - Use:

```sh
rg -n "cabal[[:space:]]+upload|stack[[:space:]]+upload|hackage-upload|curl[[:space:]].*hackage|gh release|git tag|release announcement|go/no-go|final decision|approved publication|publication approved|uploaded|published|ready to upload|release-ready|hold decision|package publication decision" docs/agentic-workflow-framework/release-candidate-bundle.md docs/agentic-workflow-framework/README.md scripts/validate-workflow-packages.sh .github/workflows/ci.yml

rg -n "WatcherEvent|event JSON `type`|schema version|golden|healthcheck|repair|prompt policy|runtime ownership|compatibility file|compatibility facade|app-server startup|issue/PR lifecycle|command execution" docs/agentic-workflow-framework/release-candidate-bundle.md
```

    - Matches are acceptable only when they are explicit non-goals,
      moifold-owned policy notes, or future-gate blockers. Revise wording if a
      match could be read as upload approval, final decision, public stability,
      facade removal, or moifold policy migration.

11. Finish with scope and hygiene checks.
    - Run:

```sh
git diff --check
git diff --name-only | rg -v '^(docs/agentic-workflow-framework/(README|release-candidate-bundle)\\.md|orchestrator/rounds/round-050/(selection|plan|implementation-notes)\\.md|orchestrator/state\\.json)$' || true
```

    - If anything outside the planned documentation and round-artifact files
      appears, either revert the implementer's own accidental change or record
      the concrete evidence issue that required the broader edit.
    - Do not stage, commit, push, upload packages, tag a release, trigger
      GitHub Actions, or edit `orchestrator/state.json`.

### Verification

Required current validation commands:

```sh
scripts/validate-workflow-packages.sh
cabal build all
cabal test watcher-core-test
cabal haddock agent-workflow-core agent-workflow-codex agent-workflow-github --haddock-all
(cd examples/workflow-package-consumer && cabal build all)
(cd examples/workflow-package-consumer && cabal run workflow-package-consumer)
git diff --check
```

If any files are staged later by the merge workflow, also run:

```sh
git diff --cached --check
```

Required evidence scans:

```sh
rg -n "^packages:|with-compiler|agent-workflow-(core|codex|github)|moifold:agent-workflow|library agent-workflow" cabal.project moifold.cabal agent-workflow-core/agent-workflow-core.cabal agent-workflow-codex/agent-workflow-codex.cabal agent-workflow-github/agent-workflow-github.cabal examples/workflow-package-consumer/cabal.project examples/workflow-package-consumer/workflow-package-consumer.cabal

rg -n "^(name|version|synopsis|description|license|author|maintainer|category):|source-repository|location:|exposed-modules:|build-depends:" agent-workflow-core/agent-workflow-core.cabal agent-workflow-codex/agent-workflow-codex.cabal agent-workflow-github/agent-workflow-github.cabal

rg -n "strategy:|matrix:|ghc-version|cabal-version|ripgrep|cabal build all|cabal test watcher-core-test|validate-workflow-packages" .github/workflows/ci.yml

rg -n "cabal[[:space:]]+upload|stack[[:space:]]+upload|hackage-upload|curl[[:space:]].*hackage|gh release|git tag|release announcement|go/no-go|final decision|approved publication|publication approved|uploaded|published|ready to upload|release-ready|hold decision|package publication decision" docs/agentic-workflow-framework/release-candidate-bundle.md docs/agentic-workflow-framework/README.md scripts/validate-workflow-packages.sh .github/workflows/ci.yml

git diff --name-only | rg -v '^(docs/agentic-workflow-framework/(README|release-candidate-bundle)\\.md|orchestrator/rounds/round-050/(selection|plan|implementation-notes)\\.md|orchestrator/state\\.json)$' || true
```

The reviewer should be able to use the bundle as a final release-gate input,
but the round is only successful if the bundle itself refuses to make the final
publication or hold decision.

### Worker Fan-Out

Worker fan-out is not used. This round is a single evidence-bundle assembly
task whose correctness depends on consistent wording across package artifacts,
validation evidence, docs, CI status, compatibility policy, and remaining
blockers. Splitting by package would add integration risk and would not create
independent write ownership because all packages converge in one release-gate
document.
