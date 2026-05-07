# Workflow Kernel Indexing Roadmap

## Status Legend

- `pending`
- `in-progress`
- `done`

## Items

1. [done] Extract generic checked-action failure traversal into core
   Item id: item-001-checked-action-failure-core
   Depends on: none
   Parallel safe: no
   Parallel group: none
   Merge after: none
   Completion notes: Completed in round-001. The reusable checked-action traversal and failure-report shape now live in `agent-workflow-core`; concrete `ActionExecutor`, command reports, hard-failure classification, daemon failure mapping, and facade compatibility remain in moifold adapters.

2. [done] Add workflow facade law and parity coverage
   Item id: item-002-facade-laws
   Depends on: item-001-checked-action-failure-core
   Parallel safe: no
   Parallel group: none
   Merge after: item-001-checked-action-failure-core
   Completion notes: Completed in round-002. Added DocsMigration and PR-review mergeability facade-law coverage for observe/plan agreement, apply and replay parity, effect-history stability, permission acceptance/rejection, and dry-run/action ordering. The round preserved event schema, golden fixture, daemon result, dry-run, runtime command, action-ordering, facade representation, and indexed API surfaces while making the narrow permission-core fix needed for spec-level effect-plan validation.

3. [done] Harden package boundary guards for the indexed rewrite
   Item id: item-003-boundary-guards
   Depends on: item-002-facade-laws
   Parallel safe: no
   Parallel group: none
   Merge after: item-002-facade-laws
   Completion notes: Completed in round-003. Strengthened `agent-workflow-core` boundary tests now recursively reject accidental imports of moifold lifecycle types, Aeson codecs, runtime interpreters, GitHub adapters, Codex app-server modules, daemon policy/runtime modules, forbidden concrete lifecycle/action/event tokens, and disallowed core package dependencies while preserving generic core exposure assertions and production behavior.

4. [pending] Introduce the parallel indexed WorkflowSpec API
   Item id: item-004-indexed-spec-api
   Depends on: item-003-boundary-guards
   Parallel safe: no
   Parallel group: none
   Merge after: item-003-boundary-guards
   Completion notes: Add an indexed spec module beside the compatibility facade, with indexed state/event/observation/effect types and existential wrappers, without rewriting `WatcherEvent` or `SomeWatcherState` wholesale.

5. [pending] Port DocsMigration as the first indexed workflow proof
   Item id: item-005-indexed-docs-migration
   Depends on: item-004-indexed-spec-api
   Parallel safe: no
   Parallel group: none
   Merge after: item-004-indexed-spec-api
   Completion notes: Express DocsMigration through the indexed API while preserving its event codec, replay fixture, permission checks, dry-run output, and daemon result behavior.

6. [pending] Port one PR-review transition slice to the indexed API
   Item id: item-006-indexed-pr-review-slice
   Depends on: item-005-indexed-docs-migration
   Parallel safe: no
   Parallel group: none
   Merge after: item-005-indexed-docs-migration
   Completion notes: Port a narrow PR-review checking or mergeability transition through the indexed API, proving the approach on real moifold lifecycle state without broad `WatcherEvent` churn.
