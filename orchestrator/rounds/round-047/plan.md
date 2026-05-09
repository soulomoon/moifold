### Goal

Add a small, buildable consumer example and focused guide for the three workflow
package candidates: `agent-workflow-core`, `agent-workflow-codex`, and
`agent-workflow-github`. The examples must use package-facing imports and
implemented APIs only, prove the packages are understandable outside moifold
product code, and preserve the public non-goals recorded in
`orchestrator/project-contract.md`.

### Approach

Use one sequential implementation pass. Do not use worker fan-out; the source,
guide, README links, and validation are small and tightly coupled.

Prefer a minimal example-local Cabal project over root-project wiring. The
current `watcher-core-test` boundary checks assert that root `cabal.project`
lists exactly `.` plus the three workflow packages, so adding an example package
to the root package set would require unrelated boundary-test churn. Instead,
add `examples/workflow-package-consumer/` with its own `cabal.project` that
references the three local package candidates and builds an executable consumer
example.

Keep the example deliberately package-facing:

- `agent-workflow-core`: define a tiny two-state workflow spec and demonstrate
  `WorkflowSpec`, `PlannedTransition`, `workflowPlanObservation`, and the pure
  `WorkflowM`/`advance` DSL path.
- `agent-workflow-codex`: construct typed thread/turn plans and deterministic
  app-server protocol requests through `CodexWatcher.Workflow.Agent.*`,
  `CodexWatcher.Workflow.Agent.Codex.Protocol`, and
  `CodexWatcher.AppServerProtocol`; do not start an app-server process or
  encode moifold prompt policy.
- `agent-workflow-github`: construct typed ids and pure `gh`/`git` command
  specs through `CodexWatcher.Workflow.GitHub.Ids` and
  `CodexWatcher.Workflow.GitHub.Command`; do not execute commands or describe
  PR/issue lifecycle policy.

The guide should be concise and source-backed: explain how to run the example,
which package owns each import family, and which responsibilities remain
moifold-owned. Avoid marketing, publication claims, changelog/release-note
content, YAML workflow engines, generic prompt runners, and package upload
language.

### Steps

1. Add `examples/workflow-package-consumer/cabal.project`.
   - List `.` plus `../../agent-workflow-core`,
     `../../agent-workflow-codex`, and `../../agent-workflow-github`.
   - Use the same compiler expectation as the repo root (`with-compiler:
     ghc-9.12.2`) unless local Cabal behavior requires omitting it.
   - Do not edit the root `cabal.project` unless implementation discovers a
     hard Cabal limitation; if that happens, also update the boundary test
     deliberately rather than weakening it.

2. Add `examples/workflow-package-consumer/workflow-package-consumer.cabal`.
   - Define one executable, `workflow-package-consumer`, with source under
     `app/Main.hs`.
   - Depend only on `base`, `text`, `bytestring` if needed for output,
     `aeson` if rendering protocol JSON, and the three workflow packages with
     the existing `>=0.1 && <0.2` bounds.
   - Do not depend on `moifold`.

3. Add `examples/workflow-package-consumer/app/Main.hs`.
   - Keep the executable self-contained and readable.
   - Include one short section per package candidate.
   - Print deterministic output that proves the examples executed, such as the
     core planned event/effect labels, Codex request method/id values or JSON,
     and GitHub command/argument specs.
   - Use only package-facing imports. Reject imports through moifold facades
     such as `CodexWatcher.Workflow.Types`, `CodexWatcher.AppServerClient`,
     `CodexWatcher.Core.Ids`, `CodexWatcher.Domain.*`,
     `CodexWatcher.Healthcheck`, `CodexWatcher.Runtime.*`, or
     `CodexWatcher.GhGit`.

4. Add `examples/workflow-package-consumer/README.md`.
   - State that this is a local consumer example for package candidates, not a
     publication or stability claim.
   - Show the exact run command:
     `(cd examples/workflow-package-consumer && cabal run workflow-package-consumer)`.
   - Summarize what each example demonstrates and what it intentionally does
     not do.

5. Add a focused guide at
   `docs/agentic-workflow-framework/package-consumer-guide.md`.
   - Link to the example package.
   - Give preferred import families for core, Codex, and GitHub consumers.
   - Record the consumer boundary: products provide concrete workflow state,
     event schemas, prompt policy, runtime/process ownership, filesystem
     writes, command execution, healthcheck, repair, compatibility files, and
     release decisions.

6. Update documentation indexes and package READMEs only enough to make the
   guide discoverable.
   - Add the guide link to `docs/agentic-workflow-framework/README.md`.
   - Add an evidence or examples link to `agent-workflow-core/README.md`,
     `agent-workflow-codex/README.md`, and `agent-workflow-github/README.md`.
   - Keep the wording aligned with existing README/Haddock non-goals.

7. Inspect descriptors and exposed modules after editing.
   - Confirm the example imports modules exposed by the three package
     descriptors.
   - Confirm package README module lists still match descriptor surfaces.
   - Confirm no docs imply package upload, final release readiness, moifold
     lifecycle migration, prompt-policy ownership, healthcheck ownership, or
     command execution ownership.

### Verification

Run these checks from the worktree root unless a command says otherwise:

```sh
(cd examples/workflow-package-consumer && cabal build all)
(cd examples/workflow-package-consumer && cabal run workflow-package-consumer)
cabal build all
cabal test watcher-core-test
cabal haddock agent-workflow-core agent-workflow-codex agent-workflow-github --haddock-all
scripts/validate-workflow-packages.sh
git diff --check
```

If files are staged during the round, also run:

```sh
git diff --cached --check
```

Use focused source and docs scans before review:

```sh
rg -n "^import CodexWatcher\\.(Workflow\\.Types|AppServerClient|Core\\.Ids|Domain\\.|Healthcheck|Runtime\\.|GhGit)" examples/workflow-package-consumer
rg -n "upload|published|publication approved|release-ready|generic prompt runner|YAML workflow|healthcheck ownership|repair ownership|prompt policy ownership" examples/workflow-package-consumer docs/agentic-workflow-framework agent-workflow-core/README.md agent-workflow-codex/README.md agent-workflow-github/README.md
```

The first scan must return no matches. The second scan may return existing
non-goal wording only when the surrounding text explicitly denies those claims.

Acceptance criteria:

- `examples/workflow-package-consumer` builds and runs through its own local
  Cabal project.
- The executable demonstrates all three package candidates through exposed,
  package-facing imports.
- The example package has no `moifold` dependency and no moifold facade imports.
- Consumer documentation is concise, discoverable from the framework docs and
  package READMEs, and source-backed by the buildable example.
- Root package validation, Haddock, `watcher-core-test`, and package validation
  still pass.
- No event schemas, golden fixtures, compatibility facades, runtime policy,
  CI scripts, package names, versions, changelog/release notes, release gates,
  or orchestrator state files are changed.

Risks:

- The core DSL example may require explicit type signatures because
  `WorkflowSpec` uses associated types. Keep it small and compile it before
  expanding the guide.
- The Codex protocol surface can be mistaken for app-server lifecycle policy.
  Show deterministic request construction only; do not start processes or
  discuss prompt scheduling.
- The GitHub command specs can be mistaken for command execution authority.
  Render command data only; do not shell out.
- Because the example project is intentionally outside the root `cabal.project`,
  root `cabal build all` does not cover it. The example-local build/run commands
  are mandatory verification for this round.
