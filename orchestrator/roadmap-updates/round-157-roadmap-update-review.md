### Checks Run
- Command: `test -f ...` over `orchestrator/active-roadmap-bundle.md`, `orchestrator/project-contract.md`, `orchestrator/state.json`, active `roadmap.md`, `verification.md`, `retry-subloop.md`, family `roadmap-history.md`, `orchestrator/roadmap-updates/round-157-roadmap-update.md`, and round-157 selection/implementation/review/merge artifacts
  Result: pass. All required control-plane, active bundle, roadmap update, and source round evidence artifacts are present.

- Command: `python3 -m json.tool orchestrator/state.json`
  Result: pass. The state file is valid JSON.

- Command: state metadata assertion script over `orchestrator/state.json`
  Result: pass. `roadmap_id` is `2026-05-11-00-highest-value-cleanup`, `roadmap_revision` is `rev-001`, `roadmap_dir` remains `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`, `last_completed_round` is `round-157`, no active or pending rounds remain, and `roadmap_update` records `round-157`, source commit `ad82d27a13acc5aa70e8c68ad6965e48d65b49b2`, `prior_roadmap_revision: rev-001`, `proposed_roadmap_revision: rev-001`, and `status: review`.

- Command: `git diff --check`
  Result: pass. No whitespace errors.

- Command: `git diff --cached --check`
  Result: pass. No staged whitespace errors.

- Command: `find orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup -maxdepth 1 -type d -name 'rev-*' -print | sort`
  Result: pass. Only `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001` exists; the update did not create a new roadmap revision.

- Command: milestone heading parser over `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`
  Result: pass. Milestone 003 remains `### 3. [in-progress] Import Convergence And Package-Boundary Cleanup`; milestones 002, 004, 005, and 006 remain pending, so the roadmap is not terminal.

- Command: `git diff --name-status HEAD -- orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md orchestrator/state.json orchestrator/roadmap-updates/round-157-roadmap-update.md`
  Result: pass. Tracked diff is limited to the active `rev-001/roadmap.md` status pointer and `orchestrator/state.json`; the update artifact is new and untracked as expected before commit. No production code, tests, package descriptors, docs, compatibility files, verification policy, retry policy, or new revision directories are changed by the roadmap update.

- Command: `git status --porcelain=v1 --untracked-files=all`
  Result: pass. Current review worktree contains only the roadmap status diff, state update metadata, the roadmap update artifact, and this review artifact after creation.

- Command: `git diff --cached --name-status`
  Result: pass. No staged paths.

- Command: `git show --stat --oneline --name-status ad82d27a13acc5aa70e8c68ad6965e48d65b49b2`
  Result: pass. The merged source round is `ad82d27 Round 157: Migrate RunnerGuardSpec ID imports`; it added round-157 artifacts, updated orchestrator state, and modified only `test/RunnerGuardSpec.hs` as the source/test file.

- Command: `git show --unified=0 --format=short ad82d27a13acc5aa70e8c68ad6965e48d65b49b2 -- test/RunnerGuardSpec.hs`
  Result: pass. The source diff only replaces `CodexWatcher.Core.Ids (RepoName (..), RequestId (..), ThreadId (..), TurnId (..), unThreadId, unTurnId)` with direct owner imports from `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`.

- Command: `rg -n 'CodexWatcher\.Core\.Ids|CodexWatcher\.Workflow\.(Agent|GitHub)\.Ids' test/RunnerGuardSpec.hs`
  Result: pass. `test/RunnerGuardSpec.hs` now imports `RequestId`, `ThreadId`, `TurnId`, `unThreadId`, and `unTurnId` from `CodexWatcher.Workflow.Agent.Ids`, and `RepoName` from `CodexWatcher.Workflow.GitHub.Ids`; there is no `CodexWatcher.Core.Ids` match in the selected file.

- Command: `rg -n 'CodexWatcher\.Core\.Ids' src app test docs moifold.cabal`
  Result: pass. Remaining `CodexWatcher.Core.Ids` users are still present across source, tests, docs, and `moifold.cabal`, including the facade module itself and exposed-module entry. This confirms round 157 did not imply broader Core.Ids migration, Cabal exposure cleanup, public facade removal, or compatibility removal.

- Command: `rg -n 'Proposed revision: `rev-001`|Requires state\.json roadmap metadata update: no|New roadmap_dir when applicable: not applicable|milestone completion|terminal completion|release approval|public compatibility removal' orchestrator/roadmap-updates/round-157-roadmap-update.md`
  Result: pass. The update artifact states the proposed revision remains `rev-001`, no roadmap metadata activation is needed, no new roadmap dir applies, and milestone completion, terminal completion, release approval, and public compatibility removal are not approved.

- Command: read `orchestrator/rounds/round-157/selection.md`, `implementation-notes.md`, `review.md`, and `merge.md`
  Result: pass. Source round evidence records the same extracted item, direct-owner import change, passing `cabal test watcher-core-test`, passing `cabal build all`, diff hygiene, focused import scans, and explicit non-approval boundaries.

- Command: package build/test baseline from `verification.md`
  Result: skipped with reviewer rationale. This is a roadmap-update review with no production code, test code, package descriptor, runtime compatibility file, public API, fixture, docs, or behavior surface changed by the update diff; the active verification contract allows artifact-only roadmap-update rounds to skip package build/test when changed-path evidence is recorded. The merged source round already recorded passing `cabal build all` and `cabal test watcher-core-test`.

### Roadmap Compliance
- The update follows merged round-157 evidence. The roadmap additions describe only the approved one-file `test/RunnerGuardSpec.hs` migration from the `CodexWatcher.Core.Ids` compatibility facade to direct `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids` imports, matching the merged commit and round evidence.
- The update keeps `rev-001` status-only semantics. It appends compact completion pointers to existing milestone 003 and direction 011 status text; it does not change future coordination, sequencing, parallel lanes, extraction scope, verification meaning, retry policy, or milestone/direction meaning.
- The update does not create or activate a new revision. State remains on `rev-001`, the proposed revision is `rev-001`, and no `rev-002` directory exists.
- Milestone 003 remains in progress, and `direction-011-core-ids-import-convergence` remains open for further exact Core.Ids import-convergence slices. The roadmap still has pending milestones and must not be treated as terminal.
- The update preserves explicit non-approval boundaries. It does not approve public facade deprecation/removal, Cabal exposure cleanup, docs cleanup, package descriptor cleanup, broader Core.Ids migration, runtime compatibility cleanup, milestone completion, terminal completion, release approval, public compatibility removal, or package publication.
- Focused import evidence confirms `test/RunnerGuardSpec.hs` is migrated and other `CodexWatcher.Core.Ids` users remain, including source, test, docs, and Cabal exposure entries. That is consistent with a narrow import-convergence status update rather than a removal/deprecation gate.

### Decision
**APPROVED**
