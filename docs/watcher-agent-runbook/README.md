# Codex Watcher Agent Runbook

This bundle gives another agent enough context to set up the `moifold` watcher runtime in a persistent Docker container, then use that same container to watch a target GitHub project, issue, or PR.

The runbook has two operational layers plus one maintenance validation page:

1. `moifold-setup/README.md`: one-time watcher runtime setup. This builds the Docker setup image, starts a long-lived watcher container, installs/selects `ghcup`/`ghc`/`cabal` inside that container, builds the watcher, resolves `WATCHER_BIN`, and verifies Codex app-server reachability from inside the container.
2. `project-watch/README.md`: per-target-project setup and watcher operation. This covers the project env file using container paths, GitHub access from inside the container, target dependency checks inside the container, state initialization, dry runs, execute loops, and resume.
3. `runbook-validation.md`: maintainer validation for setup scripts, CLI wiring, and runbook changes.

Use this order:

1. Complete `moifold-setup/README.md` for the moifold checkout. The persistent Docker container is the only supported runtime environment.
2. Fill `templates/watcher.env.example` with container-visible paths and save it under the mounted state root, for example `/workspace/artifacts/<project>-watcher.env` inside the container.
3. Complete `project-watch/00-project-setup.md` by running the checker through `docker exec` in the persistent watcher container.
4. Continue through the relevant `project-watch/` start or resume runbook.
5. If this runbook, setup scripts, CLI parser, or watcher setup code changed, complete `runbook-validation.md` before handoff.

The helper scripts in `scripts/watcher-init/` create conventional state directories, initial `events.jsonl`, `config.json`, `dry-run-command.sh`, and `restart-command.sh` files. Run them inside the persistent watcher container and inspect the generated files before starting a long-running `--execute --loop` daemon.

Assumptions:

- The watcher repo is mounted into the persistent container, conventionally at `/work/moifold`.
- Target project repos are mounted or cloned under `/workspace/artifacts` and all setup commands run inside the persistent container.
- `gh auth status` must succeed inside the persistent container, not merely on the host.
- The app server is already running and reachable from inside the container before execute loops start. On Docker Desktop, a host app-server normally uses `APP_SERVER_HOST=host.docker.internal`.
- State lives under `/workspace/artifacts` inside the container by default.
