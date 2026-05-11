### Goal

Produce artifact-only readiness evidence for the remaining
`CodexWatcher.Core.Ids` imports after rounds 098 through 102. The round should
prove the five previously accepted safe single-domain candidates are gone,
classify the current remaining users by file and blocker type, and recommend
whether direction 011 still has any safe next single-domain implementation
slice.

### Approach

This is a sequential evidence round. Do not edit source, tests, package
descriptors, roadmap files, controller state, public compatibility facades,
fixtures, docs, or prior artifacts. Write one new evidence artifact at
`orchestrator/rounds/round-103/core-ids-remaining-blocker-readiness.md`.

Use the active roadmap lineage from `orchestrator/state.json` and
`orchestrator/rounds/round-103/selection.md`, and reference
`orchestrator/project-contract.md` for the standing compatibility constraints:
`CodexWatcher.Core.Ids` remains available and exposed, and import convergence
is not deprecation, Cabal exposure removal, facade removal, release approval,
milestone completion, or terminal completion.

The evidence must be generated from current scans over the live worktree, not
copied from round-097. Rounds 098 through 102 are inputs only to confirm that
the five safe candidates named by round-097 were completed and approved.

No worker fan-out is used. The selected work produces a single round-local
artifact, has no non-overlapping implementation ownership boundaries, and
`max_parallel_rounds` is 1.

### Steps

1. Re-read coordination inputs:
   - `orchestrator/state.json`
   - `orchestrator/rounds/round-103/selection.md`
   - `orchestrator/project-contract.md`
   - `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`
   - `orchestrator/rounds/round-097/facade-import-scan-refresh.md`
   - `orchestrator/rounds/round-098/implementation-notes.md`
   - `orchestrator/rounds/round-099/implementation-notes.md`
   - `orchestrator/rounds/round-100/implementation-notes.md`
   - `orchestrator/rounds/round-101/implementation-notes.md`
   - `orchestrator/rounds/round-102/implementation-notes.md`
   - the matching `review.md` files for rounds 098 through 102

2. Record starting scope with:
   ```sh
   git status --short
   git diff --name-status
   git ls-files --others --exclude-standard orchestrator/rounds/round-103
   ```
   Treat pre-existing `orchestrator/state.json` changes as controller-owned and
   leave them untouched.

3. Run the current exact `CodexWatcher.Core.Ids` import scan:
   ```sh
   rg -n '^import[[:space:]]+(qualified[[:space:]]+)?CodexWatcher\.Core\.Ids([[:space:]]|$|\()' \
     src app test agent-workflow-core agent-workflow-codex agent-workflow-github
   ```
   In the artifact, list every matching file grouped by top-level area
   (`src`, `app`, `test`, standalone package candidates) and record exact
   counts. The expected current shape from selection is 39 total imports, with
   no `app` or standalone package-candidate imports, but the artifact must
   report the live scan result.

4. Confirm the five round-097 safe candidates completed by rounds 098 through
   102 no longer import the facade:
   ```sh
   rg -n '^import[[:space:]]+(qualified[[:space:]]+)?CodexWatcher\.Core\.Ids([[:space:]]|$|\()' \
     test/BoundaryPolicySpec.hs \
     src/CodexWatcher/Workflow/Execution.hs \
     src/CodexWatcher/Core/State.hs \
     app/Main.hs \
     test/WorkflowDocsMigrationSpec.hs
   ```
   The expected result is no matches. Also record the direct-owner imports now
   present in those files:
   ```sh
   rg -n '^import[[:space:]]+CodexWatcher\.Workflow\.(GitHub|Agent)\.Ids([[:space:]]|$|\()' \
     test/BoundaryPolicySpec.hs \
     src/CodexWatcher/Workflow/Execution.hs \
     src/CodexWatcher/Core/State.hs \
     app/Main.hs \
     test/WorkflowDocsMigrationSpec.hs
   ```

5. Run a token-domain scan for each remaining importing file to classify why it
   is blocked:
   ```sh
   rg -n '\b(RepoName|IssueNumber|PrNumber|BranchName|ReviewThreadId|CommitSha|RequestId|ThreadId|TurnId|nextRequestId|unRepoName|unIssueNumber|unPrNumber|unBranchName|unReviewThreadId|unCommitSha|unRequestId|unThreadId|unTurnId)\b' \
     <remaining-files-from-step-3>
   ```
   Classify every remaining importer as one of:
   - `combined agent/github ids`: both agent-domain and GitHub-domain id tokens
     are used in the same file, so a later implementation must split imports
     and verify the file's behavior surface.
   - `parser/renderer or command-output blocker`: id parsing, rendering,
     CLI parsing, command text, dry-run output, or user-visible formatting
     requires focused evidence before import movement.
   - `runtime-config or compatibility-state blocker`: runtime owner/config,
     state compatibility, daemon/restart/repair, or persisted compatibility
     behavior requires focused evidence.
   - `event-log or golden/replay blocker`: event schema, replay, golden log, or
     old-log behavior requires focused evidence.
   - `prompt/turn/classifier or loop-policy blocker`: agent turn observation,
     prompt/structured output, lifecycle loop, or domain policy behavior
     requires focused evidence.
   - `test-policy evidence blocker`: test modules that intentionally keep the
     facade in coverage until a later verified policy slice moves them.

6. Check package and public-facade exposure remains unchanged:
   ```sh
   rg -n 'CodexWatcher\.Core\.Ids|CodexWatcher\.Workflow\.(Agent|GitHub)\.Ids|agent-workflow-(codex|github)' \
     moifold.cabal agent-workflow-codex/agent-workflow-codex.cabal \
     agent-workflow-github/agent-workflow-github.cabal cabal.project
   git diff -- moifold.cabal agent-workflow-core/agent-workflow-core.cabal \
     agent-workflow-codex/agent-workflow-codex.cabal \
     agent-workflow-github/agent-workflow-github.cabal cabal.project
   ```
   The artifact should state that `CodexWatcher.Core.Ids` remains exposed and
   available, and that no descriptor change was made in this round.

7. Write `orchestrator/rounds/round-103/core-ids-remaining-blocker-readiness.md`
   with these sections:
   - `Scope`: roadmap lineage, round id, selected extraction, and artifact-only
     non-goals.
   - `Inputs Reviewed`: exact input artifacts from step 1.
   - `Commands Run`: each scan command and whether it matched the expected
     shape.
   - `Current Import Counts`: exact counts by `src`, `app`, `test`,
     `agent-workflow-core`, `agent-workflow-codex`, and
     `agent-workflow-github`.
   - `Completed Safe Candidates`: one row for each of the five prior
     candidates, with prior round number, direct owner import, and no-current
     facade-import confirmation.
   - `Remaining Importers`: every current importer with blocker type and the
     relevant observed token groups.
   - `Recommendation`: state whether direction 011 has any safe next
     single-domain implementation slice. If none exist, recommend closing this
     direction's single-domain queue and selecting a later split-import or
     bridge-readiness direction rather than doing mechanical import movement.
   - `Changed-Path Evidence`: prove only round-103 artifacts changed, apart
     from controller-owned state already present before implementation if it is
     still in the worktree.

8. Do not create `orchestrator/rounds/round-103/worker-plan.json`. If the scan
   unexpectedly finds a new clearly single-domain candidate, record it in the
   recommendation only; do not broaden this artifact-only round into
   implementation work.

### Verification

Run artifact-only validation:

```sh
git diff --check
git diff --cached --check
git diff --name-status
git diff -- orchestrator/rounds/round-103/plan.md \
  orchestrator/rounds/round-103/core-ids-remaining-blocker-readiness.md
git diff -- src app test moifold.cabal cabal.project \
  agent-workflow-core agent-workflow-codex agent-workflow-github
```

Package build/test may be skipped only if changed-path evidence shows the
implementation changed no production code, test code, package descriptor,
runtime compatibility file, public API, fixture, docs, or behavior surface. If
any non-artifact file changes, stop and restore scope before review rather than
using this artifact-only validation path.
