{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.DaemonLoop
  ( DaemonLoopConfig (..)
  , DaemonLoopFailure (..)
  , DaemonLoopTickResult (..)
  , formatDaemonLoopFailure
  , runAutomaticDaemonLoopOnceFromFile
  , runAutomaticDaemonLoopOnceWithEvents
  ) where

import CodexWatcher.ActionExecutor
import CodexWatcher.AppServerClient (formatAppServerClientFailure)
import CodexWatcher.Daemon
import CodexWatcher.DaemonLoop.Runtime
import CodexWatcher.DaemonLoop.Types
import CodexWatcher.EventLog.File (loadEventLogFile)
import CodexWatcher.EventLog.Replay (replayEventLog)
import CodexWatcher.EventLog.Types
import CodexWatcher.Domain.IssueImplement.Loop qualified as IssueImplementationLoop
import CodexWatcher.Logging qualified as Log
import CodexWatcher.Domain.IssuePlanning.Loop qualified as PlanningLoop
import CodexWatcher.Domain.PrReview.Loop qualified as PrReviewLoop
import CodexWatcher.Core.Types
import Data.Aeson ((.=))
import Data.Text (Text)
import Data.Text qualified as Text

runAutomaticDaemonLoopOnceFromFile :: ActionExecutor IO -> DaemonLoopConfig -> IO (Either DaemonLoopFailure DaemonLoopTickResult)
runAutomaticDaemonLoopOnceFromFile executor config = do
  loaded <- loadEventLogFile config.loopDaemonOptions.daemonEventLogPath
  case loaded of
    Left errorMessage -> do
      Log.logWatcher
        executor.actionLogger
        ( Log.watcherLog
            Log.Error
            "loop_event_log_decode_failed"
            "automatic loop could not decode event log"
            [ "eventsPath" .= config.loopDaemonOptions.daemonEventLogPath
            , "error" .= Text.pack errorMessage
            ]
        )
      pure (Left (DaemonLoopDaemonFailure (DaemonEventLogDecodeFailed (Text.pack errorMessage))))
    Right events -> runAutomaticDaemonLoopOnceWithEvents executor config events

runAutomaticDaemonLoopOnceWithEvents
  :: Monad m
  => ActionExecutor m
  -> DaemonLoopConfig
  -> [WatcherEvent]
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
runAutomaticDaemonLoopOnceWithEvents executor config events = do
  Log.logWatcher
    executor.actionLogger
    ( Log.watcherLog
        Log.Info
        "loop_tick_started"
        "automatic loop tick started"
        [ "eventsPath" .= config.loopDaemonOptions.daemonEventLogPath
        , "eventCount" .= length events
        ]
    )
  case replayEventLog events of
    Left failure -> do
      let result = Left (DaemonLoopDaemonFailure (DaemonReplayFailed failure))
      logLoopResult executor result
      pure result
    Right replay -> do
      Log.logWatcher
        executor.actionLogger
        ( Log.watcherLog
            Log.Debug
            "loop_replay_succeeded"
            "automatic loop event replay succeeded"
            [ "domain" .= Text.pack (show (someDomain replay.replayState))
            , "phase" .= Text.pack (show (somePhase replay.replayState))
            ]
        )
      result <- runFromState executor config events replay
      logLoopResult executor result
      pure result

runFromState
  :: Monad m
  => ActionExecutor m
  -> DaemonLoopConfig
  -> [WatcherEvent]
  -> EventReplayResult
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
runFromState executor config events replay = do
  clearStaleActiveTurnMarkerWhenInactive executor config replay.replayState
  case replay.replayState of
    SomeWatcherState (PlanningReady plannerConfig) -> do
      PlanningLoop.runPlanningReady domainLoopOps executor config events replay plannerConfig
    SomeWatcherState (PlanningTurnActive plannerConfig activeTurn) ->
      PlanningLoop.runPlanningActive domainLoopOps executor config events replay plannerConfig activeTurn
    SomeWatcherState (PlanningWaitingForReadyIssues {}) ->
      PlanningLoop.runPlanningWaiting domainLoopOps executor config replay
    SomeWatcherState (IssueReadyToPlan issueConfig prNumber (WorkerIdle workerThread)) ->
      IssueImplementationLoop.runIssueReadyToPlan domainLoopOps executor config events issueConfig prNumber workerThread
    SomeWatcherState (IssueInPlanMode _issueConfig _prNumber (WorkerActive activeTurn)) ->
      IssueImplementationLoop.runIssuePlanActive domainLoopOps executor config events replay activeTurn
    SomeWatcherState (IssuePlanReady issueConfig prNumber (WorkerIdle _workerThread)) ->
      IssueImplementationLoop.runIssuePlanReady domainLoopOps executor config events replay issueConfig prNumber
    SomeWatcherState (IssueImplementationReady issueConfig maybePrNumber (WorkerIdle workerThread)) ->
      IssueImplementationLoop.runIssueImplementationReady domainLoopOps executor config events replay issueConfig maybePrNumber workerThread
    SomeWatcherState (IssueImplementing _issueConfig maybePr (WorkerActive activeTurn)) ->
      IssueImplementationLoop.runIssueImplementing domainLoopOps executor config events replay maybePr activeTurn
    SomeWatcherState (IssueHandoffReady _issueConfig prNumber) ->
      IssueImplementationLoop.runIssueHandoffReady domainLoopOps executor config events prNumber
    SomeWatcherState (IssueHandoffInitialized _issueConfig prNumber) ->
      IssueImplementationLoop.runIssueHandoffInitialized domainLoopOps executor config events prNumber
    SomeWatcherState (IssueWaitingForPrMerge issueConfig prNumber) ->
      IssueImplementationLoop.runIssueWaitingForPrMerge domainLoopOps executor config events replay issueConfig prNumber
    SomeWatcherState (IssueWaitingForIssueClose issueConfig prNumber) ->
      IssueImplementationLoop.runIssueWaitingForIssueClose domainLoopOps executor config events replay issueConfig prNumber
    SomeWatcherState (PrCheckingReviews prConfig (WorkerIdle workerThread) (ReviewerIdle reviewerThread)) ->
      PrReviewLoop.runPrCheckingReviews domainLoopOps executor config events prConfig workerThread reviewerThread
    SomeWatcherState (PrFixingReviews _prConfig _evidence (WorkerActive activeTurn) _reviewer) ->
      PrReviewLoop.runPrFixingReviews domainLoopOps executor config events replay activeTurn
    SomeWatcherState (PrReviewingClean _prConfig commit _worker (ReviewerActive activeTurn)) ->
      PrReviewLoop.runPrReviewingClean domainLoopOps executor config events replay commit activeTurn
    SomeWatcherState (PrWaitingForMergeability prConfig evidence _worker _reviewer) ->
      PrReviewLoop.runPrWaitingForMergeability domainLoopOps executor config events prConfig evidence
    SomeWatcherState (PrMerging prConfig _evidence) ->
      PrReviewLoop.runPrMerging domainLoopOps executor config events replay prConfig
    SomeWatcherState (BlockedState {}) ->
      terminalStop executor config replay "watcher is blocked"
    SomeWatcherState (CompleteState {}) ->
      terminalStop executor config replay "watcher is complete"
    SomeWatcherState (StoppedState {}) ->
      terminalStop executor config replay "watcher is stopped"

formatDaemonLoopFailure :: DaemonLoopFailure -> Text
formatDaemonLoopFailure = \case
  DaemonLoopDaemonFailure failure -> formatDaemonFailure failure
  DaemonLoopExternalFailure reason -> "external observation failed: " <> reason
  DaemonLoopAppServerFailure failure -> formatAppServerClientFailure failure
  DaemonLoopUnexpectedStartPlan reason -> "unexpected start-turn plan: " <> reason

logLoopResult :: ActionExecutor m -> Either DaemonLoopFailure DaemonLoopTickResult -> m ()
logLoopResult executor = \case
  Left failure ->
    Log.logWatcher
      executor.actionLogger
      ( Log.watcherLog
          Log.Error
          "loop_tick_failed"
          "automatic loop tick failed"
          ["failure" .= formatDaemonLoopFailure failure]
      )
  Right tick ->
    Log.logWatcher
      executor.actionLogger
      ( Log.watcherLog
          Log.Info
          "loop_tick_finished"
          "automatic loop tick finished"
          [ "domain" .= Text.pack (show (someDomain tick.loopReplayResult.replayState))
          , "phase" .= Text.pack (show (somePhase tick.loopReplayResult.replayState))
          , "observation" .= fmap (Text.pack . show) tick.loopObservation
          , "idleReason" .= tick.loopIdleReason
          , "actions" .= length tick.loopActionReports
          ]
      )
