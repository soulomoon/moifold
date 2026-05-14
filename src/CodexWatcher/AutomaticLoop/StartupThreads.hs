{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.AutomaticLoop.StartupThreads
  ( refreshStartupThreads
  ) where

import CodexWatcher.ActionExecutor (ActionExecutionMode (..), ActionExecutor (..))
import CodexWatcher.Workflow.Agent.Codex.Client (formatAppServerClientFailure)
import CodexWatcher.Cli.Types (LoopCli (..))
import CodexWatcher.Daemon (DaemonOptions (..), appendWatcherEvent)
import CodexWatcher.DaemonLoop (DaemonLoopConfig (..))
import CodexWatcher.EffectInterpreter (EffectRuntimeConfig (..))
import CodexWatcher.EventLog.File (loadEventLogFile)
import CodexWatcher.EventLog.Replay (replayEventLog)
import CodexWatcher.EventLog.Types (EventReplayResult (..), WatcherEvent (..))
import CodexWatcher.Runtime.Interpreter (ioRuntimeInterpreter)
import CodexWatcher.Runtime.Defaults (defaultThreadStartOptions)
import CodexWatcher.TurnOutput (issueImplementerThreadDeveloperInstructions, prReviewThreadDeveloperInstructions)
import CodexWatcher.Workflow.Agent.Ids (RequestId, ThreadId, nextRequestId)
import CodexWatcher.Core.Kinds (Domain (..))
import CodexWatcher.Core.State (SomeWatcherState (..), WatcherState (..))
import CodexWatcher.Core.Thread (ActiveTurn (..), ReviewerThread (..), WorkerThread (..))
import CodexWatcher.Domain.IssueImplement.Types (IssueConfig)
import CodexWatcher.Domain.PrReview.Types (PrConfig)
import CodexWatcher.Workflow.Agent qualified as WorkflowAgent
import CodexWatcher.Workflow.Agent.Codex qualified as WorkflowAgentCodex
import Data.Text qualified as Text
import System.Exit (die)

data PrReviewStartupThreadRefresh
  = RefreshPrReviewIdleThreads PrConfig
  | RefreshPrReviewReviewerForActiveWorker PrConfig ThreadId

refreshStartupThreads :: ActionExecutor IO -> LoopCli -> ActionExecutionMode -> DaemonLoopConfig -> IO DaemonLoopConfig
refreshStartupThreads _executor cli _executionMode loopConfig
  | cli.loopCliDomain == IssuePlanning =
      pure loopConfig
refreshStartupThreads _executor _cli DryRunActions loopConfig =
  pure loopConfig
refreshStartupThreads executor cli ExecuteActions loopConfig = do
  loaded <- loadEventLogFile cli.loopCliEventsPath
  case loaded of
    Left _failure ->
      pure loopConfig
    Right events ->
      case replayEventLog events of
        Left _failure ->
          pure loopConfig
        Right replay ->
          case cli.loopCliDomain of
            IssueImplement ->
              refreshIssueImplementThread replay
            PrReview ->
              refreshPrReviewThreads replay
            IssuePlanning ->
              pure loopConfig
 where
  runtimeConfig = loopConfig.loopDaemonOptions.daemonRuntimeConfig

  refreshIssueImplementThread replay =
    case idleIssueConfig replay.replayState of
      Nothing ->
        pure loopConfig
      Just issueConfig -> do
        let requestId = runtimeConfig.effectRuntimeNextRequestId
            instructions = issueImplementerThreadDeveloperInstructions cli.loopCliWorkdir cli.loopCliStateDir issueConfig
        threadId <- startFreshThread executor WorkflowAgent.issueImplementationWorkerAgentRoleId requestId cli.loopCliWorkdir instructions
        appendStartupThreadRefresh (IssueWorkerThreadRefreshed threadId)
        pure (withNextRequestId (nextRequestId requestId) loopConfig)

  refreshPrReviewThreads replay =
    case prReviewStartupThreadRefresh replay.replayState of
      Nothing ->
        pure loopConfig
      Just (RefreshPrReviewIdleThreads prConfig) -> do
        let requestId = runtimeConfig.effectRuntimeNextRequestId
        workerThread <- startFreshThread executor WorkflowAgent.prReviewWorkerAgentRoleId requestId cli.loopCliWorkdir (prReviewThreadDeveloperInstructions cli.loopCliWorkdir cli.loopCliStateDir prConfig "worker")
        reviewerThread <- startFreshThread executor WorkflowAgent.reviewerAgentRoleId (nextRequestId requestId) cli.loopCliWorkdir (prReviewThreadDeveloperInstructions cli.loopCliWorkdir cli.loopCliStateDir prConfig "reviewer")
        appendStartupThreadRefresh (PrReviewThreadsRefreshed workerThread reviewerThread)
        pure (withNextRequestId (nextRequestId (nextRequestId requestId)) loopConfig)
      Just (RefreshPrReviewReviewerForActiveWorker prConfig workerThread) -> do
        let requestId = runtimeConfig.effectRuntimeNextRequestId
        reviewerThread <- startFreshThread executor WorkflowAgent.reviewerAgentRoleId requestId cli.loopCliWorkdir (prReviewThreadDeveloperInstructions cli.loopCliWorkdir cli.loopCliStateDir prConfig "reviewer")
        appendStartupThreadRefresh (PrReviewThreadsRefreshed workerThread reviewerThread)
        pure (withNextRequestId (nextRequestId requestId) loopConfig)

  appendStartupThreadRefresh event = do
    appendWatcherEvent ioRuntimeInterpreter cli.loopCliEventsPath event

startFreshThread :: ActionExecutor IO -> WorkflowAgent.AgentRoleId -> RequestId -> FilePath -> Text.Text -> IO ThreadId
startFreshThread executor roleId requestId cwd developerInstructions = do
  let threadPlan =
        WorkflowAgentCodex.agentThreadPlanFromThreadStartOptions
          roleId
          (defaultThreadStartOptions cwd developerInstructions)
  result <-
    WorkflowAgentCodex.startAgentThread
      executor.actionAppServer
      requestId
      threadPlan
  case result of
    Left failure -> die (Text.unpack (formatAppServerClientFailure failure))
    Right started -> pure (WorkflowAgent.agentThreadStartThreadId started)

withNextRequestId :: RequestId -> DaemonLoopConfig -> DaemonLoopConfig
withNextRequestId requestId loopConfig =
  loopConfig
    { loopDaemonOptions =
        loopConfig.loopDaemonOptions
          { daemonRuntimeConfig =
              loopConfig.loopDaemonOptions.daemonRuntimeConfig
                { effectRuntimeNextRequestId = requestId
                }
          }
    }

idleIssueConfig :: SomeWatcherState -> Maybe IssueConfig
idleIssueConfig = \case
  SomeWatcherState (IssueReadyToPlan config _prNumber (WorkerIdle _threadId)) -> Just config
  SomeWatcherState (IssuePlanReady config _prNumber (WorkerIdle _threadId)) -> Just config
  SomeWatcherState (IssueImplementationReady config _maybePr (WorkerIdle _threadId)) -> Just config
  _ -> Nothing

prReviewStartupThreadRefresh :: SomeWatcherState -> Maybe PrReviewStartupThreadRefresh
prReviewStartupThreadRefresh = \case
  SomeWatcherState (PrCheckingReviews config (WorkerIdle _workerThread) (ReviewerIdle _reviewerThread)) -> Just (RefreshPrReviewIdleThreads config)
  SomeWatcherState (PrReviewFixQueued config _evidence (WorkerIdle _workerThread) (ReviewerIdle _reviewerThread)) -> Just (RefreshPrReviewIdleThreads config)
  SomeWatcherState (PrFixingReviews config _evidence (WorkerActive (ActiveTurn workerThread _turnId)) (ReviewerIdle _reviewerThread)) -> Just (RefreshPrReviewReviewerForActiveWorker config workerThread)
  SomeWatcherState (PrVerifyingReviewFix config _evidence (WorkerIdle _workerThread) (ReviewerIdle _reviewerThread)) -> Just (RefreshPrReviewIdleThreads config)
  SomeWatcherState (PrWaitingForMergeability config _evidence (WorkerIdle _workerThread) (ReviewerIdle _reviewerThread)) -> Just (RefreshPrReviewIdleThreads config)
  _ -> Nothing
