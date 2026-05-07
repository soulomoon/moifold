{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Workflow.GitHub.Command
  ( GitHubCommandSpec (..)
  , ghApiUserCommand
  , ghAuthStatusCommand
  , ghIssueListOpenCommand
  , ghIssueViewCommand
  , ghPrChecksCommand
  , ghPrListByHeadCommand
  , ghPrListOpenCommand
  , ghPrMergeCommand
  , ghPrViewCommand
  , ghReplyReviewThreadCommand
  , ghResolveReviewThreadCommand
  , ghReviewThreadsCommand
  , gitBranchCurrentCommand
  , gitLsRemoteBranchCommand
  , gitPushCommand
  , gitPushDryRunCommand
  , gitRevParseHeadCommand
  , gitStatusPorcelainCommand
  , mergeFlag
  ) where

import CodexWatcher.Workflow.GitHub.Ids
  ( BranchName (..)
  , IssueNumber (..)
  , PrNumber (..)
  , RepoName (..)
  , ReviewThreadId (..)
  )
import Data.Text (Text)
import Data.Text qualified as Text

data GitHubCommandSpec = GitHubCommandSpec
  { githubCommand :: String
  , githubCommandArgs :: [String]
  , githubCommandCwd :: Maybe FilePath
  , githubCommandStdin :: Text
  }
  deriving stock (Eq, Show)

ghAuthStatusCommand :: GitHubCommandSpec
ghAuthStatusCommand =
  GitHubCommandSpec "gh" ["auth", "status"] Nothing ""

ghApiUserCommand :: GitHubCommandSpec
ghApiUserCommand =
  GitHubCommandSpec "gh" ["api", "user"] Nothing ""

ghIssueListOpenCommand :: RepoName -> GitHubCommandSpec
ghIssueListOpenCommand repo =
  GitHubCommandSpec
    "gh"
    ["issue", "list", "--repo", Text.unpack (unRepoName repo), "--state", "open", "--json", "number,title,labels,assignees"]
    Nothing
    ""

ghIssueViewCommand :: RepoName -> IssueNumber -> [Text] -> GitHubCommandSpec
ghIssueViewCommand repo issueNumber fields =
  GitHubCommandSpec
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

ghPrListOpenCommand :: RepoName -> GitHubCommandSpec
ghPrListOpenCommand repo =
  GitHubCommandSpec
    "gh"
    ["pr", "list", "--repo", Text.unpack (unRepoName repo), "--state", "open", "--json", "number,title,headRefName,headRefOid,body"]
    Nothing
    ""

ghPrListByHeadCommand :: RepoName -> BranchName -> Text -> GitHubCommandSpec
ghPrListByHeadCommand repo branch state =
  GitHubCommandSpec
    "gh"
    ["pr", "list", "--repo", Text.unpack (unRepoName repo), "--head", Text.unpack (unBranchName branch), "--state", Text.unpack state, "--json", "number,title,headRefName,headRefOid,body,state"]
    Nothing
    ""

ghPrViewCommand :: RepoName -> PrNumber -> [Text] -> GitHubCommandSpec
ghPrViewCommand repo prNumber fields =
  GitHubCommandSpec
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

ghPrChecksCommand :: RepoName -> PrNumber -> GitHubCommandSpec
ghPrChecksCommand repo prNumber =
  GitHubCommandSpec
    "gh"
    [ "pr"
    , "checks"
    , show (unPrNumber prNumber)
    , "--repo"
    , Text.unpack (unRepoName repo)
    , "--json"
    , "name,state,bucket"
    ]
    Nothing
    ""

ghReviewThreadsCommand :: RepoName -> PrNumber -> GitHubCommandSpec
ghReviewThreadsCommand repo prNumber =
  let (owner, name) = repoOwnerName repo
   in GitHubCommandSpec
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
        , "number=" <> show (unPrNumber prNumber)
        ]
        Nothing
        ""

ghResolveReviewThreadCommand :: ReviewThreadId -> GitHubCommandSpec
ghResolveReviewThreadCommand reviewThreadId =
  GitHubCommandSpec
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

ghReplyReviewThreadCommand :: ReviewThreadId -> Text -> GitHubCommandSpec
ghReplyReviewThreadCommand reviewThreadId comment =
  GitHubCommandSpec
    "gh"
    [ "api"
    , "graphql"
    , "-f"
    , "query=mutation($threadId:ID!,$body:String!){addPullRequestReviewThreadReply(input:{pullRequestReviewThreadId:$threadId,body:$body}){comment{id}}}"
    , "-f"
    , "threadId=" <> Text.unpack (unReviewThreadId reviewThreadId)
    , "-f"
    , "body=" <> Text.unpack comment
    ]
    Nothing
    ""

ghPrMergeCommand :: RepoName -> PrNumber -> Text -> GitHubCommandSpec
ghPrMergeCommand repo prNumber mergeMethod =
  GitHubCommandSpec
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

gitBranchCurrentCommand :: FilePath -> GitHubCommandSpec
gitBranchCurrentCommand workdir =
  GitHubCommandSpec "git" ["branch", "--show-current"] (Just workdir) ""

gitRevParseHeadCommand :: FilePath -> GitHubCommandSpec
gitRevParseHeadCommand workdir =
  GitHubCommandSpec "git" ["rev-parse", "HEAD"] (Just workdir) ""

gitStatusPorcelainCommand :: FilePath -> GitHubCommandSpec
gitStatusPorcelainCommand workdir =
  GitHubCommandSpec "git" ["status", "--porcelain"] (Just workdir) ""

gitLsRemoteBranchCommand :: FilePath -> BranchName -> GitHubCommandSpec
gitLsRemoteBranchCommand workdir branch =
  GitHubCommandSpec "git" ["ls-remote", "origin", "refs/heads/" <> Text.unpack (unBranchName branch)] (Just workdir) ""

gitPushDryRunCommand :: FilePath -> BranchName -> GitHubCommandSpec
gitPushDryRunCommand workdir branch =
  GitHubCommandSpec "git" ["push", "--dry-run", "origin", Text.unpack (unBranchName branch)] (Just workdir) ""

gitPushCommand :: FilePath -> BranchName -> GitHubCommandSpec
gitPushCommand workdir branch =
  GitHubCommandSpec "git" ["push", "origin", Text.unpack (unBranchName branch)] (Just workdir) ""

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
  "query($owner:String!,$name:String!,$number:Int!){repository(owner:$owner,name:$name){pullRequest(number:$number){reviewThreads(first:100){nodes{id,isResolved,isOutdated,path,line,startLine,comments(first:20){nodes{id,url,body,path,line,author{login}}}}}}}}"
