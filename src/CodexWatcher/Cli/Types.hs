{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE LambdaCase #-}

module CodexWatcher.Cli.Types
  ( CliCommand (..)
  , AppServerProbeCli (..)
  , CliDomain
  , GuardWatcherCli (..)
  , HealthcheckCli (..)
  , IssueFanoutCli (..)
  , LoopCli (..)
  , ObserveOnceCli (..)
  , RepairInvalidStateCli (..)
  , RenderServiceCli (..)
  , StopDaemonCli (..)
  , cliDomainName
  , cliDomainToDomain
  ) where

import CodexWatcher.Workflow.Agent.Codex.Transport (AppServerEndpoint)
import CodexWatcher.Workflow.Agent.Ids (ThreadId, TurnId)
import CodexWatcher.Workflow.GitHub.Ids
  ( CommitSha
  , IssueNumber
  , PrNumber
  , ReviewThreadId
  , RepoName
  )
import CodexWatcher.Core.Kinds (Domain (..))
import CodexWatcher.Core.Limits (MaxParallel, PollSeconds, StaleSeconds)
import Data.Text (Text)
import GHC.Generics (Generic)

type CliDomain = Domain

data CliCommand
  = CliReplayEvents FilePath
  | CliProbeAppServer AppServerProbeCli
  | CliHealthcheck HealthcheckCli
  | CliClearRuntimeLease FilePath
  | CliStopDaemon StopDaemonCli
  | CliRenderService RenderServiceCli
  | CliIssueFanout IssueFanoutCli
  | CliObserveOnce ObserveOnceCli
  | CliRunLoop LoopCli
  | CliGuardWatcher GuardWatcherCli
  | CliRepairInvalidState RepairInvalidStateCli
  deriving stock (Eq, Show, Generic)

data AppServerProbeCli = AppServerProbeCli
  { appServerProbeCliEndpoint :: AppServerEndpoint
  , appServerProbeCliThreadId :: Maybe ThreadId
  , appServerProbeCliCreateSmokeThread :: Bool
  , appServerProbeCliStartSmokeTurn :: Bool
  , appServerProbeCliWorkdir :: FilePath
  }
  deriving stock (Eq, Show, Generic)

data HealthcheckCli = HealthcheckCli
  { healthcheckCliStateRoot :: FilePath
  , healthcheckCliRepo :: Maybe RepoName
  , healthcheckCliEndpoint :: Maybe AppServerEndpoint
  }
  deriving stock (Eq, Show, Generic)

data StopDaemonCli = StopDaemonCli
  { stopDaemonCliPidFile :: Maybe FilePath
  , stopDaemonCliStateDir :: Maybe FilePath
  , stopDaemonCliDomain :: Maybe Domain
  }
  deriving stock (Eq, Show, Generic)

data RenderServiceCli = RenderServiceCli
  { renderServiceCliName :: Text
  , renderServiceCliDomain :: Domain
  , renderServiceCliEventsPath :: FilePath
  , renderServiceCliStateDir :: FilePath
  , renderServiceCliRepo :: RepoName
  , renderServiceCliWorkdir :: FilePath
  , renderServiceCliEndpoint :: AppServerEndpoint
  , renderServiceCliExecutable :: Maybe FilePath
  , renderServiceCliPlannerThread :: Maybe ThreadId
  , renderServiceCliPollSeconds :: PollSeconds
  , renderServiceCliLogDir :: Maybe FilePath
  , renderServiceCliRestartSeconds :: Int
  , renderServiceCliRotateCount :: Int
  , renderServiceCliImplementersRoot :: Maybe FilePath
  }
  deriving stock (Eq, Show, Generic)

data IssueFanoutCli = IssueFanoutCli
  { issueFanoutCliRepo :: RepoName
  , issueFanoutCliImplementersRoot :: FilePath
  , issueFanoutCliMaxParallel :: MaxParallel
  , issueFanoutCliOpenIssues :: Maybe [IssueNumber]
  , issueFanoutCliActiveIssues :: Maybe [IssueNumber]
  , issueFanoutCliExecute :: Bool
  , issueFanoutCliEndpoint :: Maybe AppServerEndpoint
  , issueFanoutCliWorkdirRoot :: Maybe FilePath
  , issueFanoutCliBranchPrefix :: Text
  , issueFanoutCliThreadPrefix :: Text
  , issueFanoutCliPollSeconds :: Maybe PollSeconds
  }
  deriving stock (Eq, Show, Generic)

data ObserveOnceCli = ObserveOnceCli
  { observeCliEventsPath :: FilePath
  , observeCliStateDir :: FilePath
  , observeCliRepo :: RepoName
  , observeCliWorkdir :: FilePath
  , observeCliDomain :: Domain
  , observeCliObservation :: String
  , observeCliExecute :: Bool
  , observeCliEndpoint :: Maybe AppServerEndpoint
  , observeCliThreadId :: Maybe ThreadId
  , observeCliTurnId :: Maybe TurnId
  , observeCliImplementationTurnId :: Maybe TurnId
  , observeCliPrNumber :: Maybe PrNumber
  , observeCliCommitSha :: Maybe CommitSha
  , observeCliMergeCommitSha :: Maybe CommitSha
  , observeCliReason :: Maybe Text
  , observeCliPlanMarkdown :: Maybe Text
  , observeCliReviewThreadIds :: [ReviewThreadId]
  , observeCliComment :: Maybe Text
  }
  deriving stock (Eq, Show, Generic)

data RepairInvalidStateCli = RepairInvalidStateCli
  { repairCliEventsPath :: FilePath
  , repairCliStateDir :: FilePath
  , repairCliExecute :: Bool
  }
  deriving stock (Eq, Show, Generic)

data LoopCli = LoopCli
  { loopCliDomain :: Domain
  , loopCliEventsPath :: FilePath
  , loopCliStateDir :: FilePath
  , loopCliRepo :: RepoName
  , loopCliWorkdir :: FilePath
  , loopCliEndpoint :: AppServerEndpoint
  , loopCliPollSeconds :: PollSeconds
  , loopCliExecute :: Bool
  , loopCliLoop :: Bool
  , loopCliIterations :: Maybe Int
  , loopCliPidFile :: Maybe FilePath
  , loopCliPlannerThread :: Maybe ThreadId
  , loopCliScopeIssues :: [IssueNumber]
  , loopCliImplementersRoot :: Maybe FilePath
  , loopCliOpenIssues :: Maybe [IssueNumber]
  , loopCliActiveIssues :: Maybe [IssueNumber]
  , loopCliImplementerWorkdirRoot :: Maybe FilePath
  , loopCliWorkdirRoot :: Maybe FilePath
  , loopCliBranchPrefix :: Text
  , loopCliThreadPrefix :: Text
  }
  deriving stock (Eq, Show, Generic)

data GuardWatcherCli = GuardWatcherCli
  { guardCliLoop :: LoopCli
  , guardCliPidFile :: Maybe FilePath
  , guardCliPollSeconds :: PollSeconds
  , guardCliStaleSeconds :: StaleSeconds
  , guardCliRepairCwd :: Maybe FilePath
  }
  deriving stock (Eq, Show, Generic)

cliDomainName :: CliDomain -> String
cliDomainName = \case
  PrReview -> "pr-review"
  IssueImplement -> "issue-implement"
  IssuePlanning -> "issue-planning"

cliDomainToDomain :: CliDomain -> Domain
cliDomainToDomain = id
