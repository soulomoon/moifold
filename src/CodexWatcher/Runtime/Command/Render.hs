{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Runtime.Command.Render
  ( commandText
  , renderRuntimeCommand
  ) where

import CodexWatcher.Runtime.Command.Types
import CodexWatcher.Core.Ids
  ( BranchName (..)
  , CommitSha (..)
  , IssueNumber (..)
  , PrNumber (..)
  , RepoName (..)
  , ReviewThreadId (..)
  )
import CodexWatcher.Domain.IssueImplement.Types (IssueConfig (..))
import CodexWatcher.Domain.IssuePlanning.Types (IssueCreationRequest (..))
import CodexWatcher.Domain.PrReview.Types (CleanReviewEvidence (..), PrConfig (..), ReviewEvidence (..), reviewEvidenceSummaries, reviewEvidenceThreadIds)
import Data.Text (Text)
import Data.Text qualified as Text

renderRuntimeCommand :: RuntimeCommand -> RuntimeCommandSpec
renderRuntimeCommand (CommandVersion command') =
  RuntimeCommandSpec command' ["--version"] Nothing ""
renderRuntimeCommand GhAuthStatus =
  RuntimeCommandSpec "gh" ["auth", "status"] Nothing ""
renderRuntimeCommand GhApiUser =
  RuntimeCommandSpec "gh" ["api", "user"] Nothing ""
renderRuntimeCommand (GhIssueListOpen repo) =
  RuntimeCommandSpec
    "gh"
    ["issue", "list", "--repo", Text.unpack (unRepoName repo), "--state", "open", "--json", "number,title,labels,assignees"]
    Nothing
    ""
renderRuntimeCommand (GhIssueView repo issueNumber fields) =
  RuntimeCommandSpec
    "gh"
    [ "issue"
    , "view"
    , show (unIssueNumber issueNumber)
    , "--repo"
    , Text.unpack (unRepoName repo)
    , "--json"
    , Text.unpack (Text.intercalate "," fields)
    ]
    Nothing
    ""
renderRuntimeCommand (GhIssueCreate repo request) =
  renderGhIssueCreate repo request
renderRuntimeCommand (GhIssueClose config prNumber') =
  RuntimeCommandSpec
    "bash"
    [ "-lc"
    , Text.unpack closeIssueScript
    , "codex-watcher-gh-issue-close"
    , Text.unpack (unRepoName (issueRepo config))
    , show (unIssueNumber (issueNumber config))
    , show (unPrNumber prNumber')
    ]
    Nothing
    ""
renderRuntimeCommand (GhPrListOpen repo) =
  RuntimeCommandSpec
    "gh"
    ["pr", "list", "--repo", Text.unpack (unRepoName repo), "--state", "open", "--json", "number,title,headRefName,headRefOid,body"]
    Nothing
    ""
renderRuntimeCommand (GhPrView repo prNumber fields) =
  RuntimeCommandSpec
    "gh"
    [ "pr"
    , "view"
    , show (unPrNumber prNumber)
    , "--repo"
    , Text.unpack (unRepoName repo)
    , "--json"
    , Text.unpack (Text.intercalate "," fields)
    ]
    Nothing
    ""
renderRuntimeCommand (GhPrChecks repo prNumber) =
  RuntimeCommandSpec
    "gh"
    [ "pr"
    , "checks"
    , show (unPrNumber prNumber)
    , "--repo"
    , Text.unpack (unRepoName repo)
    , "--required"
    ]
    Nothing
    ""
renderRuntimeCommand (GhReviewThreads config) =
  let (owner, name) = repoOwnerName (prRepo config)
   in RuntimeCommandSpec
        "gh"
        [ "api"
        , "graphql"
        , "-f"
        , "query=" <> reviewThreadsQuery
        , "-f"
        , "owner=" <> Text.unpack owner
        , "-f"
        , "name=" <> Text.unpack name
        , "-F"
        , "number=" <> show (unPrNumber (prNumber config))
        ]
        Nothing
        ""
renderRuntimeCommand (GhCreatePullRequest workdir config) =
  RuntimeCommandSpec
    "bash"
    [ "-lc"
    , Text.unpack createPullRequestScript
    , "codex-watcher-gh-pr-create"
    , Text.unpack (unRepoName (issueRepo config))
    , Text.unpack (unBranchName (issueBranch config))
    , show (unIssueNumber (issueNumber config))
    ]
    (Just workdir)
    ""
renderRuntimeCommand (GhUpdatePullRequestBody workdir config prNumber planPath) =
  RuntimeCommandSpec
    "bash"
    [ "-lc"
    , Text.unpack updatePullRequestBodyScript
    , "codex-watcher-gh-pr-body-update"
    , Text.unpack (unRepoName (issueRepo config))
    , show (unPrNumber prNumber)
    , show (unIssueNumber (issueNumber config))
    , planPath
    ]
    (Just workdir)
    ""
renderRuntimeCommand (GhResolveReviewThread reviewThreadId) =
  RuntimeCommandSpec
    "gh"
    [ "api"
    , "graphql"
    , "-f"
    , "query=mutation($threadId:ID!){resolveReviewThread(input:{threadId:$threadId}){thread{id,isResolved}}}"
    , "-f"
    , "threadId=" <> Text.unpack (unReviewThreadId reviewThreadId)
    ]
    Nothing
    ""
renderRuntimeCommand (GhPrRequestChanges config evidence) =
  RuntimeCommandSpec
    "gh"
    [ "pr"
    , "review"
    , show (unPrNumber (prNumber config))
    , "--repo"
    , Text.unpack (unRepoName (prRepo config))
    , "--request-changes"
    , "--body-file"
    , "-"
    ]
    Nothing
    (requestChangesReviewBody evidence)
renderRuntimeCommand (GhPrMerge repo prNumber mergeMethod) =
  RuntimeCommandSpec
    "gh"
    [ "pr"
    , "merge"
    , show (unPrNumber prNumber)
    , "--repo"
    , Text.unpack (unRepoName repo)
    , mergeFlag mergeMethod
    ]
    Nothing
    ""
renderRuntimeCommand (GhPrApproveReviewAndMerge repo prNumber evidence mergeMethod) =
  RuntimeCommandSpec
    "bash"
    [ "-lc"
    , Text.unpack approveReviewAndMergeScript
    , "codex-watcher-gh-pr-approve-review-and-merge"
    , show (unPrNumber prNumber)
    , Text.unpack (unRepoName repo)
    , mergeFlag mergeMethod
    ]
    Nothing
    (cleanReviewBody evidence)
renderRuntimeCommand (CheckNonEmptyFile path) =
  RuntimeCommandSpec
    "bash"
    [ "-lc"
    , "set -euo pipefail; test -s \"$1\" || { printf 'file missing or empty: %s\\n' \"$1\" >&2; exit 1; }"
    , "codex-watcher-check-non-empty-file"
    , path
    ]
    Nothing
    ""
renderRuntimeCommand (GitBranchCurrent workdir) =
  RuntimeCommandSpec "git" ["branch", "--show-current"] (Just workdir) ""
renderRuntimeCommand (GitRevParseHead workdir) =
  RuntimeCommandSpec "git" ["rev-parse", "HEAD"] (Just workdir) ""
renderRuntimeCommand (GitStatusPorcelain workdir) =
  RuntimeCommandSpec "git" ["status", "--porcelain"] (Just workdir) ""
renderRuntimeCommand (GitLsRemoteBranch workdir branch) =
  RuntimeCommandSpec "git" ["ls-remote", "origin", "refs/heads/" <> Text.unpack (unBranchName branch)] (Just workdir) ""
renderRuntimeCommand (GitPushDryRun workdir branch) =
  RuntimeCommandSpec "git" ["push", "--dry-run", "origin", Text.unpack (unBranchName branch)] (Just workdir) ""
renderRuntimeCommand (GitPush workdir branch) =
  RuntimeCommandSpec "git" ["push", "origin", Text.unpack (unBranchName branch)] (Just workdir) ""
renderRuntimeCommand (KillZero pid) =
  RuntimeCommandSpec "kill" ["-0", Text.unpack pid] Nothing ""
renderRuntimeCommand (KillTerm pid) =
  RuntimeCommandSpec "kill" ["-TERM", Text.unpack pid] Nothing ""
renderRuntimeCommand (RawCommand command' args' cwd') =
  RuntimeCommandSpec command' args' cwd' ""

renderGhIssueCreate :: RepoName -> IssueCreationRequest -> RuntimeCommandSpec
renderGhIssueCreate repo request =
  case request.issueCreationParent of
    Nothing ->
      RuntimeCommandSpec
        "gh"
        [ "issue"
        , "create"
        , "--repo"
        , Text.unpack (unRepoName repo)
        , "--title"
        , Text.unpack (issueCreationTitle request)
        , "--body"
        , Text.unpack (issueCreationBody request)
        ]
        Nothing
        ""
    Just parentIssue ->
      RuntimeCommandSpec
        "bash"
        [ "-lc"
        , Text.unpack createAndLinkSubIssueScript
        , "codex-watcher-gh-sub-issue-create"
        , Text.unpack (unRepoName repo)
        , Text.unpack (issueCreationTitle request)
        , Text.unpack (issueCreationBody request)
        , show (unIssueNumber parentIssue)
        ]
        Nothing
        ""

createAndLinkSubIssueScript :: Text
createAndLinkSubIssueScript =
  Text.unlines
    [ "set -euo pipefail"
    , "repo=\"$1\""
    , "title=\"$2\""
    , "body=\"$3\""
    , "parent=\"$4\""
    , "url=$(gh issue create --repo \"$repo\" --title \"$title\" --body \"$body\")"
    , "number=\"${url##*/}\""
    , "sub_issue_id=$(gh api \"repos/$repo/issues/$number\" --jq '.id')"
    , "gh api --method POST -H 'Accept: application/vnd.github+json' -H 'X-GitHub-Api-Version: 2026-03-10' \"repos/$repo/issues/$parent/sub_issues\" -F \"sub_issue_id=$sub_issue_id\" >/dev/null"
    , "printf '%s\\n' \"$url\""
    ]

createPullRequestScript :: Text
createPullRequestScript =
  Text.unlines
    [ "set -euo pipefail"
    , "repo=\"$1\""
    , "branch=\"$2\""
    , "issue=\"$3\""
    , "existing=$(gh pr list --repo \"$repo\" --head \"$branch\" --state open --json number --jq '.[0].number // empty')"
    , "if [ -n \"$existing\" ]; then"
    , "  linked=$(gh pr view \"$existing\" --repo \"$repo\" --json body,closingIssuesReferences --jq \"(([.closingIssuesReferences[]?.number] | index($issue)) != null) or ((.body // \\\"\\\") | test(\\\"(?i)(close[sd]?|fix(e[sd])?|resolve[sd]?) +#$issue(\\\\\\\\b|[^0-9])\\\"))\")"
    , "  if [ \"$linked\" != \"true\" ]; then"
    , "    printf 'open PR #%s already uses branch %s but is not linked to issue #%s\\n' \"$existing\" \"$branch\" \"$issue\" >&2"
    , "    exit 1"
    , "  fi"
    , "  printf '{\"status\":\"reused\",\"prNumber\":%s}\\n' \"$existing\""
    , "  exit 0"
    , "fi"
    , "git fetch origin --prune >/dev/null"
    , "git checkout -B \"$branch\" >/dev/null"
    , "git config user.email >/dev/null || git config user.email codex-watcher@users.noreply.github.com"
    , "git config user.name >/dev/null || git config user.name codex-watcher"
    , "base=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD || true)"
    , "if [ -z \"$base\" ]; then base=\"origin/main\"; fi"
    , "if ! git rev-parse --verify \"$base\" >/dev/null 2>&1; then"
    , "  base=$(git rev-list --max-parents=0 HEAD | tail -n1)"
    , "fi"
    , "if [ -z \"$(git log --oneline \"$base\"..HEAD)\" ]; then"
    , "  git commit --allow-empty -m \"Start issue #$issue implementation\" >/dev/null"
    , "fi"
    , "git push -u origin \"$branch\" >/dev/null"
    , "body=$(printf 'Closes #%s.\\n\\nImplementation plan pending. The issue implementer will sync issue-plan.md into this PR before implementation starts.' \"$issue\")"
    , "url=$(gh pr create --repo \"$repo\" --head \"$branch\" --title \"Implement #$issue\" --body \"$body\")"
    , "number=\"${url##*/}\""
    , "printf '{\"status\":\"created\",\"prNumber\":%s}\\n' \"$number\""
    ]

updatePullRequestBodyScript :: Text
updatePullRequestBodyScript =
  Text.unlines
    [ "set -euo pipefail"
    , "repo=\"$1\""
    , "pr=\"$2\""
    , "issue=\"$3\""
    , "plan_path=\"$4\""
    , "body_file=$(mktemp)"
    , "trap 'rm -f \"$body_file\"' EXIT"
    , "{"
    , "  printf 'Closes #%s.\\n\\n' \"$issue\""
    , "  printf '## Implementation Plan\\n\\n'"
    , "  cat \"$plan_path\""
    , "  printf '\\n\\n---\\nImplementation plan synced by codex-watcher before implementation starts. Implementation commits will be pushed to this PR.\\n'"
    , "} > \"$body_file\""
    , "gh api --method PATCH \"repos/$repo/pulls/$pr\" -f body=\"$(cat \"$body_file\")\" >/dev/null"
    , "printf '{\"status\":\"updated\",\"prNumber\":%s}\\n' \"$pr\""
    ]

closeIssueScript :: Text
closeIssueScript =
  Text.unlines
    [ "set -euo pipefail"
    , "repo=\"$1\""
    , "issue=\"$2\""
    , "pr=\"$3\""
    , "state=$(gh issue view \"$issue\" --repo \"$repo\" --json state --jq '.state')"
    , "if [ \"$state\" != \"CLOSED\" ]; then"
    , "  gh issue comment \"$issue\" --repo \"$repo\" --body \"Implemented by merged PR #$pr.\" >/dev/null"
    , "  gh issue close \"$issue\" --repo \"$repo\" --reason completed >/dev/null"
    , "fi"
    , "printf '{\"status\":\"closed\",\"issueNumber\":%s,\"prNumber\":%s}\\n' \"$issue\" \"$pr\""
    ]

repoOwnerName :: RepoName -> (Text, Text)
repoOwnerName repo =
  case Text.breakOn "/" (unRepoName repo) of
    (owner, rest)
      | Text.null rest -> (owner, "")
      | otherwise -> (owner, Text.drop 1 rest)

mergeFlag :: Text -> String
mergeFlag "squash" = "--squash"
mergeFlag "rebase" = "--rebase"
mergeFlag _ = "--merge"

reviewThreadsQuery :: String
reviewThreadsQuery =
  "query($owner:String!,$name:String!,$number:Int!){repository(owner:$owner,name:$name){pullRequest(number:$number){reviewThreads(first:100){nodes{id,isResolved,isOutdated,path,line,startLine,comments(first:20){nodes{id,body,path,line,author{login}}}}}}}}"

approveReviewAndMergeScript :: Text
approveReviewAndMergeScript =
  Text.unlines
    [ "set -euo pipefail"
    , "pr_number=\"$1\""
    , "repo=\"$2\""
    , "merge_flag=\"$3\""
    , "gh pr review \"$pr_number\" --repo \"$repo\" --approve --body-file -"
    , "gh pr merge \"$pr_number\" --repo \"$repo\" \"$merge_flag\""
    ]

requestChangesReviewBody :: ReviewEvidence -> Text
requestChangesReviewBody evidence =
  Text.unlines
    [ "Review did not pass at commit `" <> unCommitSha evidence.reviewedCommit <> "`."
    , ""
    , "Findings to address:"
    , reviewFindingBullets evidence
    , ""
    , "Submitted by Haskell PR review watcher as a blocking request-changes review."
    ]

reviewFindingBullets :: ReviewEvidence -> Text
reviewFindingBullets evidence =
  Text.unlines
    ( summaryBullets <> threadBullets )
 where
  summaryBullets =
    ["- " <> summary | summary <- reviewEvidenceSummaries evidence]
  threadBullets =
    ["- Unresolved review thread: `" <> unReviewThreadId threadId <> "`" | threadId <- reviewEvidenceThreadIds evidence]

cleanReviewBody :: CleanReviewEvidence -> Text
cleanReviewBody evidence =
  Text.unlines
    [ cleanReviewComment evidence
    , ""
    , "Reviewed commit: `" <> unCommitSha (cleanReviewCommit evidence) <> "`"
    , ""
    , "Submitted by Haskell PR review watcher as an approving clean review before merge."
    ]

commandText :: CommandReport -> Text
commandText report =
  Text.intercalate " " (filter (not . Text.null) [report.stderr, report.stdout, maybe "" id report.errorMessage])
