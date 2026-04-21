{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Snapshot
  ( NodePrReviewConfig (..)
  , NodeCheckerResult (..)
  , NodeWatcherState (..)
  , NodeCheckerState (..)
  , NodeAgentState (..)
  , NodeReviewerState (..)
  , NodeBlockedState (..)
  , NodePrReviewSnapshot (..)
  , loadNodePrReviewSnapshot
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
