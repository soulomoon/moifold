### Changes Made
- src/CodexWatcher/Workflow/Moifold/IssuePlanning/Indexed.hs: added the moifold-owned indexed issue-planning adapter, phantom state markers, wrapper types, replay/event conversion helpers, and an IndexedWorkflowSpec instance that delegates to the existing MoifoldSpec compatibility policy.
- moifold.cabal: exposed CodexWatcher.Workflow.Moifold.IssuePlanning.Indexed from the moifold library beside the existing indexed PR-review adapters.
- test/Main.hs: added indexed issue-planning parity coverage for policy transitions, graph validation success/failure cases, invalid observation failures, replay/effect/permission/dry-run/request-id parity, and compatibility write preservation.
- orchestrator/rounds/round-013/implementation-notes.md: recorded implementation scope and verification evidence for this round.

### Tests
- test/Main.hs: verifies indexed issue planning matches the compatibility route for turn start, issue requests, graph updates, ready-issues-fixed, scope completion, retry, completion, and blocked transitions from ready/active/waiting states.
- test/Main.hs: verifies invalid graph observations produce the same WatcherBlocked transitions for duplicate ready issue, duplicate blocked issue, duplicate dependency entry, ready/blocked overlap, dependency-on-ready, and out-of-scope failures, plus a scoped dependency closure success case.
- test/Main.hs: verifies invalid observations from wrong source states fail with the same compatibility failure text.
- cabal test watcher-core-test --test-options '--match indexed workflow': PASS.
- cabal test watcher-core-test --test-options '--match issue planning': PASS.
- cabal build all: PASS.
- cabal test watcher-core-test: PASS.
- git diff --check: PASS.
- git diff --cached --check: PASS.

### Notes
Live daemon routing was not changed in this round. No worker-plan.json was used. Existing event schemas, golden fixtures, daemon result shapes, dry-run rendering, action ordering, request-id progression, compatibility write paths, graph/scope validation, roadmap files, and orchestrator/state.json were preserved.
