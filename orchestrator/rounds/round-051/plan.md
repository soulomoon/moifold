### Goal
Record the terminal publication-gate outcome for
`direction-016-explicit-publication-gate` /
`item-051-explicit-publication-gate` as an explicit, reviewable decision.

The expected outcome for the current tree is a deliberate hold, not an approved
publication plan, because the current release-candidate evidence still records
unobserved hosted CI, Haddock per-export/link warnings, and no explicit
user/operator approval for externally visible package upload. The round must
leave `agent-workflow-core`, `agent-workflow-codex`, and
`agent-workflow-github` in candidate state and must not upload packages, create
tags, create GitHub releases, publish announcements, or trigger workflows.

### Approach
Keep the round documentation-only and terminal-gate focused. Add a clear
decision document under `docs/agentic-workflow-framework/`, preferably
`publication-gate-decision.md`, that references the release-candidate bundle
and prior round evidence, classifies blockers package-by-package, and records
the no-go/hold decision.

The decision document should distinguish:

- package-local readiness evidence already present in the release-candidate
  bundle;
- terminal blockers that prevent publication approval now;
- shared release blockers that apply to all three package candidates;
- actions explicitly not run in this round.

Do not change package descriptors, package source, Cabal wiring, CI workflows,
generated artifacts, changelog/release-note source material, compatibility
facades, event schemas, runtime policy, healthcheck, repair, prompt policy,
roadmap files, or `orchestrator/state.json`. A single README index link to the
new decision document is acceptable if it stays next to the existing release
candidate bundle link. Also write
`orchestrator/rounds/round-051/implementation-notes.md` with the files changed,
decision outcome, blocker classification, and validation results.

### Steps
1. Confirm worktree safety with `git status --short --branch`. Treat the
   existing `orchestrator/state.json` change as unrelated and leave it
   untouched.
2. Inspect the round and release-gate inputs:
   `orchestrator/rounds/round-051/selection.md`,
   `orchestrator/roadmaps/2026-05-09-00-external-package-extraction/rev-001/verification.md`,
   `orchestrator/project-contract.md`,
   `docs/agentic-workflow-framework/release-candidate-bundle.md`,
   `orchestrator/rounds/round-050/review.md`,
   `orchestrator/rounds/round-050/review-record.json`,
   `orchestrator/rounds/round-050/merge.md`, and the active roadmap.
3. Create `docs/agentic-workflow-framework/publication-gate-decision.md` with:
   a status line saying the publication gate is on deliberate hold;
   the date; package-by-package sections for `agent-workflow-core`,
   `agent-workflow-codex`, and `agent-workflow-github`; shared blocker
   classification; evidence references to the release-candidate bundle and
   rounds 049 and 050; and an explicit statement that no package upload, tag,
   GitHub release, release announcement, workflow trigger, or publication
   command ran.
4. In each package section, summarize current candidate evidence from the
   bundle and classify the relevant blockers. `agent-workflow-core` should
   mention successful package validation/build/test/consumer evidence but
   missing per-export Haddock coverage. `agent-workflow-codex` should include
   the same validation evidence, Haddock/link-warning classification, and the
   need to keep app-server startup, prompts, structured-output acceptance, and
   lifecycle routing moifold-owned. `agent-workflow-github` should include the
   pure command-spec candidate evidence and confirm command execution and
   release publication policy stay moifold-owned.
5. In the shared decision section, classify hosted CI as not observed unless
   `gh run list` on the current branch shows a relevant completed successful
   CI run without triggering a workflow. If no such run is observed, state that
   local CI configuration coverage is evidence but not a hosted CI pass.
6. Explicitly record that there is no user/operator approval for externally
   visible package upload in this round. This alone is sufficient to hold even
   if local validation passes.
7. Optionally add one narrow link from
   `docs/agentic-workflow-framework/README.md` to
   `publication-gate-decision.md`. Do not otherwise reorganize the docs index.
8. Write `orchestrator/rounds/round-051/implementation-notes.md` summarizing
   the decision document, optional README link, validation commands, blockers,
   and untouched areas.
9. Do not write `worker-plan.json`; this terminal gate is a small serial docs
   decision with no disjoint implementation ownership.

### Verification
Run and record the exact results in implementation notes:

- `git status --short --branch`
- Inspect input documents listed in step 2.
- `scripts/validate-workflow-packages.sh`
- `cabal build all`
- `cabal test watcher-core-test`
- `cabal haddock agent-workflow-core agent-workflow-codex agent-workflow-github --haddock-all`
- `(cd examples/workflow-package-consumer && cabal build all)`
- `(cd examples/workflow-package-consumer && cabal run workflow-package-consumer)`
- `rg -n "strategy:|matrix:|ghc-version|cabal-version|ripgrep|cabal build all|cabal test watcher-core-test|validate-workflow-packages" .github/workflows/ci.yml`
- `gh run list --workflow=CI --branch "$(git branch --show-current)" --limit 5`
- `gh run list --workflow=CI --branch "$(git branch --show-current)" --limit 5 --json databaseId,status,conclusion,headBranch,workflowName,displayTitle,createdAt,updatedAt`
- `rg -n "cabal[[:space:]]+upload|stack[[:space:]]+upload|hackage-upload|curl[[:space:]].*hackage|gh release|git tag|release announcement|approved publication|publication approved|uploaded|published|ready to upload|release-ready" docs/agentic-workflow-framework README.md agent-workflow-core agent-workflow-codex agent-workflow-github scripts .github orchestrator/rounds/round-051`
- `rg -n "package upload|publication command|workflow trigger|tag creation|GitHub release|release announcement|No upload|no package publication command|deliberate hold|candidate state|not observed|Haddock" docs/agentic-workflow-framework/publication-gate-decision.md docs/agentic-workflow-framework/release-candidate-bundle.md orchestrator/rounds/round-051`
- `rg -n "WatcherEvent|event JSON `type`|schema version|golden|healthcheck|repair|prompt policy|runtime ownership|compatibility file|compatibility facade|app-server startup|issue/PR lifecycle|command execution|moifold-owned|moifold owned" docs/agentic-workflow-framework/publication-gate-decision.md docs/agentic-workflow-framework/release-candidate-bundle.md`
- `git diff --name-only | rg -v '^(docs/agentic-workflow-framework/(README|publication-gate-decision)\\.md|orchestrator/rounds/round-051/(selection|plan|implementation-notes|review|review-record)\\.json|orchestrator/rounds/round-051/(selection|plan|implementation-notes|review)\\.md|orchestrator/state\\.json)$' || true`
- `git diff --check`
- `git diff --cached --check` if any files become staged.

Manual verification must classify scan matches instead of relying only on exit
codes. The final decision document must not overclaim hosted CI, must not imply
that Haddock warnings are resolved if they remain, must not imply operator
approval, and must not contain upload/tag/release/workflow-triggering
instructions.

### Worker Fan-Out
Worker fan-out is not used. The task is a serial terminal-gate documentation
decision with a small, coupled write set, and parallel workers would add
coordination overhead without improving ownership boundaries.
