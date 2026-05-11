### Goal

Move `src/CodexWatcher/Workflow/Execution.hs` from the combined
`CodexWatcher.Core.Ids` compatibility facade to the direct agent-id owner
module `CodexWatcher.Workflow.Agent.Ids` for `RequestId`.

This round preserves request-id propagation through workflow effect
compilation, compiled plan output, dry-run conversion, action partitioning, and
workflow execution behavior. It is import convergence only: it does not change
constructors, parsers, renderers, command output, dry-run output, action order,
package descriptors, public facade exposure, deprecation policy, or removal
status.

### Approach

Make the smallest source change in the selected production module:

- Replace `import CodexWatcher.Core.Ids (RequestId)` with
  `import CodexWatcher.Workflow.Agent.Ids (RequestId)` in
  `src/CodexWatcher/Workflow/Execution.hs`.
- Leave all workflow execution data types and functions unchanged, especially
  `WorkflowCompiledEffectPlan`, `compileWorkflowEffectPlanWithMetadata`,
  `compileWorkflowEffect`, `compileWorkflowEffectWithMetadata`,
  `workflowCompiledEffectPlanLegacy`, dry-run helpers, action partitioning, and
  checked action execution.
- Do not edit `moifold.cabal`, standalone package descriptors, exposed-module
  lists, public compatibility facades, tests, fixtures, docs, roadmap files, or
  controller state.
- Treat `CodexWatcher.Core.Ids` as still public and supported. A direct import
  in this module is not deprecation, Cabal exposure cleanup, facade removal, or
  approval to migrate combined users.

No package descriptor change is expected because
`CodexWatcher.Workflow.Agent.Ids` is already the direct owner module visible to
the main library. If `cabal build all` proves a descriptor change is required,
limit it to the minimal build reachability fix and record the build failure
that justified it.

No worker fan-out is used. The implementation has one source file, one import
replacement, and one coupled verification path; parallel workers would add
coordination without reducing risk.

### Steps

1. Re-read `orchestrator/rounds/round-099/selection.md`,
   `orchestrator/project-contract.md`, and the active verification bundle for
   `2026-05-11-00-highest-value-cleanup/rev-001` before editing.
2. Open `src/CodexWatcher/Workflow/Execution.hs` and replace the single
   `CodexWatcher.Core.Ids` import with
   `CodexWatcher.Workflow.Agent.Ids (RequestId)`.
3. Confirm the module's id usage remains agent-id-only and currently limited
   to the `RequestId` type in compiled workflow plans and compile helpers.
4. Confirm no GitHub id tokens are present in the module and no additional
   agent id exports are introduced.
5. Do not alter request-id threading through
   `compileWorkflowEffectPlanWithMetadata`, `compileWorkflowEffect`,
   `compileWorkflowEffectWithMetadata`, or
   `workflowCompiledEffectPlanLegacy`; the final request id must continue to
   flow from `config.effectRuntimeNextRequestId` through `mapAccumL` into
   `workflowCompiledNextRequestId` and `compiledNextRequestId`.
6. Inspect the final diff. The intended implementation diff is only the import
   replacement in `src/CodexWatcher/Workflow/Execution.hs`, plus round-local
   orchestrator artifacts and controller state if the surrounding orchestrator
   flow writes them. Package descriptors must have no diff unless a build
   failure proves a minimal descriptor fix is required.

### Verification

Run focused import scans from the repository root:

```sh
rg -n '^import[[:space:]]+(qualified[[:space:]]+)?CodexWatcher\.Core\.Ids([[:space:]]|$|\()' src/CodexWatcher/Workflow/Execution.hs
```

Expected result: no matches. This proves the selected module no longer imports
the combined `Core.Ids` facade.

```sh
rg -n '^import[[:space:]]+CodexWatcher\.Workflow\.Agent\.Ids[[:space:]]+\(RequestId\)' src/CodexWatcher/Workflow/Execution.hs
```

Expected result: exactly one direct owner import in
`src/CodexWatcher/Workflow/Execution.hs`.

Run token scans proving the selected module is an agent-id-only user and that
the used agent-id symbol is still only `RequestId`:

```sh
rg -n '\b(RequestId|ThreadId|TurnId|nextRequestId)\b' src/CodexWatcher/Workflow/Execution.hs
```

Expected result: matches are limited to `RequestId`; there are no `ThreadId`,
`TurnId`, or `nextRequestId` matches.

```sh
rg -n '\b(RepoName|IssueNumber|PrNumber|BranchName|ReviewThreadId|CommitSha)\b' src/CodexWatcher/Workflow/Execution.hs
```

Expected result: no matches. This proves the module does not need the GitHub-id
half of `CodexWatcher.Core.Ids`.

Run behavior and baseline checks:

```sh
cabal test watcher-core-test
cabal build all
```

Expected result: both pass, proving the direct owner import preserves the
watcher-core workflow behavior suite and the full package build.

Run diff and hygiene checks:

```sh
git diff --check
git diff --name-only
git diff -- src/CodexWatcher/Workflow/Execution.hs
git diff -- moifold.cabal agent-workflow-core/agent-workflow-core.cabal agent-workflow-codex/agent-workflow-codex.cabal agent-workflow-github/agent-workflow-github.cabal cabal.project
```

Expected result: diff hygiene passes; `Execution.hs` shows only the import
replacement; package descriptors and `cabal.project` have no diff. The full
changed-path list should be limited to
`src/CodexWatcher/Workflow/Execution.hs`, round-099 orchestrator artifacts, and
`orchestrator/state.json` if controller/role state was written by the
orchestrator flow.

If staging occurs later in the orchestrator flow, also run:

```sh
git diff --cached --check
```
