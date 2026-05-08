### Changes Made
- `src/CodexWatcher/Daemon.hs`: routed only the seven round-019 IssueImplement plan-mode/PR-setup daemon observations through the indexed adapter and added `preparedFromIssueImplementProjection`.
- `test/Main.hs`: narrowed the IssueImplement indexed-routing source guard, added a Daemon.hs guard against item-020+ projectors, added dry-run/execute daemon projection parity coverage for the seven routed observations, and extended automatic-loop PR setup assertions to compare routed ticks with indexed projections while preserving plan-write/action ordering.

### Tests
- `test/Main.hs`: verifies the seven routed observations match compatibility `workflowPlanObservation` and the indexed IssueImplement projection in dry-run and execute mode.
- `test/Main.hs`: verifies IssueImplement indexed routing remains out of Loop.hs, DaemonLoop, and AutomaticLoop modules, and that Daemon.hs does not route item-020+ projectors.
- `test/Main.hs`: verifies follow-up worker refresh, PR create, merged-attempt branch advance, and PR body update automatic-loop ticks still match the indexed projection; PR body update also asserts the plan file write occurs before the PR body update command and before the event append.

### Notes
No implementation-turn, review handoff, PR merge-wait, post-merge review, issue close, child lifecycle, GitHub parsing, PR body rendering, or issue-plan recording ownership was moved. `orchestrator/state.json` was already modified before this implementation pass and was left untouched.
