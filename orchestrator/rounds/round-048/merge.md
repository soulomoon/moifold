### Squash Commit
- Title: Add package candidate changelog and release notes
- Summary: Adds source-backed changelog and release-note material for the `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github` `0.1.0.0` package candidates, then links those artifacts from the framework docs index and package READMEs. The docs record current package scope, descriptor metadata, local validation evidence, consumer-example evidence, compatibility-facade status, moifold-owned boundaries, pre-1.0 expectations, and explicit no-publication/no-upload/no-go-live wording.

### Merge Readiness
- Base branch freshness: confirmed. `HEAD`, `codex/workflow-facade-extraction`, and their merge base all resolve to `dd1fd169e08db795257282380e78e1a9e0eb1d41` before the staged round payload.
- Merge ordering satisfied: yes. `round-048` depends on `round-036` through `round-047`; controller state records `last_completed_round` as `round-047`, no pending merge rounds, and the active round is `round-048` at merge stage.
- Pending dependencies: none.

### Follow-Up Notes
This merge prepares documentation evidence only. It does not approve a package upload, release announcement, tag, final go/no-go decision, compatibility-facade removal, descriptor/version change, CI change, source change, roadmap edit, or controller-state payload. `orchestrator/state.json` remains unstaged controller bookkeeping outside this squash payload.
