### Squash Commit
- Title: Record terminal facade cleanup hold
- Summary: Adds the approved artifact-only terminal decision report for `round-082-terminal-decision-report`. The round records `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.EventLog`, and `CodexWatcher.Workflow.Permission` as kept available for now, deferred for public deprecation and Cabal exposure removal, and blocked from exact removal by named evidence gaps. It approves no production, test, documentation, package descriptor, roadmap, state, runtime compatibility, event schema, healthcheck, repair, release, publication, deprecation, exposed-module, import migration, or facade deletion change.

### Merge Readiness
- Base branch freshness: confirmed. Branch `orchestrator/round-082-terminal-decision-report` is at `d831960`, matching base `codex/workflow-facade-extraction`.
- Merge ordering satisfied: yes. Declared dependencies and merge-after items for rounds 075-081 have already completed on the base branch before this round.
- Pending dependencies: none.

### Follow-Up Notes
This is ready for squash merge as an artifact-only round. The merge should include only round-082 orchestrator artifacts, with this report preserving the empty deprecated-surface and removed-surface sets from the approved terminal decision.
