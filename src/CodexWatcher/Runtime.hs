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
  , CleanReviewEvidence (..)
  , CommitSha (..)
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
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text.Encoding
import GHC.Generics (Generic)
import System.Directory (createDirectoryIfMissing, renameFile)
import System.Exit (ExitCode (..))
import System.FilePath (takeDirectory)
import System.Process.Typed qualified as Process.Typed

data RuntimeCommand
  = CommandVersion String
  | GhAuthStatus
  | GhApiUser
  | GhIssueListOpen RepoName
  | GhIssueView RepoName IssueNumber [Text]
  | GhIssueCreate RepoName IssueCreationRequest
  | GhPrListOpen RepoName
  | GhPrView RepoName PrNumber [Text]
  | GhPrChecks RepoName PrNumber
  | GhReviewThreads PrConfig
  | GhCreatePullRequest FilePath IssueConfig
  | GhUpdatePullRequestBody FilePath IssueConfig PrNumber FilePath
  | GhResolveReviewThread ReviewThreadId
  | GhPrMerge RepoName PrNumber Text
  | GhPrCommentReviewAndMerge RepoName PrNumber CleanReviewEvidence Text
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
renderRuntimeCommand (GhPrChecks repo prNumber) =
  RuntimeCommandSpec
    "gh"
    [ "pr"
    , "checks"
    , show (unPrNumber prNumber)
    , "--repo"
    , Text.unpack (unRepoName repo)
    , "--required"
    , "--json"
    , "name,state,bucket"
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
renderRuntimeCommand (GhPrCommentReviewAndMerge repo prNumber evidence mergeMethod) =
  RuntimeCommandSpec
    "bash"
    [ "-lc"
    , Text.unpack commentReviewAndMergeScript
    , "codex-watcher-gh-pr-comment-review-and-merge"
    , show (unPrNumber prNumber)
    , Text.unpack (unRepoName repo)
    , mergeFlag mergeMethod
    ]
    Nothing
    (cleanReviewBody evidence)
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
    , "body=$(printf 'Implements #%s.\\n\\nCreated by codex-watcher after the issue planning turn. Implementation commits will be pushed to this PR.' \"$issue\")"
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
    , "if [ ! -s \"$plan_path\" ]; then"
    , "  printf 'issue plan file missing or empty: %s\\n' \"$plan_path\" >&2"
    , "  exit 1"
    , "fi"
    , "body_file=$(mktemp)"
    , "trap 'rm -f \"$body_file\"' EXIT"
    , "{"
    , "  printf 'Implements #%s.\\n\\n' \"$issue\""
    , "  printf '## Implementation Plan\\n\\n'"
    , "  cat \"$plan_path\""
    , "  printf '\\n\\n---\\nCreated by codex-watcher after the issue planning turn. Implementation commits will be pushed to this PR.\\n'"
    , "} > \"$body_file\""
    , "gh pr edit \"$pr\" --repo \"$repo\" --body-file \"$body_file\" >/dev/null"
    , "printf '{\"status\":\"updated\",\"prNumber\":%s}\\n' \"$pr\""
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

commentReviewAndMergeScript :: Text
commentReviewAndMergeScript =
  Text.unlines
    [ "set -euo pipefail"
    , "pr_number=\"$1\""
    , "repo=\"$2\""
    , "merge_flag=\"$3\""
    , "gh pr review \"$pr_number\" --repo \"$repo\" --comment --body-file -"
    , "gh pr merge \"$pr_number\" --repo \"$repo\" \"$merge_flag\""
    ]

cleanReviewBody :: CleanReviewEvidence -> Text
cleanReviewBody evidence =
  Text.unlines
    [ cleanReviewComment evidence
    , ""
    , "Reviewed commit: `" <> unCommitSha (cleanReviewCommit evidence) <> "`"
    , ""
    , "Submitted by Haskell PR review watcher before merge."
    ]

runRuntimeCommand :: RuntimeCommand -> IO CommandReport
runRuntimeCommand = runProcessSpec . renderRuntimeCommand

commandSummary :: String -> [String] -> Maybe FilePath -> IO CommandReport
commandSummary command' args' cwd' =
  runRuntimeCommand (RawCommand command' args' cwd')

runProcessSpec :: RuntimeCommandSpec -> IO CommandReport
runProcessSpec spec = do
  result <-
    try (Process.Typed.readProcess (processConfigFromSpec spec))
      :: IO (Either IOException (ExitCode, LazyByteString.ByteString, LazyByteString.ByteString))
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
        , stdout = redact (Text.strip (Text.Encoding.decodeUtf8 (LazyByteString.toStrict stdout')))
        , stderr = redact (Text.strip (Text.Encoding.decodeUtf8 (LazyByteString.toStrict stderr')))
        , errorMessage = Nothing
        }

processConfigFromSpec :: RuntimeCommandSpec -> Process.Typed.ProcessConfig () () ()
processConfigFromSpec spec =
  setCwd spec.cwd $
    Process.Typed.setStdin (Process.Typed.byteStringInput (LazyByteString.fromStrict (Text.Encoding.encodeUtf8 spec.stdin))) $
      Process.Typed.proc spec.command spec.args
 where
  setCwd Nothing = id
  setCwd (Just cwd') = Process.Typed.setWorkingDir cwd'

readJsonValue :: FilePath -> IO (Either Text Value)
readJsonValue path = do
  bytesResult <- try (ByteString.readFile path) :: IO (Either IOException ByteString.ByteString)
  pure case bytesResult of
    Left error' -> Left (Text.pack (show error'))
    Right bytes -> either (Left . Text.pack) Right (eitherDecodeStrict' bytes)

writeJsonValue :: FilePath -> Value -> IO ()
writeJsonValue path value = do
  createDirectoryIfMissing True (takeDirectory path)
  let tmpPath = path <> ".tmp"
  LazyByteString.writeFile tmpPath (encode value)
  renameFile tmpPath path

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
