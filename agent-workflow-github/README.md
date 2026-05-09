# agent-workflow-github

`agent-workflow-github` is the reusable GitHub adapter package candidate for
typed identifiers, pure remote parsers and classifiers, and deterministic
`gh`/`git` command specifications.

The package owns data and pure command specs. It does not execute commands,
decide issue or PR lifecycle state, decide merge readiness, publish review
feedback, run healthcheck or repair, own Codex adapter behavior, own moifold
runtime policy, or make package publication decisions.

This is a local external-package candidate in this repository. The README is
documentation for the implemented package surface, not a package upload or
public stability claim.

## Architecture

The public modules are grouped by ownership:

- `CodexWatcher.Workflow.GitHub.Ids`: typed repository, issue, PR, branch,
  review-thread, and commit-SHA values.
- `CodexWatcher.Workflow.GitHub.Remote`: pure parsers and classifiers for
  GitHub and git observations, including issue state, PR state, PR checks, PR
  create results, review threads, branch names, commit SHAs, and merge-state
  diagnostics.
- `CodexWatcher.Workflow.GitHub.Command`: pure `gh` and `git` command
  specifications with command name, arguments, working directory, and stdin.

## Guarantees

The GitHub adapter keeps repository, issue, PR, branch, review-thread, and SHA
values typed; parses remote JSON or command output without executing commands;
classifies remote state through pure functions; and renders command specs
deterministically for an external interpreter to inspect, dry-run, or execute.

It does not own command execution authority, local worktree mutation, PR or
issue lifecycle policy, merge policy, review publication policy, healthcheck,
repair, Codex agent behavior, moifold runtime ownership, or publication gates.

## Evidence

- [Implemented API freeze](../docs/agentic-workflow-framework/implemented-api-freeze.md)
- [Package extraction readiness](../docs/agentic-workflow-framework/package-extraction-readiness.md)
- [Compatibility and deprecation policy](../docs/agentic-workflow-framework/compatibility-deprecation-policy.md)
- [Package validation](../docs/agentic-workflow-framework/package-validation.md)
- [Package consumer guide](../docs/agentic-workflow-framework/package-consumer-guide.md)
- [Buildable consumer example](../examples/workflow-package-consumer)
