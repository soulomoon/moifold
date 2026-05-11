### Changes Made

- `orchestrator/rounds/round-097/facade-import-scan-refresh.md`: created the
  round-local inventory artifact for `CodexWatcher.AppServerClient`,
  `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.EventLog`, and
  `CodexWatcher.Workflow.Permission`. The artifact records lineage,
  non-goals, exact scan commands, grouped current references, per-facade
  classifications, blockers, and next-slice notes.
- `orchestrator/rounds/round-097/implementation-notes.md`: recorded the
  command summaries, changed-path evidence, and artifact-only baseline
  rationale for this evidence-only round.

### Tests

No package build or test target was run for this artifact-only round. The
active verification bundle permits skipping `cabal build all` and
`cabal test watcher-core-test` when changed-path evidence shows the round
touched only round-local orchestrator artifacts and no production code, test
code, package descriptor, runtime compatibility file, public API, fixture,
docs, or behavior surface.

Read-only scans run:

- Re-read control-plane inputs:
  `orchestrator/state.json`,
  `orchestrator/rounds/round-097/selection.md`,
  `orchestrator/rounds/round-097/plan.md`,
  `orchestrator/project-contract.md`,
  `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`,
  and
  `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`.
- Confirmed facade source shapes from
  `src/CodexWatcher/AppServerClient.hs`,
  `src/CodexWatcher/Core/Ids.hs`,
  `src/CodexWatcher/Workflow/EventLog.hs`, and
  `src/CodexWatcher/Workflow/Permission.hs`.
- Broad selected-facade reference scan over `src`, `app`, `test`,
  `agent-workflow-core`, `agent-workflow-codex`, `agent-workflow-github`,
  `docs`, `examples`, `scripts`, `*.cabal`, and `cabal.project`: completed.
- Narrow import-only scan over `src`, `app`, `test`, and standalone package
  candidates: completed. Current selected-facade import counts are
  `AppServerClient`: 19, `Core.Ids`: 44, `Workflow.EventLog`: 10, and
  `Workflow.Permission`: 7.
- Package exposure and direct-owner scan over all package descriptors:
  completed. `moifold.cabal` still exposes the four selected facades; candidate
  package descriptors expose direct owner modules and no selected facades.
- Direct-owner import scan over `src`, `app`, `test`, and standalone package
  candidates: completed. Existing direct-owner imports are present for Codex
  client/transport, agent ids, GitHub ids, event-log core/file/commit, audit,
  and permission core modules.
- Exact-reference scan separated selected facade references from owner-module
  prefix references in docs and package candidates.
- `Core.Ids` symbol-domain scan classified current import users as 3
  GitHub-only candidates, 2 agent-only candidates, and 39 combined users that
  need later split-import evidence. This retry uses exact token matching so
  `ReviewThreadId` is not misclassified as an agent `ThreadId` use.

Verification run after writing the artifacts:

- `git status --short --untracked-files=all`
  - Result: `M orchestrator/state.json`, plus untracked
    `orchestrator/rounds/round-097/facade-import-scan-refresh.md`,
    `orchestrator/rounds/round-097/implementation-notes.md`,
    `orchestrator/rounds/round-097/plan.md`, and
    `orchestrator/rounds/round-097/selection.md`.
  - The `orchestrator/state.json` modification and the round `plan.md` /
    `selection.md` artifacts were present before implementation and were not
    edited by this round.
- `git diff --name-only`
  - Result: `orchestrator/state.json` only, because the owned artifacts are
    new untracked files and the only tracked dirty path is pre-existing
    controller metadata.
- `git diff --check`
  - Result: passed with no output.
- `git ls-files --others --exclude-standard orchestrator/rounds/round-097`
  - Result: lists the two owned artifacts plus the pre-existing untracked
    `plan.md` and `selection.md` controller artifacts.
- `rg -n "deprecat|remov|migrat|delete|rename|approval|Cabal exposure" \
  orchestrator/rounds/round-097/facade-import-scan-refresh.md \
  orchestrator/rounds/round-097/implementation-notes.md`
  - Result: matches are confined to the required non-goal statements,
    blocker language, policy-reference paths, public exposure inventory, and
    this verification command. No line claims deprecation, migration, removal,
    Cabal exposure change, release approval, milestone completion, or runtime
    compatibility cleanup approval.

Retry verification run for the material inventory correction:

- Exact-token `Core.Ids` symbol-domain scan over current import users:
  - Result: 3 `github-only`, 2 `agent-only`, and 39 `both`.
  - The retry classifier matches complete tokens only, so `ReviewThreadId`
    is counted as a GitHub id and does not imply `ThreadId`.
- Targeted `test/BoundaryPolicySpec.hs` scan:
  - GitHub tokens found: `RepoName`, `IssueNumber`, `PrNumber`,
    `BranchName`, and `ReviewThreadId`.
  - Exact agent-token scan for `RequestId`, `ThreadId`, `TurnId`, and
    `nextRequestId`: no matches.
- Artifact sanity scan for stale classification text:
  - `BoundaryPolicySpec` now appears under the GitHub-only candidate list.
  - The stale prior combined-total wording is absent; `39 combined` appears in
    the corrected totals.
- `git status --short --untracked-files=all`
  - Result: pre-existing `M orchestrator/state.json`, untracked owned
    artifacts, pre-existing untracked `plan.md` / `selection.md`, and
    untracked review artifacts. Review artifacts were not edited.
- `git diff --name-only`
  - Result: `orchestrator/state.json` only, because the owned artifacts remain
    untracked and the tracked dirty path is pre-existing controller metadata.
- `git diff --check`
  - Result: passed with no output.
- Re-ran the no-overstatement scan above:
  - Result: matches remain confined to required non-goals, blocker language,
    policy-reference paths, public exposure inventory, and verification text.

### Notes

- The existing dirty `orchestrator/state.json` controller metadata was present
  before this implementation and was not edited.
- `orchestrator/rounds/round-097/selection.md` and
  `orchestrator/rounds/round-097/plan.md` were already present before writing
  the owned artifacts and were read only.
- This round makes no import migration, no Cabal exposure change, no public
  deprecation, no facade removal, no compatibility-file cleanup
  classification, no runtime compatibility cleanup, no behavior change, no
  roadmap edit, and no controller state edit.
