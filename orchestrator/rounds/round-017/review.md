### Checks Run
- Command: `git status --porcelain=v1 -uall`
  Result: pass. Only controller state plus round/rev-004 artifacts are dirty: `orchestrator/state.json`, `orchestrator/rounds/round-017/{selection.md,plan.md,implementation-notes.md}`, and `orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-004/{roadmap.md,verification.md,retry-subloop.md}`.
- Command: `git diff --name-only -- src test golden-files orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-003`
  Result: pass. No production source, tests, golden fixtures, or rev-003 roadmap files are modified.
- Command: `git ls-files --others --exclude-standard | rg '^(src|test|golden-files|orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-003)/'`
  Result: pass. No untracked production source, tests, golden fixtures, or rev-003 roadmap files.
- Command: `git diff -- orchestrator/state.json`
  Result: pass with caveat. The only state diff is controller-owned active round metadata for round 017 moving from update-roadmap to review; it is not an implementation artifact and was left untouched during review.
- Command: `find orchestrator -name worker-plan.json -print`
  Result: pass. No `worker-plan.json` exists.
- Command: `test -f orchestrator/rounds/round-017/plan.md && test -f orchestrator/rounds/round-017/selection.md && test -f orchestrator/rounds/round-017/implementation-notes.md && test -f orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-004/roadmap.md && test -f orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-004/verification.md && test -f orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-004/retry-subloop.md && test ! -e orchestrator/rounds/round-017/worker-plan.json`
  Result: pass. Required artifacts exist and the round has no worker plan.
- Command: `rg -n 'Roadmap id: `2026-05-07-00-workflow-kernel-indexing`|Roadmap revision: `rev-004`|\[done\] Prepare the issue-implementation indexed adoption plan|item-018-indexed-issue-implementation-policy|item-019-indexed-issue-implementation-plan-and-pr-setup-daemon|item-020-indexed-issue-implementation-worker-daemon|item-021-indexed-issue-implementation-handoff-and-merge-wait-daemon|item-022-indexed-issue-implementation-post-merge-review-daemon|item-023-indexed-issue-implementation-close-daemon|item-024-indexed-issue-implementation-lifecycle-hardening' orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-004/roadmap.md`
  Result: pass. `rev-004/roadmap.md` has the required id/revision, marks item 017 done, and orders IssueImplement slices 018-024 after it.
- Command: `rg -n "IssueImplement|IssueFinalReviewOutcome|event `type` fields|JSON schemas|golden fixtures|compatibility module availability|daemon result constructors|dry-run rendering|runtime command rendering|request-id progression|compatibility writes|child lifecycle|agent-workflow-core" orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-004/verification.md`
  Result: pass. Verification is IssueImplement-specific and preserves event/schema/golden/daemon/dry-run/runtime/request-id/compatibility/lifecycle/package-boundary guarantees.
- Command: `rg -n "IssueImplement|event schema|golden replay|dry-run text|daemon result shape|action ordering|request-id progression|compatibility writes|child lifecycle ownership|indexed core|worker-plan.json" orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-004/retry-subloop.md`
  Result: pass. Retry subloop is IssueImplement-specific, keeps worker-slice retry disabled by default, and sends divergences back to parity rather than moving concrete policy into indexed core.
- Command: `rg -n "data IssueImplementObservation|ObservedPlanTurnStarted|ObservedPlanCompleted|ObservedIssueAttemptBranchAdvanced|ObservedIssueWorkerThreadRefreshed|ObservedPullRequestCreated|ObservedPullRequestReused|ObservedPullRequestBodyUpdated|ObservedImplementationTurnStarted|ObservedImplementationIncomplete|ObservedImplementationBlocked|ObservedReviewHandoffInitialized|ObservedReviewHandoffStarted|ObservedImplementationCompleted|ObservedIssueReviewerThreadReady|ObservedPullRequestMerged|ObservedPostMergeReviewStarted|ObservedPostMergeReviewerOutcome|ObservedIssueClosed|ObservedIssueImplementBlocked" src/CodexWatcher/Domain/IssueImplement src/CodexWatcher/StateMachine.hs`
  Result: pass. Roadmap observation names match the current IssueImplement surface.
- Command: `rg -n "data IssueFinalReviewOutcome|IssueFinalReviewOutcome" src/CodexWatcher/Domain/IssueImplement test/Main.hs`
  Result: pass. Final-review outcome coverage is grounded in the current IssueImplement classifier/watcher/test surface.
- Command: `git diff --check`
  Result: pass. No whitespace errors.
- Command: `git diff --cached --name-status`
  Result: pass. Nothing is staged, so `git diff --cached --check` was not run per instruction.
- Command: `git diff --cached --quiet --`
  Result: pass. Confirms there are no staged changes.

### Plan Compliance
- Re-read active round inputs: met. Reviewed `orchestrator/state.json`, reviewer role, selection, plan, implementation notes, rev-003 roadmap/verification/retry, and the newly authored rev-004 files.
- Artifact-only scope: met. No production source, tests, golden fixtures, event schemas, daemon behavior, rev-003 files, or implementation-owned state changes are present. The dirty `orchestrator/state.json` contains controller active-round metadata only.
- New rev-004 roadmap: met. `roadmap.md` keeps roadmap id `2026-05-07-00-workflow-kernel-indexing`, revision `rev-004`, marks item 017 done, and adds ordered non-parallel IssueImplement slices for policy, plan/PR setup, worker, handoff/merge wait, post-merge review/follow-up, close, and lifecycle hardening.
- Preservation contract: met. `verification.md` and `retry-subloop.md` are IssueImplement-specific and preserve event schemas/type fields, golden replay/log expectations, daemon result shapes, detailed transaction failures, dry-run/runtime command rendering, action ordering, compatibility writes/facades, request-id progression, lifecycle ownership, and package boundaries.
- Worker fan-out: met. No `worker-plan.json` exists.
- Verification scope: met. Production build/test commands were skipped because this is an artifact-only planning round and there are no production/test/golden changes. This follows the rev-003/rev-004 verification exception for artifact-only roadmap rounds.

### Decision
**APPROVED**

### Evidence
The integrated review found only planning artifacts for round 017 and the new rev-004 roadmap bundle, plus controller-owned `orchestrator/state.json` active-round metadata. The rev-004 roadmap records the required id and revision, marks item 017 done, and defers implementation into ordered IssueImplement adoption items 018-024. The verification and retry contracts are IssueImplement-specific and preserve compatibility, schema, daemon, dry-run, request-id, lifecycle, and package-boundary guarantees. `git diff --check` passed, and no staged diff exists.
