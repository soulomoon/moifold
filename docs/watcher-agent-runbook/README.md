# Codex Watcher Agent Runbook

This bundle gives another agent enough context to set up, start, or resume typed Codex watchers for a target GitHub project and issue.

Use this order:

1. Fill `templates/watcher.env.example` and save it as a project-specific env file outside this bundle.
2. Have the operating agent complete `runbooks/00-setup-checks.md`. Prefer the Docker smoke first, then run host check-only mode and report any missing tools or dependency commands.
3. Read `runbooks/01-preflight.md`.
4. For a repository planner, follow `runbooks/02-start-issue-planning.md`.
5. For one specific issue, follow `runbooks/03-start-specific-issue.md`.
6. For a PR review watcher, follow `runbooks/04-start-pr-review.md`.
7. To resume an existing state directory, follow `runbooks/05-resume-old-state.md`.

The helper scripts in `scripts/watcher-init/` are templates. They create conventional state directories, initial `events.jsonl`, `config.json`, and `restart-command.sh` files, but they do not hide the commands from the operator. Inspect the generated files before starting a long-running `--execute --loop` daemon.

Assumptions:

- The watcher repo is the Haskell `moifold` repository.
- The target project repo is a normal Git checkout accessible to `gh`, `git`, and the app-server runtime.
- The app server is already running and reachable by host/port before execute loops start.
- State lives under `/workspace/artifacts` by default.
