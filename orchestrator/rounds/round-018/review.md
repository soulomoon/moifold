### Findings
- No findings.

### Prior Rejection Checklist
- Focused parity coverage now covers the full accepted observation/source-state matrix from `plan.md`, including the previously missing multi-source routes:
  - PR create/reuse from implementation-ready and implementing states.
  - PR body update from plan-ready, implementation-ready, and implementing states.
  - implementation blocked from implementation-ready and implementing states.
  - handoff initialized/started idempotent routes from handoff and waiting-for-merge states.
  - implementation completed from implementing, handoff-ready, handoff-initialized, and waiting-for-merge states.
  - reviewer-thread-ready from handoff-ready, handoff-initialized, waiting-for-merge, post-merge-pending-reviewer, and post-merge-ready states.
  - waiting-for-merge PR merged with and without an existing reviewer thread.
  - ignored merged-PR observations from implementation-ready, implementing, handoff-ready, handoff-initialized, post-merge-pending-reviewer, post-merge-ready, post-merge-reviewing, and waiting-for-issue-close states.
  - generic blocked observations from every accepted non-terminal IssueImplement state.
- Invalid/blocking coverage now includes wrong PR body update, duplicate plan start, completion before implementation turn, post-merge review start without a reviewer, terminal observations, wrong-domain observations, wrong handoff initialization/start, stale implementation completion, and wrong issue close.
- The waiting-for-merge merged-PR projection now selects the indexed post-merge-review-ready marker for the reviewer-present branch and the pending-reviewer marker for the no-reviewer branch, while preserving the same compatibility event and effect behavior.
- `Watcher.hs` and `Replay.hs` are aligned for ignored merged-PR observations: the observer and replay layer now expose the same idempotent sleep behavior for the non-waiting IssueImplement states that the state machine already handled.

### Contract Review
- Moifold-owned adapter: met. `CodexWatcher.Workflow.Moifold.IssueImplement.Indexed` lives in the moifold source tree and wraps `MoifoldSpec` compatibility behavior.
- Cabal exposure: met. `moifold.cabal` exposes the new adapter module.
- No live daemon routing expansion: met. The focused source-scan test passed and the implementation diff does not import the adapter from `CodexWatcher.Domain.IssueImplement.Loop`, `CodexWatcher.DaemonLoop`, or automatic-loop modules.
- No concrete policy moved into `agent-workflow-core`: met. No `agent-workflow-core` files changed.
- Compatibility surfaces: met. The parity helper compares facade observe, generic observe, planned transitions, indexed observe/plan/apply, compatibility apply, replay state/effects, source/target/final labels, event labels, pre/post effect plans, effect validation, effect permission, compatibility writes, action ordering, dry-run text, and request-id progression for the policy matrix.
- Event schemas/type fields/golden logs/daemon shapes/dry-run text/action ordering/request-id progression/compatibility writes/replay/effect validation/effect permissions: no regression found in review or in the focused/full watcher-core runs.

### Verification Evidence
- Command: `cabal test watcher-core-test --test-option=--match --test-option='indexed workflow issue implement'`
  Result: pass. The watcher-core test suite passed; the output includes the focused `indexed workflow issue implement ...` rows for the expanded matrix and invalid/blocking cases.
- Command: `cabal test watcher-core-test`
  Result: pass. The full watcher-core test suite passed.
- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`.
- Command: `git diff --check`
  Result: pass. No whitespace errors were reported.
- Command: `git diff --cached --name-only`
  Result: no staged files. Per the review contract, `git diff --cached --check` was not run because there was no staged diff.

### Decision
**APPROVED**
