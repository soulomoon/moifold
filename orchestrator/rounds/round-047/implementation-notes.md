### Changes Made

- `examples/workflow-package-consumer/cabal.project`: added an example-local
  Cabal project that lists only the example package plus the three local
  workflow package candidates; the root `cabal.project` was not changed.
- `examples/workflow-package-consumer/workflow-package-consumer.cabal`: added a
  single executable package depending on `base`, `text`, `bytestring`, `aeson`,
  and the three workflow package candidates with `>=0.1 && <0.2` bounds; it has
  no `moifold` dependency.
- `examples/workflow-package-consumer/app/Main.hs`: added a deterministic
  executable example covering all three packages through exposed
  package-facing imports: a tiny `WorkflowSpec` and `WorkflowM`/`advance`
  transition, Codex typed thread/turn request construction, and GitHub typed id
  plus pure command spec construction.
- `examples/workflow-package-consumer/README.md`: documented how to run the
  example and what product responsibilities it intentionally leaves outside the
  reusable packages.
- `docs/agentic-workflow-framework/package-consumer-guide.md`: added a focused
  consumer guide with preferred import families, local project wiring, and the
  product-owned boundary.
- `docs/agentic-workflow-framework/README.md`: linked the package consumer guide
  from the framework docs index.
- `agent-workflow-core/README.md`: linked the package consumer guide and
  buildable consumer example.
- `agent-workflow-codex/README.md`: linked the package consumer guide and
  buildable consumer example.
- `agent-workflow-github/README.md`: linked the package consumer guide and
  buildable consumer example.
- `orchestrator/rounds/round-047/implementation-notes.md`: recorded changed
  files and validation evidence for review.

### Tests

- `(cd examples/workflow-package-consumer && cabal build all)`: passed; built
  `agent-workflow-core`, `agent-workflow-codex`, `agent-workflow-github`, and
  `workflow-package-consumer` from the example-local project.
- `(cd examples/workflow-package-consumer && cabal run workflow-package-consumer)`:
  passed; output included the core planned event/effect labels, Codex request
  ids/methods/JSON, and GitHub `gh`/`git` command specs.
- `cabal build all`: passed; root project was up to date after the earlier root
  build.
- `cabal test watcher-core-test`: passed.
- `cabal haddock agent-workflow-core agent-workflow-codex agent-workflow-github --haddock-all`:
  passed; Haddock reported existing missing-documentation coverage warnings.
- `scripts/validate-workflow-packages.sh`: passed; `cabal check` and source
  distribution validation succeeded for all three workflow packages and the
  script reported no upload or package publication command was run.
- `git diff --check`: passed.
- `git diff --cached --check`: passed; no files were staged.
- `rg -n "^import CodexWatcher\\.(Workflow\\.Types|AppServerClient|Core\\.Ids|Domain\\.|Healthcheck|Runtime\\.|GhGit)" examples/workflow-package-consumer`:
  passed with no matches.
- `rg -n "upload|published|publication approved|release-ready|generic prompt runner|YAML workflow|healthcheck ownership|repair ownership|prompt policy ownership" examples/workflow-package-consumer docs/agentic-workflow-framework agent-workflow-core/README.md agent-workflow-codex/README.md agent-workflow-github/README.md`:
  returned only existing docs/README non-goal wording that denies upload,
  publication, prompt-runner, YAML-workflow, and ownership claims.

### Notes

The example uses `RepoName "soulomoon/moifold"` only as sample typed GitHub
identifier data for pure command-spec rendering. It does not import moifold
modules, depend on `moifold`, execute commands, start an app-server, or change
runtime, event, compatibility, CI, changelog, release-gate, package descriptor,
or root project files.
