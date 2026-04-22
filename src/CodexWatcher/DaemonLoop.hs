{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
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
import CodexWatcher.AppServerClient
import CodexWatcher.AppServerProtocol
import CodexWatcher.Daemon
import CodexWatcher.EffectInterpreter
import CodexWatcher.Effects
import CodexWatcher.EventLog
import CodexWatcher.GhGit
import CodexWatcher.IssueImplementWatcher
import CodexWatcher.IssuePlanningWatcher
import CodexWatcher.PrReviewWatcher
import CodexWatcher.TurnClassifier
import CodexWatcher.Types
import Data.Aeson (Value)
import Data.List (find)
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)

data DaemonLoopConfig = DaemonLoopConfig
  { loopDaemonOptions :: DaemonOptions
  , loopPlannerThreadId :: Maybe ThreadId
  }
  deriving stock (Eq, Show, Generic)

data DaemonLoopFailure
  = DaemonLoopDaemonFailure DaemonFailure
  | DaemonLoopExternalFailure Text
  | DaemonLoopAppServerFailure AppServerClientFailure
  | DaemonLoopMissingPlannerThread
  | DaemonLoopUnexpectedStartPlan Text
  deriving stock (Eq, Show, Generic)

data DaemonLoopTickResult = DaemonLoopTickResult
  { loopReplayResult :: EventReplayResult
  , loopObservation :: Maybe DaemonObservation
  , loopObservedTick :: Maybe DaemonObservedTickResult
  , loopIdleReason :: Maybe Text
  , loopActionReports :: [ActionExecutionReport]
  }
  deriving stock (Show, Generic)

data StartTurnKind
  = StartPlannerTurnKind
  | StartWorkerTurnKind
  | StartReviewerTurnKind
  deriving stock (Eq, Show)

runAutomaticDaemonLoopOnceFromFile :: ActionExecutor IO -> DaemonLoopConfig -> IO (Either DaemonLoopFailure DaemonLoopTickResult)
runAutomaticDaemonLoopOnceFromFile executor config = do
  loaded <- loadEventLogFile config.loopDaemonOptions.daemonEventLogPath
  case loaded of
    Left errorMessage -> pure (Left (DaemonLoopDaemonFailure (DaemonEventLogDecodeFailed (Text.pack errorMessage))))
    Right events -> runAutomaticDaemonLoopOnceWithEvents executor config events

runAutomaticDaemonLoopOnceWithEvents
  :: Monad m
  => ActionExecutor m
  -> DaemonLoopConfig
  -> [WatcherEvent]
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
runAutomaticDaemonLoopOnceWithEvents executor config events =
  case replayEventLog events of
    Left failure -> pure (Left (DaemonLoopDaemonFailure (DaemonReplayFailed failure)))
    Right replay -> runFromState executor config events replay

runFromState
  :: Monad m
  => ActionExecutor m
  -> DaemonLoopConfig
  -> [WatcherEvent]
  -> EventReplayResult
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
runFromState executor config events replay =
  case replay.replayState of
    SomeWatcherState (PlanningReady {}) ->
      case config.loopPlannerThreadId of
        Nothing -> pure (Left DaemonLoopMissingPlannerThread)
        Just plannerThread -> prestartAndObserve executor config events StartPlannerTurnKind plannerThread (DaemonIssuePlanningObservation . ObservedPlanningTurnStarted plannerThread)
    SomeWatcherState (PlanningTurnActive _ activeTurn) ->
      observeActiveTurn executor config events replay activeTurn \turn ->
        case classifyTurnCompletion turn of
          TurnStillRunning -> Nothing
          TurnCompleted _ -> Just (DaemonIssuePlanningObservation ObservedPlanningTurnCompleted)
          TurnFailed reason -> Just (DaemonIssuePlanningObservation (ObservedPlanningBlocked (BlockedReason reason)))
    SomeWatcherState (IssueNeedsTriage _ (WorkerIdle workerThread)) ->
      prestartAndObserve executor config events StartWorkerTurnKind workerThread (DaemonIssueImplementObservation . ObservedTriageTurnStarted)
    SomeWatcherState (IssueTriageActive _ (WorkerActive activeTurn)) ->
      observeActiveTurn executor config events replay activeTurn (fmap DaemonIssueImplementObservation . classifyIssueTriageTurn)
    SomeWatcherState (IssuePlanReady _ (WorkerIdle workerThread)) ->
      prestartAndObserve executor config events StartWorkerTurnKind workerThread (DaemonIssueImplementObservation . ObservedPlanTurnStarted)
    SomeWatcherState (IssueInPlanMode _ (WorkerActive activeTurn)) ->
      observeActiveTurn executor config events replay activeTurn (fmap DaemonIssueImplementObservation . classifyIssuePlanTurn)
    SomeWatcherState (IssueImplementationReady issueConfig Nothing _worker) ->
      observeExistingPullRequest executor config events replay issueConfig
    SomeWatcherState (IssueImplementationReady _issueConfig (Just _prNumber) (WorkerIdle workerThread)) ->
      prestartAndObserve executor config events StartWorkerTurnKind workerThread (DaemonIssueImplementObservation . ObservedImplementationTurnStarted)
    SomeWatcherState (IssueImplementing _issueConfig maybePr (WorkerActive activeTurn)) ->
      observeActiveTurn executor config events replay activeTurn (fmap DaemonIssueImplementObservation . classifyIssueImplementationObservation events maybePr)
    SomeWatcherState (PrCheckingReviews prConfig (WorkerIdle workerThread) (ReviewerIdle reviewerThread)) ->
      observeReviewThreads executor config events prConfig workerThread reviewerThread
    SomeWatcherState (PrFixingReviews _prConfig _evidence (WorkerActive activeTurn) _reviewer) ->
      observeActiveTurn executor config events replay activeTurn (fmap DaemonPrReviewObservation . classifyPrReviewWorkerTurn)
    SomeWatcherState (PrReviewingClean _prConfig commit _worker (ReviewerActive activeTurn)) ->
      observeActiveTurn executor config events replay activeTurn (fmap DaemonPrReviewObservation . classifyPrReviewReviewerTurn commit)
    SomeWatcherState (PrMerging prConfig _evidence) ->
      observeMergeCompletion executor config events replay prConfig
    SomeWatcherState (BlockedState {}) ->
      idle executor config replay "watcher is blocked"
    SomeWatcherState (CompleteState {}) ->
      idle executor config replay "watcher is complete"
    SomeWatcherState (StoppedState {}) ->
      idle executor config replay "watcher is stopped"

observeActiveTurn
  :: Monad m
  => ActionExecutor m
  -> DaemonLoopConfig
  -> [WatcherEvent]
  -> EventReplayResult
  -> ActiveTurn
  -> (AppServerTurn -> Maybe DaemonObservation)
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
observeActiveTurn executor config events replay activeTurn classify = do
  turnResult <- readActiveTurn executor config activeTurn
  case turnResult of
    Left failure -> pure (Left failure)
    Right Nothing ->
      idle executor config replay ("active turn not found: " <> unTurnId activeTurn.activeTurnId)
    Right (Just turn) ->
      case classify turn of
        Nothing -> idle executor config replay ("active turn is not finished: " <> unTurnId activeTurn.activeTurnId)
        Just observation -> observeWithExecutor executor config events observation

observeReviewThreads
  :: Monad m
  => ActionExecutor m
  -> DaemonLoopConfig
  -> [WatcherEvent]
  -> PrConfig
  -> ThreadId
  -> ThreadId
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
observeReviewThreads executor config events prConfig workerThread reviewerThread = do
  status <- runGitWorktreeStatus executor.actionRuntime config.loopDaemonOptions.daemonRuntimeConfig.effectRuntimeWorkdir prConfig.prBranch
  case status.gitHeadSha of
    Nothing -> pure (Left (DaemonLoopExternalFailure "could not determine git HEAD for review-thread check"))
    Just commit -> do
      report <- runGhReviewThreads executor.actionRuntime prConfig
      case report of
        Left reason -> pure (Left (DaemonLoopExternalFailure reason))
        Right reviewReport ->
          let hasUnresolved = not (null reviewReport.unresolvedReviewThreads)
              targetThread = if hasUnresolved then workerThread else reviewerThread
           in prestartAndObserve executor config events (if hasUnresolved then StartWorkerTurnKind else StartReviewerTurnKind) targetThread \turnId ->
                DaemonPrReviewObservation (ObservedReviewThreads reviewReport commit turnId)

observeExistingPullRequest
  :: Monad m
  => ActionExecutor m
  -> DaemonLoopConfig
  -> [WatcherEvent]
  -> EventReplayResult
  -> IssueConfig
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
observeExistingPullRequest executor config events replay issueConfig = do
  pullRequests <- runGhPrListOpen executor.actionRuntime issueConfig.issueRepo
  case pullRequests of
    Left reason -> pure (Left (DaemonLoopExternalFailure reason))
    Right openPullRequests ->
      case find ((== issueConfig.issueBranch) . ghPullRequestHeadRefName) openPullRequests of
        Nothing -> idle executor config replay ("waiting for pull request for branch " <> unBranchName issueConfig.issueBranch)
        Just pullRequest ->
          observeWithExecutor
            executor
            config
            events
            (DaemonIssueImplementObservation (ObservedPullRequestReused pullRequest.ghPullRequestNumber))

classifyIssueImplementationObservation :: [WatcherEvent] -> Maybe PrNumber -> AppServerTurn -> Maybe IssueImplementObservation
classifyIssueImplementationObservation events maybePr turn =
  case classifyIssueImplementationTurn maybePr turn of
    Just (ObservedImplementationCompleted prNumber)
      | not (hasReviewHandoffInitialized prNumber events) ->
          Just (ObservedReviewHandoffInitialized prNumber)
      | not (hasReviewHandoffStarted prNumber events) ->
          Just (ObservedReviewHandoffStarted prNumber)
    observation ->
      observation

hasReviewHandoffInitialized :: PrNumber -> [WatcherEvent] -> Bool
hasReviewHandoffInitialized prNumber =
  any \case
    IssueReviewHandoffInitializedEvent eventPr -> eventPr == prNumber
    _ -> False

hasReviewHandoffStarted :: PrNumber -> [WatcherEvent] -> Bool
hasReviewHandoffStarted prNumber =
  any \case
    IssueReviewHandoffStartedEvent eventPr -> eventPr == prNumber
    _ -> False

observeMergeCompletion
  :: Monad m
  => ActionExecutor m
  -> DaemonLoopConfig
  -> [WatcherEvent]
  -> EventReplayResult
  -> PrConfig
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
observeMergeCompletion executor config events replay prConfig = do
  pullRequest <- runGhPrView executor.actionRuntime prConfig.prRepo prConfig.prNumber
  case pullRequest of
    Left reason -> pure (Left (DaemonLoopExternalFailure reason))
    Right remote
      | Text.toUpper remote.remotePullRequestState == "MERGED"
      , Just mergeCommit <- remote.remotePullRequestMergeCommit ->
          observeWithExecutor executor config events (DaemonPrReviewObservation (ObservedMergeCompleted (MergeCommit mergeCommit)))
      | otherwise ->
          idle executor config replay ("waiting for PR merge completion for #" <> Text.pack (show (unPrNumber prConfig.prNumber)))

prestartAndObserve
  :: Monad m
  => ActionExecutor m
  -> DaemonLoopConfig
  -> [WatcherEvent]
  -> StartTurnKind
  -> ThreadId
  -> (TurnId -> DaemonObservation)
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
prestartAndObserve executor config events kind threadId toObservation =
  case config.loopDaemonOptions.daemonExecutionMode of
    DryRunActions -> do
      let turnId = syntheticTurnId kind config.loopDaemonOptions.daemonRuntimeConfig.effectRuntimeNextRequestId
      observeWithExecutor executor config events (toObservation turnId)
    ExecuteActions -> do
      started <- prestartTurn executor config.loopDaemonOptions.daemonRuntimeConfig kind threadId
      case started of
        Left failure -> pure (Left failure)
        Right (turnId, cachedExecutor) ->
          observeWithExecutor cachedExecutor config events (toObservation turnId)

prestartTurn
  :: Monad m
  => ActionExecutor m
  -> EffectRuntimeConfig
  -> StartTurnKind
  -> ThreadId
  -> m (Either DaemonLoopFailure (TurnId, ActionExecutor m))
prestartTurn executor runtimeConfig kind threadId =
  case compileEffect runtimeConfig runtimeConfig.effectRuntimeNextRequestId (startTurnEffect kind threadId) of
    ([PlannedAppServerRequest request], _nextRequestId) -> do
      response <- executor.actionAppServer.appServerSendRequest request
      case parseTurnStartTurnId response of
        Left failure -> pure (Left (DaemonLoopAppServerFailure failure))
        Right turnId -> pure (Right (turnId, cachedAppServerExecutor executor request response))
    (actions, _nextRequestId) ->
      pure (Left (DaemonLoopUnexpectedStartPlan ("expected one app-server start action, got " <> Text.pack (show actions))))

cachedAppServerExecutor :: Monad m => ActionExecutor m -> AppServerRequest -> Value -> ActionExecutor m
cachedAppServerExecutor executor expectedRequest response =
  executor
    { actionAppServer =
        AppServerInterpreter \request ->
          if request == expectedRequest
            then pure response
            else executor.actionAppServer.appServerSendRequest request
    }

startTurnEffect :: StartTurnKind -> ThreadId -> SomeEffect
startTurnEffect kind threadId =
  case kind of
    StartPlannerTurnKind -> SomeEffect (StartPlannerTurn threadId)
    StartWorkerTurnKind -> SomeEffect (StartWorkerTurn threadId)
    StartReviewerTurnKind -> SomeEffect (StartReviewerTurn threadId)

syntheticTurnId :: StartTurnKind -> Int -> TurnId
syntheticTurnId kind requestId =
  TurnId ("dry-run-" <> kindText kind <> "-" <> Text.pack (show requestId))

kindText :: StartTurnKind -> Text
kindText = \case
  StartPlannerTurnKind -> "planner-turn"
  StartWorkerTurnKind -> "worker-turn"
  StartReviewerTurnKind -> "reviewer-turn"

readActiveTurn :: Monad m => ActionExecutor m -> DaemonLoopConfig -> ActiveTurn -> m (Either DaemonLoopFailure (Maybe AppServerTurn))
readActiveTurn executor config activeTurn = do
  response <-
    executor.actionAppServer.appServerSendRequest
      (threadReadRequest config.loopDaemonOptions.daemonRuntimeConfig.effectRuntimeNextRequestId activeTurn.activeThreadId True)
  pure case parseThreadReadTurns response of
    Left failure -> Left (DaemonLoopAppServerFailure failure)
    Right turns -> Right (latestTurnById activeTurn.activeTurnId turns)

observeWithExecutor
  :: Monad m
  => ActionExecutor m
  -> DaemonLoopConfig
  -> [WatcherEvent]
  -> DaemonObservation
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
observeWithExecutor executor config events observation = do
  observed <- runObservedDaemonTickWithEvents executor config.loopDaemonOptions events observation
  pure case observed of
    Left failure -> Left (DaemonLoopDaemonFailure failure)
    Right tick ->
      Right
        DaemonLoopTickResult
          { loopReplayResult = tick.daemonObservedReplayResult
          , loopObservation = Just observation
          , loopObservedTick = Just tick
          , loopIdleReason = Nothing
          , loopActionReports = tick.daemonObservedActionReports
          }

idle
  :: Monad m
  => ActionExecutor m
  -> DaemonLoopConfig
  -> EventReplayResult
  -> Text
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
idle executor config replay reason = do
  let sleepPlan = compileEffectPlan config.loopDaemonOptions.daemonRuntimeConfig [SomeEffect SleepUntilNextPoll]
  reports <- executeCompiledEffectPlan executor config.loopDaemonOptions.daemonExecutionMode sleepPlan
  pure
    ( Right
        DaemonLoopTickResult
          { loopReplayResult = replay
          , loopObservation = Nothing
          , loopObservedTick = Nothing
          , loopIdleReason = Just reason
          , loopActionReports = reports
          }
    )

formatDaemonLoopFailure :: DaemonLoopFailure -> Text
formatDaemonLoopFailure = \case
  DaemonLoopDaemonFailure failure -> formatDaemonFailure failure
  DaemonLoopExternalFailure reason -> "external observation failed: " <> reason
  DaemonLoopAppServerFailure failure -> formatAppServerClientFailure failure
  DaemonLoopMissingPlannerThread -> "issue planning loop requires a planner thread id"
  DaemonLoopUnexpectedStartPlan reason -> "unexpected start-turn plan: " <> reason
