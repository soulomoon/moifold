{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Runtime
  ( CommandReport (..)
  , RuntimeCommand (..)
  , RuntimeCommandSpec (..)
  , RuntimeInterpreter (..)
  , appendJsonLine
  , commandSummary
  , commandText
  , ioRuntimeInterpreter
  , readJsonValue
  , redact
  , renderRuntimeCommand
  , runProcessSpec
  , runRuntimeCommand
  , skippedCommand
  , writeJsonValue
  ) where

import CodexWatcher.Types
  ( BranchName (..)
  , IssueCreationRequest (..)
  , IssueConfig (..)
  , IssueNumber (..)
  , PrNumber (..)
  , PrConfig (..)
  , RepoName (..)
  , ReviewThreadId (..)
  )
import Control.Exception (IOException, try)
import Data.Aeson
  ( ToJSON
  , Value
  , eitherDecodeStrict'
  , encode
  )
import Data.ByteString qualified as ByteString
import Data.ByteString.Lazy.Char8 qualified as LazyByteString
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)
import System.Exit (ExitCode (..))
import System.Process qualified as Process

data RuntimeCommand
  = CommandVersion String
  | GhAuthStatus
  | GhApiUser
  | GhIssueListOpen RepoName
  | GhIssueView RepoName IssueNumber [Text]
  | GhIssueCreate RepoName IssueCreationRequest
  | GhPrListOpen RepoName
  | GhPrView RepoName PrNumber [Text]
  | GhReviewThreads PrConfig
  | GhCreatePullRequest FilePath IssueConfig
  | GhResolveReviewThread ReviewThreadId
  | GhPrMerge RepoName PrNumber Text
  | GitBranchCurrent FilePath
  | GitRevParseHead FilePath
  | GitStatusPorcelain FilePath
  | GitLsRemoteBranch FilePath BranchName
  | GitPushDryRun FilePath BranchName
  | GitPush FilePath BranchName
  | KillZero Text
  | KillTerm Text
  | RawCommand String [String] (Maybe FilePath)
  deriving stock (Eq, Show, Generic)

data RuntimeCommandSpec = RuntimeCommandSpec
  { command :: String
  , args :: [String]
  , cwd :: Maybe FilePath
  , stdin :: Text
  }
  deriving stock (Eq, Show, Generic)

data CommandReport = CommandReport
  { ok :: Bool
  , status :: Maybe Int
  , stdout :: Text
  , stderr :: Text
  , errorMessage :: Maybe Text
  }
  deriving stock (Eq, Show, Generic)
  deriving anyclass (ToJSON)

data RuntimeInterpreter m = RuntimeInterpreter
  { runtimeRunCommand :: RuntimeCommand -> m CommandReport
  , runtimeReadJsonValue :: FilePath -> m (Either Text Value)
  , runtimeWriteJsonValue :: FilePath -> Value -> m ()
  , runtimeAppendJsonLine :: FilePath -> Value -> m ()
  }

ioRuntimeInterpreter :: RuntimeInterpreter IO
ioRuntimeInterpreter =
  RuntimeInterpreter
    { runtimeRunCommand = runRuntimeCommand
    , runtimeReadJsonValue = readJsonValue
    , runtimeWriteJsonValue = writeJsonValue
    , runtimeAppendJsonLine = appendJsonLine
    }

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
renderRuntimeCommand (GhPrListOpen repo) =
  RuntimeCommandSpec
    "gh"
    ["pr", "list", "--repo", Text.unpack (unRepoName repo), "--state", "open", "--json", "number,title,headRefName,headRefOid"]
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
    , "  printf 'PR #%s already exists for %s\\n' \"$existing\" \"$branch\""
    , "  exit 0"
    , "fi"
    , "git fetch origin --prune >/dev/null"
    , "git checkout -B \"$branch\""
    , "git config user.email >/dev/null || git config user.email codex-watcher@users.noreply.github.com"
    , "git config user.name >/dev/null || git config user.name codex-watcher"
    , "base=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD || true)"
    , "if [ -z \"$base\" ]; then base=\"origin/main\"; fi"
    , "if ! git rev-parse --verify \"$base\" >/dev/null 2>&1; then"
    , "  base=$(git rev-list --max-parents=0 HEAD | tail -n1)"
    , "fi"
    , "if [ -z \"$(git log --oneline \"$base\"..HEAD)\" ]; then"
    , "  git commit --allow-empty -m \"Start issue #$issue implementation\""
    , "fi"
    , "git push -u origin \"$branch\""
    , "body=$(printf 'Implements #%s.\\n\\nCreated by codex-watcher after the issue planning turn. Implementation commits will be pushed to this PR.' \"$issue\")"
    , "gh pr create --repo \"$repo\" --head \"$branch\" --title \"Implement #$issue\" --body \"$body\""
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

runRuntimeCommand :: RuntimeCommand -> IO CommandReport
runRuntimeCommand = runProcessSpec . renderRuntimeCommand

commandSummary :: String -> [String] -> Maybe FilePath -> IO CommandReport
commandSummary command' args' cwd' =
  runRuntimeCommand (RawCommand command' args' cwd')

runProcessSpec :: RuntimeCommandSpec -> IO CommandReport
runProcessSpec spec = do
  result <-
    try
      (Process.readCreateProcessWithExitCode (Process.proc spec.command spec.args) {Process.cwd = spec.cwd} (Text.unpack spec.stdin))
      :: IO (Either IOException (ExitCode, String, String))
  pure case result of
    Left error' ->
      CommandReport
        { ok = False
        , status = Nothing
        , stdout = ""
        , stderr = ""
        , errorMessage = Just (Text.pack (show error'))
        }
    Right (exitCode, stdout', stderr') ->
      CommandReport
        { ok = exitCode == ExitSuccess
        , status = exitStatus exitCode
        , stdout = redact (Text.strip (Text.pack stdout'))
        , stderr = redact (Text.strip (Text.pack stderr'))
        , errorMessage = Nothing
        }

readJsonValue :: FilePath -> IO (Either Text Value)
readJsonValue path = do
  bytesResult <- try (ByteString.readFile path) :: IO (Either IOException ByteString.ByteString)
  pure case bytesResult of
    Left error' -> Left (Text.pack (show error'))
    Right bytes -> either (Left . Text.pack) Right (eitherDecodeStrict' bytes)

writeJsonValue :: FilePath -> Value -> IO ()
writeJsonValue path value =
  LazyByteString.writeFile path (encode value)

appendJsonLine :: FilePath -> Value -> IO ()
appendJsonLine path value =
  LazyByteString.appendFile path (encode value <> "\n")

skippedCommand :: Text -> CommandReport
skippedCommand reason' =
  CommandReport {ok = False, status = Nothing, stdout = "", stderr = "", errorMessage = Just reason'}

exitStatus :: ExitCode -> Maybe Int
exitStatus ExitSuccess = Just 0
exitStatus (ExitFailure code) = Just code

commandText :: CommandReport -> Text
commandText report =
  Text.intercalate " " (filter (not . Text.null) [report.stderr, report.stdout, maybe "" id report.errorMessage])

redact :: Text -> Text
redact =
  Text.unwords . fmap redactWord . Text.words
 where
  redactWord word
    | any (`Text.isPrefixOf` word) ["ghp_", "github_pat_", "gho_", "ghu_", "ghs_", "ghr_"] = "<redacted-token>"
    | otherwise = word
