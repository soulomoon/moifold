### Checks Run
- Command: `git diff --cached --name-only`
  Result: pass. Staged payload contains package README links, framework guide link, the new `docs/agentic-workflow-framework/package-consumer-guide.md`, the standalone `examples/workflow-package-consumer` project, and round selection/plan/implementation notes. The staged payload excludes `orchestrator/state.json` and root `cabal.project`.

- Command: `git diff --cached --stat`
  Result: pass. Staged payload is 12 files, 725 insertions: README/doc links, one new consumer guide, one new example project, and round artifacts.

- Command: `(cd examples/workflow-package-consumer && cabal build all)`
  Result: pass. Cabal reported `Up to date` for the standalone example-local project.

- Command: `(cd examples/workflow-package-consumer && cabal run workflow-package-consumer)`
  Result: pass. Output included the `agent-workflow-core` planned event/effect labels, `agent-workflow-codex` request ids and JSON-RPC methods (`thread/start`, `turn/start`, `thread/read`), and `agent-workflow-github` pure `gh`/`git` command specs including `git push --dry-run`.

- Command: `cabal build all`
  Result: pass. Rebuilt `agent-workflow-core`, `agent-workflow-github`, `agent-workflow-codex`, `moifold` library, and `moifold` executable successfully.

- Command: `cabal test watcher-core-test`
  Result: pass. Test suite `watcher-core-test` passed: `1 of 1 test suites (1 of 1 test cases) passed`.

- Command: `cabal haddock agent-workflow-core agent-workflow-codex agent-workflow-github --haddock-all`
  Result: pass. Haddock completed for all three packages and wrote docs under `dist-newstyle`; output contained existing missing-documentation and link-destination warnings.

- Command: `scripts/validate-workflow-packages.sh`
  Result: pass. `cabal check` reported no errors or warnings for all three workflow packages, source distributions were generated and validated, and the script reported `No upload or package publication command was run.`

- Command: `git diff --check`
  Result: pass. No whitespace errors reported.

- Command: `git diff --cached --check`
  Result: pass. No staged whitespace errors reported.

- Command: `rg -n "^import CodexWatcher\\.(Workflow\\.Types|AppServerClient|Core\\.Ids|Domain\\.|Healthcheck|Runtime\\.|GhGit)" examples/workflow-package-consumer`
  Result: pass. No matches.

- Command: `rg -n "upload|published|publication approved|release-ready|generic prompt runner|YAML workflow|healthcheck ownership|repair ownership|prompt policy ownership" examples/workflow-package-consumer docs/agentic-workflow-framework agent-workflow-core/README.md agent-workflow-codex/README.md agent-workflow-github/README.md`
  Result: pass. Matches are non-failures: package README and validation docs explicitly deny upload/publication claims; framework docs retain existing generic prompt runner non-goal wording; release metadata and compatibility docs describe release gates; `agent-turn-contract.md` has unrelated review-findings publication wording. No new example or guide text claims upload, publication approval, release readiness, YAML workflow ownership, generic prompt-runner ownership, healthcheck ownership, repair ownership, or prompt-policy ownership.

- Command: `git diff --cached --name-only -- agent-workflow-core/agent-workflow-core.cabal agent-workflow-codex/agent-workflow-codex.cabal agent-workflow-github/agent-workflow-github.cabal moifold.cabal cabal.project CHANGELOG.md docs/agentic-workflow-framework/release-notes.md`
  Result: pass. No existing package descriptor, root `cabal.project`, changelog, release-note, or release metadata files are staged.

- Command: `rg -n "moifold|CodexWatcher\\." examples/workflow-package-consumer`
  Result: pass. Imports are package-facing modules from `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`; `moifold` appears only in the README non-dependency text and as sample `RepoName "soulomoon/moifold"` data for pure command rendering.

### Plan Compliance
- Add `examples/workflow-package-consumer/cabal.project`: met. The new example-local project lists `.` plus `../../agent-workflow-core`, `../../agent-workflow-codex`, and `../../agent-workflow-github`, with `with-compiler: ghc-9.12.2`. Root `cabal.project` is not staged.
- Add `examples/workflow-package-consumer/workflow-package-consumer.cabal`: met. The executable depends on `base`, `text`, `bytestring`, `aeson`, and the three workflow packages with `>=0.1 && <0.2` bounds; it has no `moifold` dependency.
- Add `examples/workflow-package-consumer/app/Main.hs`: met. The executable demonstrates a small `WorkflowSpec`, `workflowPlanObservation`, `WorkflowM`/`advance`, typed Codex request construction, typed GitHub ids, and pure command specs through package-facing imports. Forbidden moifold facade import scan returned no matches.
- Add `examples/workflow-package-consumer/README.md`: met. The README gives the exact run command, states the example is local and not a publication or stability claim, and lists product-owned responsibilities.
- Add `docs/agentic-workflow-framework/package-consumer-guide.md`: met. The guide links to the example, lists preferred import families, and states that concrete products own state, event schemas, prompt policy, runtime ownership, filesystem writes, command execution, healthcheck, repair, compatibility files, and release decisions.
- Update documentation indexes and package READMEs only enough for discoverability: met. The framework docs index and the three package READMEs add consumer guide/example links only.
- Inspect descriptors and exposed modules: met. The example builds and runs against exposed package modules. Existing package descriptors, root project, changelog, release-note, release metadata, and publication files are not staged.
- Preserve roadmap and project-contract boundaries: met. No event schemas, golden fixtures, compatibility facades, runtime policy, CI scripts, package names, versions, existing package descriptors, changelogs, release notes, release gates, root project wiring, or controller state files are staged.

### Decision
**APPROVED**

### Evidence
The integrated round result matches `item-047-examples-and-consumer-guides`. The standalone example project builds and runs independently from the root project, depends only on the three local workflow package candidates plus ordinary library dependencies, and does not depend on `moifold`. The executable exercises the package-facing core workflow DSL/spec APIs, Codex app-server request value constructors, and GitHub typed ids/command specs without starting processes, executing GitHub commands, moving prompt policy, or claiming lifecycle ownership.

Manual staged-scope inspection confirms the staged payload excludes `orchestrator/state.json` and root `cabal.project`; `orchestrator/state.json` remains only an unstaged live-controller dirty file. The only Cabal descriptor added is the expected example-local descriptor. Existing package descriptors, changelog/release-note files, and release/publication metadata are untouched. Documentation wording keeps package ownership narrow and treats upload, publication, release readiness, healthcheck, repair, runtime, prompt policy, event schemas, and compatibility files as non-goals or product-owned responsibilities.
