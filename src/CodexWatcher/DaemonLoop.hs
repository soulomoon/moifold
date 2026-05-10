{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.DaemonLoop
  ( DaemonLoopConfig (..)
  , DaemonLoopFailure (..)
  , DaemonLoopTickResult (..)
  , classifyDaemonLoopFailure
  , formatDaemonLoopFailure
  , runAutomaticDaemonLoopOnceFromFile
  , runAutomaticDaemonLoopOnceWithEvents
  ) where

import CodexWatcher.ActionExecutor
import CodexWatcher.Workflow.Agent.Codex.Client (formatAppServerClientFailure)
import CodexWatcher.Daemon
import CodexWatcher.DaemonLoop.Runtime
import CodexWatcher.DaemonLoop.Types
import CodexWatcher.EventLog.File (loadEventLogFile)
import CodexWatcher.EventLog.Replay (replayEventLog)
import CodexWatcher.EventLog.Types
import CodexWatcher.Failure
import CodexWatcher.Domain.IssueImplement.Loop qualified as IssueImplementationLoop
import CodexWatcher.Logging qualified as Log
import CodexWatcher.Domain.IssuePlanning.Loop qualified as PlanningLoop
import CodexWatcher.Domain.PrReview.Loop qualified as PrReviewLoop
import CodexWatcher.Runtime.Command.Render (commandText)
import CodexWatcher.Core.Ids (ThreadId)
import CodexWatcher.Core.Kinds (ThreadActivity (..))
import CodexWatcher.Core.State (SomeWatcherState (..), WatcherState (..), someDomain, somePhase)
import CodexWatcher.Core.Thread (ReviewerThread (..), WorkerThread (..))
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
    SomeWatcherState (IssueHandoffReady _issueConfig prNumber _worker _reviewer) ->
      IssueImplementationLoop.runIssueHandoffReady domainLoopOps executor config events prNumber
    SomeWatcherState (IssueHandoffInitialized _issueConfig prNumber _worker _reviewer) ->
      IssueImplementationLoop.runIssueHandoffInitialized domainLoopOps executor config events prNumber
    SomeWatcherState (IssueWaitingForPrMerge issueConfig prNumber _worker _reviewer) ->
      IssueImplementationLoop.runIssueWaitingForPrMerge domainLoopOps executor config events replay issueConfig prNumber
    SomeWatcherState (IssuePostMergeReviewPendingReviewer issueConfig prNumber _worker) ->
      IssueImplementationLoop.runIssuePostMergeReviewPendingReviewer domainLoopOps executor config events replay issueConfig prNumber
    SomeWatcherState (IssuePostMergeReviewReady issueConfig prNumber _worker reviewer) ->
      IssueImplementationLoop.runIssuePostMergeReviewReady domainLoopOps executor config events issueConfig prNumber (reviewerThreadId reviewer)
    SomeWatcherState (IssuePostMergeReviewing _issueConfig _prNumber _worker commit (ReviewerActive activeTurn)) ->
      IssueImplementationLoop.runIssuePostMergeReviewing domainLoopOps executor config events replay commit activeTurn
    SomeWatcherState (IssueWaitingForIssueClose issueConfig prNumber) ->
      IssueImplementationLoop.runIssueWaitingForIssueClose domainLoopOps executor config events replay issueConfig prNumber
    SomeWatcherState (PrCheckingReviews prConfig (WorkerIdle workerThread) (ReviewerIdle reviewerThread)) ->
      PrReviewLoop.runPrCheckingReviews domainLoopOps executor config events prConfig workerThread reviewerThread
    SomeWatcherState (PrFixingReviews _prConfig _evidence (WorkerActive activeTurn) _reviewer) ->
      PrReviewLoop.runPrFixingReviews domainLoopOps executor config events replay activeTurn
    SomeWatcherState (PrReviewFixQueued _prConfig evidence (WorkerIdle workerThread) _reviewer) ->
      PrReviewLoop.runPrReviewFixQueued domainLoopOps executor config events evidence workerThread
    SomeWatcherState (PrVerifyingReviewFix prConfig evidence (WorkerIdle workerThread) (ReviewerIdle reviewerThread)) ->
      PrReviewLoop.runPrVerifyingReviewFix domainLoopOps executor config events prConfig evidence workerThread reviewerThread
    SomeWatcherState (PrReviewingClean _prConfig commit _reviewContext _worker (ReviewerActive activeTurn)) ->
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

classifyDaemonLoopFailure :: DaemonLoopFailure -> FailureClassification
classifyDaemonLoopFailure = \case
  DaemonLoopExternalFailure reason ->
    classifyExternalFailureText reason
  DaemonLoopAppServerFailure failure ->
    classifyAppServerFailure failure
  DaemonLoopDaemonFailure (DaemonActionFailed _action report)
    | transientFailureText (commandText report) ->
        FailureClassification TransientFailure (commandText report)
  DaemonLoopDaemonFailure failure ->
    FailureClassification FatalFailure (formatDaemonFailure failure)
  DaemonLoopUnexpectedStartPlan reason ->
    FailureClassification FatalFailure ("unexpected start-turn plan: " <> reason)

reviewerThreadId :: ReviewerThread 'Idle -> ThreadId
reviewerThreadId (ReviewerIdle threadId) = threadId

logLoopResult :: ActionExecutor m -> Either DaemonLoopFailure DaemonLoopTickResult -> m ()
logLoopResult executor = \case
  Left failure ->
    Log.logWatcher
      executor.actionLogger
      ( Log.watcherLog
          (failureLogLevel failure)
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

failureLogLevel :: DaemonLoopFailure -> Log.WatcherLogLevel
failureLogLevel failure =
  case (classifyDaemonLoopFailure failure).failureClass of
    TransientFailure -> Log.Warn
    FatalFailure -> Log.Error
    PolicyViolation -> Log.Error
    ExternalStateMismatch -> Log.Error
