{-# LANGUAGE DerivingStrategies #-}

module CodexWatcher.Domain.IssueImplement.Types
  ( IssueConfig (..)
  ) where

import CodexWatcher.Workflow.GitHub.Ids (BranchName, IssueNumber, RepoName)

data IssueConfig = IssueConfig
  { issueRepo :: RepoName
  , issueNumber :: IssueNumber
  , issueBranch :: BranchName
  }
  deriving stock (Eq, Show)
