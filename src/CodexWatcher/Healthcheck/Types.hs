{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE PatternSynonyms #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE StandaloneKindSignatures #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}
{-# OPTIONS_GHC -Wno-unused-top-binds #-}

module CodexWatcher.Healthcheck.Types
  ( AppServerThreadReport (..)
  , ConfigItem (..)
  , EventReplayReport (..)
  , GenericConfig (..)
  , HealthcheckOptions (..)
  , PidReport (..)
  , Problem (..)
  , RemotePrReport (..)
  , SWatcherKind (..)
  , SomeConfigItem
  , SomeWatcherSummary
  , WatcherKind (..)
  , WatcherKindDomain
  , WatcherSummary (..)
  , WorkdirReport (..)
  , expectedDomain
  , pattern SomeConfigItem
  , pattern SomeWatcherSummary
  , someConfigKind
  , someSummaryKind
  , someWatcherKind
  , watcherKindDomainMatches
  , watcherKindValue
  , withSomeWatcher
  ) where

import CodexWatcher.AppServerClient (AppServerEndpoint)
import CodexWatcher.Runtime (CommandReport)
import CodexWatcher.Types (Domain (..), SDomain (..), SomeWatcherState, someDomainIs)
import Data.Aeson (FromJSON (..), ToJSON (..), Value (..), withObject, (.:?))
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Kind (Type)
import Data.Singletons (SingKind (..))
import Data.Singletons.TH (genSingletons)
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

$(genSingletons [''WatcherKind])

type WatcherKindDomain :: WatcherKind -> Domain
type family WatcherKindDomain kind where
  WatcherKindDomain 'IssuePlanningKind = 'IssuePlanning
  WatcherKindDomain 'IssueImplementKind = 'IssueImplement
  WatcherKindDomain 'PrReviewKind = 'PrReview

instance ToJSON WatcherKind where
  toJSON = \case
    IssuePlanningKind -> "issue-planning"
    IssueImplementKind -> "issue-implement"
    PrReviewKind -> "pr-review"

watcherKindValue :: SWatcherKind kind -> WatcherKind
watcherKindValue =
  fromSing

watcherKindDomainSing :: SWatcherKind kind -> SDomain (WatcherKindDomain kind)
watcherKindDomainSing = \case
  SIssuePlanningKind -> SIssuePlanning
  SIssueImplementKind -> SIssueImplement
  SPrReviewKind -> SPrReview

expectedDomain :: SWatcherKind kind -> Domain
expectedDomain =
  fromSing . watcherKindDomainSing

watcherKindDomainMatches :: SWatcherKind kind -> SomeWatcherState -> Bool
watcherKindDomainMatches = \case
  SIssuePlanningKind -> someDomainIs @'IssuePlanning
  SIssueImplementKind -> someDomainIs @'IssueImplement
  SPrReviewKind -> someDomainIs @'PrReview

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

data ConfigItem (kind :: WatcherKind) = ConfigItem
  { dir :: FilePath
  , configPath :: FilePath
  , config :: Either Text GenericConfig
  }
  deriving stock (Eq, Show, Generic)

data SomeWatcher (payload :: WatcherKind -> Type) where
  SomeWatcher :: SWatcherKind kind -> payload kind -> SomeWatcher payload

withSomeWatcher :: SomeWatcher payload -> (forall kind. SWatcherKind kind -> payload kind -> result) -> result
withSomeWatcher (SomeWatcher kind payload) usePayload =
  usePayload kind payload

someWatcherKind :: SomeWatcher payload -> WatcherKind
someWatcherKind (SomeWatcher kind _) =
  watcherKindValue kind

type SomeConfigItem = SomeWatcher ConfigItem

pattern SomeConfigItem :: SWatcherKind kind -> ConfigItem kind -> SomeConfigItem
pattern SomeConfigItem kind item = SomeWatcher kind item
{-# COMPLETE SomeConfigItem #-}

someConfigKind :: SomeConfigItem -> WatcherKind
someConfigKind =
  someWatcherKind

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

data WatcherSummary (kind :: WatcherKind) = WatcherSummary
  { label :: Text
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

type SomeWatcherSummary = SomeWatcher WatcherSummary

pattern SomeWatcherSummary :: SWatcherKind kind -> WatcherSummary kind -> SomeWatcherSummary
pattern SomeWatcherSummary kind summary = SomeWatcher kind summary
{-# COMPLETE SomeWatcherSummary #-}

someSummaryKind :: SomeWatcherSummary -> WatcherKind
someSummaryKind =
  someWatcherKind

instance ToJSON (SomeWatcher WatcherSummary) where
  toJSON (SomeWatcherSummary kind summary) =
    case toJSON summary of
      Object object' ->
        Object (KeyMap.insert (Key.fromString "kind") (toJSON (watcherKindValue kind)) object')
      value -> value

data Problem = Problem
  { severity :: Text
  , component :: Text
  , message :: Text
  , recommendation :: Maybe Text
  }
  deriving stock (Eq, Show, Generic)
  deriving anyclass (ToJSON)
