{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Healthcheck.Types
  ( AppServerThreadReport (..)
  , ConfigItem (..)
  , EventReplayReport (..)
  , GenericConfig (..)
  , HealthcheckOptions (..)
  , PidReport (..)
  , Problem (..)
  , RemotePrReport (..)
  , WatcherKind (..)
  , WatcherSummary (..)
  , WorkdirReport (..)
  , expectedDomain
  ) where

import CodexWatcher.AppServerClient (AppServerEndpoint)
import CodexWatcher.Runtime (CommandReport)
import CodexWatcher.Types (Domain (..))
import Data.Aeson (FromJSON (..), ToJSON (..), Value, withObject, (.:?))
import Data.Text (Text)
import GHC.Generics (Generic)

data HealthcheckOptions = HealthcheckOptions
  { stateRoot :: FilePath
  , repoFilter :: Maybe Text
  , appServerEndpoint :: Maybe AppServerEndpoint
  }
  deriving stock (Eq, Show, Generic)

data WatcherKind
  = IssuePlanningKind
  | IssueImplementKind
  | PrReviewKind
  deriving stock (Eq, Ord, Show, Generic)

instance ToJSON WatcherKind where
  toJSON = \case
    IssuePlanningKind -> "issue-planning"
    IssueImplementKind -> "issue-implement"
    PrReviewKind -> "pr-review"

data GenericConfig = GenericConfig
  { repoFullName :: Maybe Text
  , issueNumber :: Maybe Int
  , prNumber :: Maybe Int
  , branch :: Maybe Text
  , workdir :: Maybe FilePath
  , stateDir :: Maybe FilePath
  , pidPath :: Maybe FilePath
  , eventsPath :: Maybe FilePath
  , threadId :: Maybe Text
  , reviewerThreadId :: Maybe Text
  , reviewWhenClean :: Maybe Bool
  , maxParallel :: Maybe Int
  , handoffReview :: Maybe Bool
  , runtimeOwner :: Maybe Text
  }
  deriving stock (Eq, Show, Generic)

instance FromJSON GenericConfig where
  parseJSON = withObject "GenericConfig" \object' ->
    GenericConfig
      <$> object' .:? "repoFullName"
      <*> object' .:? "issueNumber"
      <*> object' .:? "prNumber"
      <*> object' .:? "branch"
      <*> object' .:? "workdir"
      <*> object' .:? "stateDir"
      <*> object' .:? "pidPath"
      <*> object' .:? "eventsPath"
      <*> object' .:? "threadId"
      <*> object' .:? "reviewerThreadId"
      <*> object' .:? "reviewWhenClean"
      <*> object' .:? "maxParallel"
      <*> object' .:? "handoffReview"
      <*> object' .:? "runtimeOwner"

data ConfigItem = ConfigItem
  { kind :: WatcherKind
  , dir :: FilePath
  , configPath :: FilePath
  , config :: Either Text GenericConfig
  }
  deriving stock (Eq, Show, Generic)

data WorkdirReport = WorkdirReport
  { skipped :: Bool
  , reason :: Maybe Text
  , path :: Maybe FilePath
  , exists :: Bool
  , isGitCheckout :: Bool
  , currentBranch :: Maybe Text
  , headSha :: Maybe Text
  , remoteHeadSha :: Maybe Text
  , localDiffersFromRemote :: Bool
  , dirty :: Bool
  , dirtyStatus :: Maybe Text
  }
  deriving stock (Eq, Show, Generic)
  deriving anyclass (ToJSON)

data EventReplayReport = EventReplayReport
  { skipped :: Bool
  , ok :: Bool
  , reason :: Maybe Text
  , eventsPath :: Maybe FilePath
  , domain :: Maybe Text
  , phase :: Maybe Text
  , eventCount :: Maybe Int
  , effectBatchCount :: Maybe Int
  }
  deriving stock (Eq, Show, Generic)
  deriving anyclass (ToJSON)

data RemotePrReport = RemotePrReport
  { skipped :: Bool
  , ok :: Bool
  , errorMessage :: Maybe Text
  , raw :: Value
  , merged :: Bool
  }
  deriving stock (Eq, Show, Generic)
  deriving anyclass (ToJSON)

data PidReport = PidReport
  { pidPath :: FilePath
  , pid :: Maybe Text
  , running :: Bool
  }
  deriving stock (Eq, Show, Generic)
  deriving anyclass (ToJSON)

data AppServerThreadReport = AppServerThreadReport
  { skipped :: Bool
  , ok :: Bool
  , threadId :: Maybe Text
  , reason :: Maybe Text
  , turnCount :: Maybe Int
  , latestTurnId :: Maybe Text
  , latestTurnStatus :: Maybe Text
  }
  deriving stock (Eq, Show, Generic)
  deriving anyclass (ToJSON)

data WatcherSummary = WatcherSummary
  { kind :: WatcherKind
  , label :: Text
  , configPath :: FilePath
  , configLoadError :: Maybe Text
  , repoFullName :: Maybe Text
  , issueNumber :: Maybe Int
  , prNumber :: Maybe Int
  , branch :: Maybe Text
  , workdirPath :: Maybe FilePath
  , threadId :: Maybe Text
  , reviewerThreadId :: Maybe Text
  , reviewWhenClean :: Maybe Bool
  , maxParallel :: Maybe Int
  , runtimeOwner :: Maybe Text
  , pid :: PidReport
  , issueStatus :: Maybe Text
  , blocked :: Bool
  , blockedReason :: Maybe Text
  , workdir :: WorkdirReport
  , gitPushDryRun :: CommandReport
  , remotePr :: RemotePrReport
  , eventReplay :: EventReplayReport
  , workerThreadInspection :: AppServerThreadReport
  , reviewerThreadInspection :: AppServerThreadReport
  , states :: Value
  }
  deriving stock (Eq, Show, Generic)
  deriving anyclass (ToJSON)

data Problem = Problem
  { severity :: Text
  , component :: Text
  , message :: Text
  , recommendation :: Maybe Text
  }
  deriving stock (Eq, Show, Generic)
  deriving anyclass (ToJSON)

expectedDomain :: WatcherKind -> Domain
expectedDomain IssuePlanningKind = IssuePlanning
expectedDomain IssueImplementKind = IssueImplement
expectedDomain PrReviewKind = PrReview
