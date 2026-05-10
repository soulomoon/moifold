### Changes Made
- `test/Main.hs`: strengthened the runtime-owner JSON contract property to assert that `runtimeLeaseJson` has top-level `lease`, has no top-level `owner` or `runtime`, and stores the runtime owner identity at nested `lease.runtime`.
- `test/BoundaryPolicySpec.hs`: added a focused healthcheck source-policy assertion that preserves `runtime-owner.json` as the `runtimeOwner` state surface through shared issue-planning/issue-implementation state files and PR-review state files, preserves summary lookup through `["runtimeOwner","owner"]`, and rejects switching to `["runtimeOwner","lease","runtime"]`.
- `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`: narrowed the `runtime-owner.json` row to record the current round-089 healthcheck field-path contract and remaining gates before any future behavior change.

### Tests
- `test/Main.hs`: verifies current runtime-owner lease JSON shape and nested owner identity path.
- `test/BoundaryPolicySpec.hs`: verifies the current healthcheck runtime-owner file mapping and summary field-path contract by source-policy scan.

### Notes
This round records current contract evidence only. It does not change production healthcheck behavior, runtime-owner production/schema, repair behavior, scripts, fixtures, file names, schema, roadmap files, or controller state. No `worker-plan.json` was created.
