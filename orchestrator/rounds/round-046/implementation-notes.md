### Changes Made
- `agent-workflow-core/README.md`: added package-facing thesis, architecture, guarantees, non-goals, and evidence links for the reusable workflow-kernel candidate.
- `agent-workflow-codex/README.md`: added package-facing thesis, architecture, guarantees, non-goals, and evidence links for the Codex app-server adapter candidate.
- `agent-workflow-github/README.md`: added package-facing thesis, architecture, guarantees, non-goals, and evidence links for the GitHub ids/parser/command-spec candidate.
- `agent-workflow-core/agent-workflow-core.cabal`: added `extra-doc-files: README.md`; `cabal check` accepted the descriptor.
- `agent-workflow-codex/agent-workflow-codex.cabal`: added `extra-doc-files: README.md`; `cabal check` accepted the descriptor.
- `agent-workflow-github/agent-workflow-github.cabal`: added `extra-doc-files: README.md`; `cabal check` accepted the descriptor.
- `agent-workflow-core/src/CodexWatcher/Workflow/*.hs` and exposed submodules under `Indexed`, `EventLog`, `Execution`, `Permission`, `Transaction`, and `Daemon`: added concise module-level Haddock headers describing generic kernel ownership and concrete moifold non-ownership.
- `agent-workflow-codex/src/CodexWatcher/AppServerProtocol.hs` and exposed modules under `Workflow/Agent` and `Workflow/Observation`: added concise module-level Haddock headers describing protocol, typed agent, transport, interpreter, and observation boundaries without prompt or lifecycle policy claims.
- `agent-workflow-github/src/CodexWatcher/Workflow/GitHub/*.hs`: added concise module-level Haddock headers describing typed ids, pure parsers/classifiers, and pure command specs without command execution or lifecycle ownership.
- `orchestrator/rounds/round-046/implementation-notes.md`: recorded the round changes, documentation claims, descriptor decision, and validation results.

### Tests
- `cabal haddock agent-workflow-core agent-workflow-codex agent-workflow-github`: passed; Haddock generated docs for all three packages. Haddock still reports missing per-export documentation because this round only added module headers.
- `scripts/validate-workflow-packages.sh`: passed; `cabal check` accepted all three descriptors, source distributions were generated, and the script reported that no upload or package-publication command was run.
- `cabal build all`: passed.
- `cabal test watcher-core-test`: passed. An initial run failed because a core module comment introduced forbidden boundary-scan tokens; the comments were tightened and the exact command was rerun successfully.
- Static module-list check: passed; each README module list matches the corresponding `exposed-modules` field.
- Static module-header check: passed; each exposed module in the three package source trees has module-level Haddock.
- Static overclaim scan: passed for publication/upload commands, `stable 1.0`, generic prompt runner claims, and package-owned healthcheck/repair/lifecycle wording.

### Notes
Docs claims stay within the implemented package surfaces. The READMEs describe these as local external-package candidates and avoid examples, consumer guides, changelog text, release notes, upload commands, public stability claims, compatibility facade removal, event/golden changes, and roadmap or state edits.

The only descriptor changes are `extra-doc-files: README.md`; package names, versions, dependencies, exposed modules, source layout, and source repository fields are unchanged.
