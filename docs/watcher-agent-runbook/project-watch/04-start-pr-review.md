# 04 Start PR Review

Use a PR review watcher when the agent should review, fix, and merge one PR independently from an issue implementer handoff.

## Initialize state

```bash
docker exec "$WATCHER_DOCKER_CONTAINER" bash -lc '
set -euo pipefail
source /workspace/artifacts/<project>-watcher.env
cd "$WATCHER_REPO"
PR_STATE_DIR="$(scripts/watcher-init/init-pr-review-state.sh /workspace/artifacts/<project>-watcher.env)"
printf "%s\n" "$PR_STATE_DIR"
'
```

The conventional PR review state directory is:

```text
$PR_REVIEW_ROOT/<repo-slug>__pr${PR_NUMBER}
```

The repo slug follows the Haskell watcher rule: every non-alphanumeric character in `REPO_FULL_NAME` becomes `_`.

## Dry run one iteration

```bash
docker exec "$WATCHER_DOCKER_CONTAINER" bash -lc '
set -euo pipefail
source /workspace/artifacts/<project>-watcher.env
PR_STATE_DIR="$PR_REVIEW_ROOT/${REPO_FULL_NAME//[^[:alnum:]]/_}__pr${PR_NUMBER}"
"$PR_STATE_DIR/dry-run-command.sh"
'
```

## Start continuous execution

```bash
docker exec "$WATCHER_DOCKER_CONTAINER" bash -lc '
set -euo pipefail
source /workspace/artifacts/<project>-watcher.env
PR_STATE_DIR="$PR_REVIEW_ROOT/${REPO_FULL_NAME//[^[:alnum:]]/_}__pr${PR_NUMBER}"
"$PR_STATE_DIR/restart-command.sh"
'
```

Expected lifecycle:

1. Read unresolved GitHub review threads and PR review decision.
2. Start a worker turn if actionable findings exist.
3. Start reviewer turn when no unresolved findings remain.
4. Recheck mergeability and required checks.
5. Merge only after a clean reviewer outcome and clean pre-merge gate.
