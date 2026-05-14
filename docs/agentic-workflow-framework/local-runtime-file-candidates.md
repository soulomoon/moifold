# Local Runtime-File Candidate Decisions

Date: 2026-05-14

This note closes the local half of roadmap direction
`direction-026-local-runtime-file-removal-candidates`. It covers local runtime
files that did not have owner-scoped downstream code-search hits in the
2026-05-14 audit.

## Decisions

| File | Decision | Evidence | Cleanup consequence |
| --- | --- | --- | --- |
| `planning-state.json` | `removed` | No owner-scoped downstream hits were found; healthcheck never read it; `RecordPlanningGraph` now compiles to no runtime write; issue-planning compatibility projection writes only `planner-state.json`; the obsolete fixture was deleted. Planning graph truth remains in the event log and replayed watcher state. | Do not restore the compatibility file unless a selected behavior-change round reintroduces a supported reader contract with old-log and fixture evidence. |
| `repair-state.json` | `keep-as-product` | It is a repair command diagnostic written only by `repair-invalid-state --execute`, has fixture and execute-order coverage, and is intentionally absent from healthcheck and runtime readers. | Treat as a moifold repair diagnostic, not a compatibility alias. It does not need removal for public facade cleanup. |
| `runtime-owner.json` | `keep-as-product` | Runtime owner store, runtime-owner CLI, healthcheck, automatic loop validation, and `scripts/restart-watcher` use it as the live daemon lease contract. Fixture tests cover the current lease shape and reject old owner-only JSON. | Retain as live runtime ownership state until a selected replacement lease mechanism lands. |
| `issue-snapshot.json` | `keep-as-product` | Issue planning writes it before planner turns; prompt rendering tells planners to read it; fixture tests cover the deterministic shape and write timing. Healthcheck, repair, snapshot loading, and restart do not read it. | Retain as live planner input, not a removable compatibility projection, until a selected replacement planner-input path lands. |

## Verification

The decision is guarded by `localRuntimeFileCandidateDecisionTest` in
`RuntimeCompatibilityFixtureSpec`, plus the existing focused fixture/source
tests for planning-state removal, repair-state execute order, runtime-owner
lease shape, and issue-snapshot write timing.

These decisions do not close terminal cleanup. Runtime-file removal remains
blocked by the direct-reader state files documented in
`downstream-runtime-state-migration.md` until the local downstream daemon-shim
patch is accepted upstream or the downstream owner explicitly retains the
legacy runtime. Normal local Haskell compatibility-file producers have been
removed, checked-in compatibility snapshot readers/fixtures were later migrated
to bootstrapped event-log fixtures, and restart/operator runbooks no longer
depend on stale compatibility files. The retained `repair-state.json`,
`runtime-owner.json`, and live `issue-snapshot.json` files are product
contracts outside the compatibility-file removal goal. The repair-failure
`block-state.json` writer and fixture were removed after this decision artifact
was introduced.
