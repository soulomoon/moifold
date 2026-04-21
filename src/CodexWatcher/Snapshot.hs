{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Snapshot
  ( NodePrReviewConfig (..)
  , NodeIssueImplementConfig (..)
  , NodeCheckerResult (..)
  , NodeWatcherState (..)
  , NodeCheckerState (..)
  , NodeAgentState (..)
  , NodeReviewerState (..)
  , NodeIssueState (..)
  , NodeIssueDaemonState (..)
  , NodeBlockedState (..)
  , NodePrReviewSnapshot (..)
  , NodeIssueImplementSnapshot (..)
  , NodeSnapshot (..)
  , loadNodePrReviewSnapshot
  , loadNodeIssueImplementSnapshot
  , loadNodeSnapshot
  ) where

import CodexWatcher.Json
import Data.Aeson
  ( FromJSON (..)
  , withObject
  , (.:)
  , (.:?)
  , (.!=)
  )
import Data.Text (Text)
import GHC.Generics (Generic)
import System.FilePath ((</>))

data NodePrReviewConfig = NodePrReviewConfig
  { repoFullName :: Text
  , prNumber :: Int
  , branch :: Text
  , threadId :: Text
  , reviewerThreadId :: Maybe Text
  }
  deriving stock (Eq, Show, Generic)

instance FromJSON NodePrReviewConfig where
  parseJSON = withObject "NodePrReviewConfig" \object ->
    NodePrReviewConfig
      <$> object .: "repoFullName"
      <*> object .: "prNumber"
      <*> object .: "branch"
      <*> object .: "threadId"
      <*> object .:? "reviewerThreadId"

data NodeIssueImplementConfig = NodeIssueImplementConfig
  { repoFullName :: Text
  , issueNumber :: Int
  , branch :: Text
  , threadId :: Text
  }
  deriving stock (Eq, Show, Generic)

instance FromJSON NodeIssueImplementConfig where
  parseJSON = withObject "NodeIssueImplementConfig" \object ->
    NodeIssueImplementConfig
      <$> object .: "repoFullName"
      <*> object .: "issueNumber"
      <*> object .: "branch"
      <*> object .: "threadId"

data NodeCheckerResult = NodeCheckerResult
  { hasUnresolved :: Bool
  , unresolvedCount :: Int
  , unresolvedThreadIds :: [Text]
  }
  deriving stock (Eq, Show, Generic)

instance FromJSON NodeCheckerResult where
  parseJSON = withObject "NodeCheckerResult" \object ->
    NodeCheckerResult
      <$> object .: "has_unresolved"
      <*> object .: "unresolved_count"
      <*> object .: "unresolved_thread_ids"

data NodeWatcherState = NodeWatcherState
  { lastTurnStatus :: Maybe Text
  , lastReviewTargetSha :: Maybe Text
  , lastReviewerTargetSha :: Maybe Text
  , blockedReason :: Maybe Text
  , lastCheckerResult :: Maybe NodeCheckerResult
  }
  deriving stock (Eq, Show, Generic)

instance FromJSON NodeWatcherState where
  parseJSON = withObject "NodeWatcherState" \object ->
    NodeWatcherState
      <$> object .:? "lastTurnStatus"
      <*> object .:? "lastReviewTargetSha"
      <*> object .:? "lastReviewerTargetSha"
      <*> object .:? "blockedReason"
      <*> object .:? "lastCheckerResult"

data NodeCheckerState = NodeCheckerState
  { hasUnresolved :: Bool
  , unresolvedCount :: Int
  , unresolvedThreadIds :: [Text]
  }
  deriving stock (Eq, Show, Generic)

instance FromJSON NodeCheckerState where
  parseJSON = withObject "NodeCheckerState" \object ->
    NodeCheckerState
      <$> object .: "has_unresolved"
      <*> object .: "unresolved_count"
      <*> object .: "unresolved_thread_ids"

data NodeAgentState = NodeAgentState
  { completionStatus :: Maybe Text
  , publishedCommitSha :: Maybe Text
  , resolvedThreadIds :: [Text]
  , remainingUnresolvedThreadIds :: [Text]
  , blockedReason :: Maybe Text
  }
  deriving stock (Eq, Show, Generic)

instance FromJSON NodeAgentState where
  parseJSON = withObject "NodeAgentState" \object ->
    NodeAgentState
      <$> object .:? "completion_status"
      <*> object .:? "published_commit_sha"
      <*> object .:? "resolved_thread_ids" .!= []
      <*> object .:? "remaining_unresolved_thread_ids" .!= []
      <*> object .:? "blocked_reason"

data NodeReviewerState = NodeReviewerState
  { reviewStatus :: Maybe Text
  , reviewedCommitSha :: Maybe Text
  , addedReviewCommentCount :: Maybe Int
  , blockedReason :: Maybe Text
  }
  deriving stock (Eq, Show, Generic)

instance FromJSON NodeReviewerState where
  parseJSON = withObject "NodeReviewerState" \object ->
    NodeReviewerState
      <$> object .:? "review_status"
      <*> object .:? "reviewed_commit_sha"
      <*> object .:? "added_review_comment_count"
      <*> object .:? "blocked_reason"

data NodeIssueState = NodeIssueState
  { issueStatus :: Maybe Text
  , issuePrNumber :: Maybe Int
  , issuePrUrl :: Maybe Text
  , issueBlockedReason :: Maybe Text
  }
  deriving stock (Eq, Show, Generic)

instance FromJSON NodeIssueState where
  parseJSON = withObject "NodeIssueState" \object ->
    NodeIssueState
      <$> object .:? "issue_status"
      <*> object .:? "pr_number"
      <*> object .:? "pr_url"
      <*> object .:? "blocked_reason"

data NodeIssueDaemonState = NodeIssueDaemonState
  { activeTurnId :: Maybe Text
  , activeTurnPurpose :: Maybe Text
  , activeTurnCollaborationMode :: Maybe Text
  }
  deriving stock (Eq, Show, Generic)

instance FromJSON NodeIssueDaemonState where
  parseJSON = withObject "NodeIssueDaemonState" \object ->
    NodeIssueDaemonState
      <$> object .:? "activeTurnId"
      <*> object .:? "activeTurnPurpose"
      <*> object .:? "activeTurnCollaborationMode"

data NodeBlockedState = NodeBlockedState
  { blocked :: Bool
  , reason :: Maybe Text
  }
  deriving stock (Eq, Show, Generic)

instance FromJSON NodeBlockedState where
  parseJSON = withObject "NodeBlockedState" \object ->
    NodeBlockedState
      <$> object .: "blocked"
      <*> object .:? "reason"

data NodePrReviewSnapshot = NodePrReviewSnapshot
  { snapshotDir :: FilePath
  , config :: NodePrReviewConfig
  , watcherState :: NodeWatcherState
  , checkerState :: Maybe NodeCheckerState
  , agentState :: Maybe NodeAgentState
  , reviewerState :: Maybe NodeReviewerState
  , blockedState :: Maybe NodeBlockedState
  }
  deriving stock (Eq, Show, Generic)

data NodeIssueImplementSnapshot = NodeIssueImplementSnapshot
  { snapshotDir :: FilePath
  , config :: NodeIssueImplementConfig
  , daemonState :: Maybe NodeIssueDaemonState
  , issueState :: Maybe NodeIssueState
  , blockedState :: Maybe NodeBlockedState
  }
  deriving stock (Eq, Show, Generic)

data NodeSnapshot
  = NodePrReview NodePrReviewSnapshot
  | NodeIssueImplement NodeIssueImplementSnapshot
  deriving stock (Eq, Show, Generic)

loadNodePrReviewSnapshot :: FilePath -> IO (Either String NodePrReviewSnapshot)
loadNodePrReviewSnapshot dir = do
  configResult <- decodeJsonFile (dir </> "config.json")
  watcherResult <- decodeJsonFile (dir </> "watcher-state.json")
  checkerResult <- decodeOptionalJsonFile (dir </> "checker-state.json")
  agentResult <- decodeOptionalJsonFile (dir </> "agent-state.json")
  reviewerResult <- decodeOptionalJsonFile (dir </> "reviewer-state.json")
  blockedResult <- decodeOptionalJsonFile (dir </> "block-state.json")
  pure do
    config <- configResult
    watcherState <- watcherResult
    checkerState <- checkerResult
    agentState <- agentResult
    reviewerState <- reviewerResult
    blockedState <- blockedResult
    Right NodePrReviewSnapshot { snapshotDir = dir, config, watcherState, checkerState, agentState, reviewerState, blockedState }

loadNodeIssueImplementSnapshot :: FilePath -> IO (Either String NodeIssueImplementSnapshot)
loadNodeIssueImplementSnapshot dir = do
  configResult <- decodeJsonFile (dir </> "config.json")
  daemonResult <- decodeOptionalJsonFile (dir </> "daemon-state.json")
  issueResult <- decodeOptionalJsonFile (dir </> "issue-state.json")
  blockedResult <- decodeOptionalJsonFile (dir </> "block-state.json")
  pure do
    config <- configResult
    daemonState <- daemonResult
    issueState <- issueResult
    blockedState <- blockedResult
    Right NodeIssueImplementSnapshot { snapshotDir = dir, config, daemonState, issueState, blockedState }

loadNodeSnapshot :: FilePath -> IO (Either String NodeSnapshot)
loadNodeSnapshot dir = do
  prReviewResult <- loadNodePrReviewSnapshot dir
  case prReviewResult of
    Right snapshot -> pure (Right (NodePrReview snapshot))
    Left prReviewError -> do
      issueResult <- loadNodeIssueImplementSnapshot dir
      pure case issueResult of
        Right snapshot -> Right (NodeIssueImplement snapshot)
        Left issueError ->
          Left ("not a supported Node watcher snapshot; PR review error: " <> prReviewError <> "; issue implement error: " <> issueError)
