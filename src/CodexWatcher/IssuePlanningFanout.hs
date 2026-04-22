{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.IssuePlanningFanout
  ( IssueImplementerLaunchPlan (..)
  , IssuePlanningFanoutConfig (..)
  , defaultIssuePlanningFanoutConfig
  , issueImplementerConfigJson
  , issueImplementerStateDir
  , planIssueImplementerLaunches
  ) where

import CodexWatcher.CompatibilityState
import CodexWatcher.EventLog
import CodexWatcher.IssuePlanningWatcher
import CodexWatcher.Types
import Data.Aeson (Value, object, (.=))
import Data.Char (isAlphaNum)
import Data.Text (Text)
import Data.Text qualified as Text
import System.FilePath ((</>))

data IssuePlanningFanoutConfig = IssuePlanningFanoutConfig
  { fanoutImplementersRoot :: FilePath
  , fanoutWorkdirRoot :: Maybe FilePath
  , fanoutBranchPrefix :: Text
  , fanoutThreadPrefix :: Text
  }
  deriving stock (Eq, Show)

data IssueImplementerLaunchPlan = IssueImplementerLaunchPlan
  { launchIssueConfig :: IssueConfig
  , launchThreadId :: ThreadId
  , launchStateDir :: FilePath
  , launchConfigPath :: FilePath
  , launchEventsPath :: FilePath
  , launchWorkdir :: Maybe FilePath
  , launchConfigJson :: Value
  , launchInitialEvent :: WatcherEvent
  , launchCompatibilityWrites :: [CompatibilityWrite]
  }
  deriving stock (Eq, Show)

defaultIssuePlanningFanoutConfig :: FilePath -> IssuePlanningFanoutConfig
defaultIssuePlanningFanoutConfig implementersRoot =
  IssuePlanningFanoutConfig
    { fanoutImplementersRoot = implementersRoot
    , fanoutWorkdirRoot = Nothing
    , fanoutBranchPrefix = "codex/issue-"
    , fanoutThreadPrefix = "issue-worker-"
    }

planIssueImplementerLaunches :: IssuePlanningFanoutConfig -> PlannerConfig -> [IssueNumber] -> [IssueNumber] -> [IssueImplementerLaunchPlan]
planIssueImplementerLaunches fanoutConfig plannerConfig activeIssues openIssues =
  fmap (issueImplementerLaunchPlan fanoutConfig plannerConfig) selectedIssues
 where
  selectedIssues = selectIssueImplementationStarts plannerConfig activeIssues openIssues

issueImplementerLaunchPlan :: IssuePlanningFanoutConfig -> PlannerConfig -> IssueNumber -> IssueImplementerLaunchPlan
issueImplementerLaunchPlan fanoutConfig plannerConfig issueNumber' =
  IssueImplementerLaunchPlan
    { launchIssueConfig = issueConfig
    , launchThreadId = threadId
    , launchStateDir = stateDir
    , launchConfigPath = stateDir </> "config.json"
    , launchEventsPath = stateDir </> "events.jsonl"
    , launchWorkdir = workdir
    , launchConfigJson = issueImplementerConfigJson issueConfig threadId stateDir workdir
    , launchInitialEvent = initialEvent
    , launchCompatibilityWrites = compatibilityStateWrites stateDir initialState
    }
 where
  repo = plannerRepo plannerConfig
  branch = BranchName (fanoutConfig.fanoutBranchPrefix <> Text.pack (show (unIssueNumber issueNumber')))
  issueConfig = IssueConfig repo issueNumber' branch
  threadId = ThreadId (fanoutConfig.fanoutThreadPrefix <> Text.pack (show (unIssueNumber issueNumber')))
  stateDir = issueImplementerStateDir fanoutConfig.fanoutImplementersRoot repo issueNumber'
  workdir = (</> issueImplementerSlug repo issueNumber') <$> fanoutConfig.fanoutWorkdirRoot
  initialEvent = IssueImplementInitialized issueConfig threadId
  initialState = SomeWatcherState (IssueNeedsTriage issueConfig (WorkerIdle threadId))

issueImplementerConfigJson :: IssueConfig -> ThreadId -> FilePath -> Maybe FilePath -> Value
issueImplementerConfigJson issueConfig threadId stateDir maybeWorkdir =
  object
    [ "repoFullName" .= unRepoName issueConfig.issueRepo
    , "issueNumber" .= unIssueNumber issueConfig.issueNumber
    , "branch" .= unBranchName issueConfig.issueBranch
    , "threadId" .= unThreadId threadId
    , "stateDir" .= stateDir
    , "configPath" .= (stateDir </> "config.json")
    , "eventsPath" .= (stateDir </> "events.jsonl")
    , "workdir" .= maybeWorkdir
    ]

issueImplementerStateDir :: FilePath -> RepoName -> IssueNumber -> FilePath
issueImplementerStateDir implementersRoot repo issueNumber' =
  implementersRoot </> issueImplementerSlug repo issueNumber'

issueImplementerSlug :: RepoName -> IssueNumber -> FilePath
issueImplementerSlug repo issueNumber' =
  Text.unpack (safeRepoSlug repo <> "__issue" <> Text.pack (show (unIssueNumber issueNumber')))

safeRepoSlug :: RepoName -> Text
safeRepoSlug =
  Text.map safeChar . unRepoName
 where
  safeChar char
    | isAlphaNum char = char
    | otherwise = '_'
