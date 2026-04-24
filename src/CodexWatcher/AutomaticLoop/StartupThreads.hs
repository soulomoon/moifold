{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.AutomaticLoop.StartupThreads
  ( refreshStartupThreads
  ) where

import CodexWatcher.ActionExecutor (ActionExecutionMode (..), ActionExecutor (..))
import CodexWatcher.AppServerClient (formatAppServerClientFailure, startThreadWithInterpreter)
import CodexWatcher.Cli.Types (LoopCli (..))
import CodexWatcher.CompatibilityRuntime (writeCompatibility)
import CodexWatcher.CompatibilityState (compatibilityStateWrites)
import CodexWatcher.Daemon (DaemonOptions (..), appendWatcherEvent)
import CodexWatcher.DaemonLoop (DaemonLoopConfig (..))
import CodexWatcher.EffectInterpreter (EffectRuntimeConfig (..))
import CodexWatcher.EventLog.File (loadEventLogFile)
import CodexWatcher.EventLog.Replay (replayEventLog)
import CodexWatcher.EventLog.Types (EventReplayResult (..), WatcherEvent (..))
import CodexWatcher.ReplayCli (formatReplayFailure)
import CodexWatcher.Runtime.Interpreter (ioRuntimeInterpreter)
import CodexWatcher.Runtime.Defaults (defaultThreadStartOptions)
import CodexWatcher.TurnOutput (issueImplementerThreadDeveloperInstructions, prReviewThreadDeveloperInstructions)
import CodexWatcher.Core.Ids (RequestId, ThreadId, nextRequestId)
import CodexWatcher.Core.Kinds (Domain (..))
import CodexWatcher.Core.State (SomeWatcherState (..), WatcherState (..))
import CodexWatcher.Core.Thread (ReviewerThread (..), WorkerThread (..))
import CodexWatcher.Domain.IssueImplement.Types (IssueConfig)
import CodexWatcher.Domain.PrReview.Types (PrConfig)
import Data.Text qualified as Text
import System.Exit (die)

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
        threadId <- startFreshThread executor requestId cli.loopCliWorkdir instructions
        appendStartupThreadRefresh (IssueWorkerThreadRefreshed threadId)
        pure (withNextRequestId (nextRequestId requestId) loopConfig)

  refreshPrReviewThreads replay =
    case idlePrReviewConfig replay.replayState of
      Nothing ->
        pure loopConfig
      Just prConfig -> do
        let requestId = runtimeConfig.effectRuntimeNextRequestId
        workerThread <- startFreshThread executor requestId cli.loopCliWorkdir (prReviewThreadDeveloperInstructions cli.loopCliWorkdir cli.loopCliStateDir prConfig "worker")
        reviewerThread <- startFreshThread executor (nextRequestId requestId) cli.loopCliWorkdir (prReviewThreadDeveloperInstructions cli.loopCliWorkdir cli.loopCliStateDir prConfig "reviewer")
        appendStartupThreadRefresh (PrReviewThreadsRefreshed workerThread reviewerThread)
        pure (withNextRequestId (nextRequestId (nextRequestId requestId)) loopConfig)

  appendStartupThreadRefresh event = do
    events <- either die pure =<< loadEventLogFile cli.loopCliEventsPath
    appendWatcherEvent ioRuntimeInterpreter cli.loopCliEventsPath event
    replay <- either (die . formatReplayFailure) pure (replayEventLog (events <> [event]))
    mapM_ (writeCompatibility ioRuntimeInterpreter) (compatibilityStateWrites cli.loopCliStateDir replay.replayState)

startFreshThread :: ActionExecutor IO -> RequestId -> FilePath -> Text.Text -> IO ThreadId
startFreshThread executor requestId cwd developerInstructions = do
  result <-
    startThreadWithInterpreter
      executor.actionAppServer
      requestId
      (defaultThreadStartOptions cwd developerInstructions)
  case result of
    Left failure -> die (Text.unpack (formatAppServerClientFailure failure))
    Right threadId -> pure threadId

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

idlePrReviewConfig :: SomeWatcherState -> Maybe PrConfig
idlePrReviewConfig = \case
  SomeWatcherState (PrCheckingReviews config (WorkerIdle _workerThread) (ReviewerIdle _reviewerThread)) -> Just config
  SomeWatcherState (PrWaitingForMergeability config _evidence (WorkerIdle _workerThread) (ReviewerIdle _reviewerThread)) -> Just config
  _ -> Nothing
