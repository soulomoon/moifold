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
{-# LANGUAGE FlexibleInstances #-}

module CodexWatcher.Healthcheck.Types
  ( AppServerThreadReport (..)
  , ConfigItem (..)
  , EventReplayReport (..)
  , GenericConfig (..)
  , HealthcheckOptions (..)
  , PidReport (..)
  , Problem (..)
  , RemotePrReport (..)
  , SDomain (..)
  , SomeConfigItem
  , SomeWatcherSummary
  , WatcherSummary (..)
  , WorkdirReport (..)
  , pattern SomeConfigItem
  , pattern SomeWatcherSummary
  , someConfigDomain
  , someSummaryDomain
  , someWatcherDomain
  , watcherDomainMatches
  , watcherDomainValue
  , withSomeWatcher
  ) where

import CodexWatcher.AppServerClient (AppServerEndpoint)
import CodexWatcher.Runtime.Command.Types (CommandReport)
import CodexWatcher.Types (Domain (..), SDomain (..), SomeWatcherState, someDomain)
import Data.Aeson (FromJSON (..), ToJSON (..), Value (..), withObject, (.:?))
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Kind (Type)
import Data.Singletons (SingKind (..))
import Data.Text (Text)
import GHC.Generics (Generic)

data HealthcheckOptions = HealthcheckOptions
  { stateRoot :: FilePath
  , repoFilter :: Maybe Text
  , appServerEndpoint :: Maybe AppServerEndpoint
  }
  deriving stock (Eq, Show, Generic)

watcherDomainValue :: SDomain domain -> Domain
watcherDomainValue =
  fromSing

watcherDomainMatches :: SDomain domain -> SomeWatcherState -> Bool
watcherDomainMatches domain state =
  someDomain state == watcherDomainValue domain

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

data ConfigItem (domain :: Domain) = ConfigItem
  { dir :: FilePath
  , configPath :: FilePath
  , config :: Either Text GenericConfig
  }
  deriving stock (Eq, Show, Generic)

data SomeWatcher (payload :: Domain -> Type) where
  SomeWatcher :: SDomain domain -> payload domain -> SomeWatcher payload

withSomeWatcher :: SomeWatcher payload -> (forall domain. SDomain domain -> payload domain -> result) -> result
withSomeWatcher (SomeWatcher domain payload) usePayload =
  usePayload domain payload

someWatcherDomain :: SomeWatcher payload -> Domain
someWatcherDomain (SomeWatcher domain _) =
  watcherDomainValue domain

type SomeConfigItem = SomeWatcher ConfigItem

pattern SomeConfigItem :: SDomain domain -> ConfigItem domain -> SomeConfigItem
pattern SomeConfigItem kind item = SomeWatcher kind item
{-# COMPLETE SomeConfigItem #-}

someConfigDomain :: SomeConfigItem -> Domain
someConfigDomain =
  someWatcherDomain

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

data WatcherSummary (domain :: Domain) = WatcherSummary
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

pattern SomeWatcherSummary :: SDomain domain -> WatcherSummary domain -> SomeWatcherSummary
pattern SomeWatcherSummary kind summary = SomeWatcher kind summary
{-# COMPLETE SomeWatcherSummary #-}

someSummaryDomain :: SomeWatcherSummary -> Domain
someSummaryDomain =
  someWatcherDomain

instance ToJSON (SomeWatcher WatcherSummary) where
  toJSON (SomeWatcherSummary kind summary) =
    case toJSON summary of
      Object object' ->
        Object (KeyMap.insert (Key.fromString "kind") (toJSON (watcherDomainValue kind)) object')
      value -> value

data Problem = Problem
  { severity :: Text
  , component :: Text
  , message :: Text
  , recommendation :: Maybe Text
  }
  deriving stock (Eq, Show, Generic)
  deriving anyclass (ToJSON)
