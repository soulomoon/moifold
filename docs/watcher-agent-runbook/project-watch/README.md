# Project Watch Setup

This layer assumes `../moifold-setup/README.md` has already started the persistent watcher Docker container. All commands in this directory run inside that container through `docker exec`; host execution is not a supported fallback.

Use this order for each target project:

1. Fill `../templates/watcher.env.example` with container-visible paths and save it as a project-specific env file under the mounted state root.
2. Complete `00-project-setup.md`.
3. Run `01-preflight.md` inside the persistent watcher container.
4. For a repository planner, follow `02-start-issue-planning.md`.
5. For one specific issue, follow `03-start-specific-issue.md`.
6. For a PR review watcher, follow `04-start-pr-review.md`.
7. To resume an existing state directory, follow `05-resume-old-state.md`.

Project setup is report-only by default so the agent can show what it will install. Dependency installation is allowed inside the persistent watcher container by rerunning the setup checker with `--install`.

## Choose the right start path

Use `02-start-issue-planning.md` when the agent should watch a repository or planning issue, maintain a planning graph, and fan out issue implementers.

Use `03-start-specific-issue.md` when the agent should implement one already-selected issue.

Use `04-start-pr-review.md` when the agent should watch one PR, handle review feedback, and drive review/merge readiness.

Use `05-resume-old-state.md` when a state directory already exists. Resume before creating fresh state unless the operator explicitly wants a new watcher.

## Common execution pattern

The start runbooks follow the same shape:

1. Enter the persistent watcher container with `docker exec`.
2. Source the project env file from its container path.
3. Run the matching `init-*` script to create state.
4. Inspect generated `config.json`, `events.jsonl`, `dry-run-command.sh`, and `restart-command.sh`.
5. Run one dry-run iteration.
6. Start `--execute --loop` only after the dry run and app-server preflight are acceptable.

## Hard gates before execute mode

- `01-preflight.md` has passed inside the persistent watcher container.
- `gh auth status` succeeds for the target account inside the persistent watcher container.
- The real Codex app-server protocol check has passed from inside the persistent watcher container, not only Docker TCP smoke.
- The target checkout and branch state are understood.
- No existing daemon owns the same state directory.
- The generated command targets the intended repository, issue, or PR.
