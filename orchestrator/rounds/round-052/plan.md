### Goal

Produce a source-backed inventory for the selected Haskell compatibility import
facades:

- `CodexWatcher.AppServerClient`
- `CodexWatcher.Core.Ids`
- `CodexWatcher.Workflow.Types`
- `CodexWatcher.Workflow.EventLog`
- `CodexWatcher.Workflow.Execution`
- `CodexWatcher.Workflow.Permission`

The round should leave a reviewable evidence report, not production changes.
It should identify each facade's current exposed-module status, repo-local
users, preferred replacement imports, existing test coverage, and unresolved
ownership or coverage unknowns.

### Approach

Keep the work sequential and evidence-only. Write the inventory as a
round-local artifact, for example
`orchestrator/rounds/round-052/import-facade-inventory.md`, so it is
reviewable without changing production source, roadmap state, policy docs, or
runtime compatibility files.

Use recursive text scans plus direct module/Cabal inspection. Treat
`orchestrator/project-contract.md` as the shared compatibility contract:
facades stay available unless a later removal round proves safety. This round
must not add deprecation pragmas, remove or rename modules, rewrite imports,
inventory runtime compatibility files, or author policy wording.

### Steps

1. Re-read `orchestrator/rounds/round-052/selection.md`,
   `orchestrator/project-contract.md`, and
   `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-001/verification.md`
   before editing the report.
2. Inspect each selected facade module and record whether it defines concrete
   product-facing types/functions, reexports package-candidate modules, or
   bridges generic package APIs to moifold-owned lifecycle behavior.
3. Inspect `moifold.cabal`, `agent-workflow-core/agent-workflow-core.cabal`,
   `agent-workflow-codex/agent-workflow-codex.cabal`, and
   `agent-workflow-github/agent-workflow-github.cabal` for exposed-module and
   replacement-module status.
4. Run recursive import/reference scans across source, tests, app code,
   examples, Cabal descriptors, README files, package docs, and public package
   docs. Include at least these scan shapes in the report evidence:
   - `rg -n "import CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.(Types|EventLog|Execution|Permission))" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
   - `rg -n "CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.(Types|EventLog|Execution|Permission))" README.md docs agent-workflow-core agent-workflow-codex agent-workflow-github examples *.cabal */*.cabal`
   - `rg -n "exposed-modules|other-modules|CodexWatcher\\.AppServerClient|CodexWatcher\\.Core\\.Ids|CodexWatcher\\.Workflow\\.(Types|EventLog|Execution|Permission)" *.cabal */*.cabal`
5. For each facade, group current users by location: production source, tests,
   app/CLI entrypoints, examples, package descriptors, and docs. Distinguish
   true imports from prose references and test fixture strings.
6. For each facade, name the preferred replacement path where current code or
   docs already establish one. Examples to verify from source/docs include
   `CodexWatcher.Workflow.Agent.Codex.Client`,
   `CodexWatcher.Workflow.Agent.Codex.Transport`,
   `CodexWatcher.Workflow.Agent.Ids`,
   `CodexWatcher.Workflow.GitHub.Ids`,
   `CodexWatcher.Workflow.EventLog.Core`,
   `CodexWatcher.Workflow.EventLog.File.Core`,
   `CodexWatcher.Workflow.EventLog.Commit.Core`,
   `CodexWatcher.Workflow.Execution.Core`, and
   `CodexWatcher.Workflow.Permission.Core`.
7. Identify protecting tests by inspecting the relevant assertions in
   `test/Main.hs` and any focused specs that import the selected facades. The
   report should name the test or assertion purpose, not just the file.
8. Record unknowns explicitly. Unknowns may include ambiguous ownership,
   missing package-boundary assertions, docs that name a facade without a
   replacement, or tests that prove availability but not migration readiness.
9. Keep the report descriptive. Do not classify any facade as approved for
   deprecation or removal; later readiness and policy rounds own those
   decisions.

### Verification

- Run the three scan commands from Step 4 and include their summarized results
  or exact output excerpts in the inventory report.
- Run `cabal test watcher-core-test` to preserve the existing package-boundary
  and compatibility-facade assertions while adding the report.
- Run `scripts/validate-workflow-packages.sh` because the inventory cites
  package descriptors and public package docs.
- Run `git diff --check`.
- If staging happens later, run `git diff --cached --check`.
- The final diff for this round should contain only
  `orchestrator/rounds/round-052/import-facade-inventory.md` and any necessary
  round-local evidence notes; it should not change production code, roadmap
  files, `orchestrator/state.json`, implementation notes, reviews, or merge
  notes.
