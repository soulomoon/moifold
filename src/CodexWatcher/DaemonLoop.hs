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
import CodexWatcher.CompatibilityState
import CodexWatcher.Daemon
import CodexWatcher.EffectInterpreter
import CodexWatcher.Effects
import CodexWatcher.EventLog
import CodexWatcher.GhGit
import CodexWatcher.IssueImplementWatcher
import CodexWatcher.IssuePlanningWatcher
import CodexWatcher.PrReviewWatcher
import CodexWatcher.Runtime (CommandReport (..), runtimeReadJsonValue, runtimeWriteJsonValue)
import CodexWatcher.TurnClassifier
import CodexWatcher.Types
import Control.Monad (filterM)
import Data.Aeson (FromJSON (..), Result (..), ToJSON (..), Value (..), fromJSON, object, withObject, (.:), (.=))
import Data.List (find, nub)
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)
import System.FilePath ((</>))

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
  | StartIssueTriageWorkerTurnKind
  | StartIssuePlanWorkerTurnKind IssueConfig
  | StartIssueImplementationWorkerTurnKind
  | StartReviewerTurnKind PrConfig CommitSha
  deriving stock (Eq, Show)

data StaleActiveTurnMarker = StaleActiveTurnMarker
  { staleMarkerDomain :: Text
  , staleMarkerThreadId :: Text
  , staleMarkerTurnId :: Text
  , staleMarkerStateFingerprint :: Text
  , staleMarkerReason :: Text
  , staleMarkerFirstSeenAt :: Text
  , staleMarkerLastSeenAt :: Text
  , staleMarkerCount :: Int
  }
  deriving stock (Eq, Show, Generic)

instance ToJSON StaleActiveTurnMarker where
  toJSON marker =
    object
      [ "domain" .= marker.staleMarkerDomain
      , "threadId" .= marker.staleMarkerThreadId
      , "turnId" .= marker.staleMarkerTurnId
      , "stateFingerprint" .= marker.staleMarkerStateFingerprint
      , "reason" .= marker.staleMarkerReason
      , "firstSeenAt" .= marker.staleMarkerFirstSeenAt
      , "lastSeenAt" .= marker.staleMarkerLastSeenAt
      , "count" .= marker.staleMarkerCount
      ]

instance FromJSON StaleActiveTurnMarker where
  parseJSON = withObject "StaleActiveTurnMarker" \objectValue ->
    StaleActiveTurnMarker
      <$> objectValue .: "domain"
      <*> objectValue .: "threadId"
      <*> objectValue .: "turnId"
      <*> objectValue .: "stateFingerprint"
      <*> objectValue .: "reason"
      <*> objectValue .: "firstSeenAt"
      <*> objectValue .: "lastSeenAt"
      <*> objectValue .: "count"

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
runFromState executor config events replay = do
  clearStaleActiveTurnMarkerWhenInactive executor config replay.replayState
  case replay.replayState of
    SomeWatcherState (PlanningReady {}) ->
      case config.loopPlannerThreadId of
        Nothing -> pure (Left DaemonLoopMissingPlannerThread)
        Just plannerThread -> prestartAndObserve executor config events StartPlannerTurnKind plannerThread (DaemonIssuePlanningObservation . ObservedPlanningTurnStarted plannerThread)
    SomeWatcherState (PlanningTurnActive plannerConfig activeTurn) ->
      observePlanningActiveTurn executor config events replay plannerConfig activeTurn
    SomeWatcherState (PlanningWaitingForReadyIssues {}) ->
      idle executor config replay "issue planning is waiting for ready issues"
    SomeWatcherState (IssueNeedsTriage _ (WorkerIdle workerThread)) ->
      prestartAndObserve executor config events StartIssueTriageWorkerTurnKind workerThread (DaemonIssueImplementObservation . ObservedTriageTurnStarted)
    SomeWatcherState (IssueTriageActive _ (WorkerActive activeTurn)) ->
      observeActiveTurn executor config events replay activeTurn (fmap DaemonIssueImplementObservation . classifyIssueTriageTurn)
    SomeWatcherState (IssuePlanReady issueConfig (WorkerIdle workerThread)) ->
      prestartAndObserve executor config events (StartIssuePlanWorkerTurnKind issueConfig) workerThread (DaemonIssueImplementObservation . ObservedPlanTurnStarted)
    SomeWatcherState (IssueInPlanMode _ (WorkerActive activeTurn)) ->
      observeActiveTurn executor config events replay activeTurn (fmap DaemonIssueImplementObservation . classifyIssuePlanTurn)
    SomeWatcherState (IssueImplementationReady issueConfig Nothing _worker) ->
      observeExistingPullRequest executor config events replay issueConfig
    SomeWatcherState (IssueImplementationReady _issueConfig (Just _prNumber) (WorkerIdle workerThread)) ->
      prestartAndObserve executor config events StartIssueImplementationWorkerTurnKind workerThread (DaemonIssueImplementObservation . ObservedImplementationTurnStarted)
    SomeWatcherState (IssueImplementing _issueConfig maybePr (WorkerActive activeTurn)) ->
      observeActiveTurn executor config events replay activeTurn (fmap DaemonIssueImplementObservation . classifyIssueImplementationObservation events maybePr)
    SomeWatcherState (IssueWaitingForPrMerge issueConfig prNumber) ->
      observeIssuePullRequestMerged executor config events replay issueConfig prNumber
    SomeWatcherState (PrCheckingReviews prConfig (WorkerIdle workerThread) (ReviewerIdle reviewerThread)) ->
      observeReviewThreads executor config events prConfig workerThread reviewerThread
    SomeWatcherState (PrFixingReviews _prConfig _evidence (WorkerActive activeTurn) _reviewer) ->
      observeActiveTurn executor config events replay activeTurn (fmap DaemonPrReviewObservation . classifyPrReviewWorkerTurn)
    SomeWatcherState (PrReviewingClean _prConfig commit _worker (ReviewerActive activeTurn)) ->
      observeActiveTurn executor config events replay activeTurn (fmap DaemonPrReviewObservation . classifyPrReviewReviewerTurn commit)
    SomeWatcherState (PrMerging prConfig _evidence) ->
      observeMergeCompletion executor config events replay prConfig
    SomeWatcherState (BlockedState {}) ->
      terminalStop executor config replay "watcher is blocked"
    SomeWatcherState (CompleteState {}) ->
      terminalStop executor config replay "watcher is complete"
    SomeWatcherState (StoppedState {}) ->
      terminalStop executor config replay "watcher is stopped"

clearStaleActiveTurnMarkerWhenInactive :: Monad m => ActionExecutor m -> DaemonLoopConfig -> SomeWatcherState -> m ()
clearStaleActiveTurnMarkerWhenInactive executor config state =
  if watcherStateHasActiveTurn state
    then pure ()
    else clearStaleActiveTurnMarker executor config

watcherStateHasActiveTurn :: SomeWatcherState -> Bool
watcherStateHasActiveTurn = \case
  SomeWatcherState PlanningTurnActive {} -> True
  SomeWatcherState IssueTriageActive {} -> True
  SomeWatcherState IssueInPlanMode {} -> True
  SomeWatcherState IssueImplementing {} -> True
  SomeWatcherState PrFixingReviews {} -> True
  SomeWatcherState PrReviewingClean {} -> True
  _ -> False

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
      handleMissingActiveTurn executor config events replay activeTurn
    Right (Just turn) -> do
      clearStaleActiveTurnMarker executor config
      case classify turn of
        Nothing -> idle executor config replay ("active turn is not finished: " <> unTurnId activeTurn.activeTurnId)
        Just observation -> observeWithExecutor executor config events observation

observePlanningActiveTurn
  :: Monad m
  => ActionExecutor m
  -> DaemonLoopConfig
  -> [WatcherEvent]
  -> EventReplayResult
  -> PlannerConfig
  -> ActiveTurn
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
observePlanningActiveTurn executor config events replay plannerConfig activeTurn = do
  turnResult <- readActiveTurn executor config activeTurn
  case turnResult of
    Left failure -> pure (Left failure)
    Right Nothing ->
      handleMissingActiveTurn executor config events replay activeTurn
    Right (Just turn) -> do
      clearStaleActiveTurnMarker executor config
      case classifyIssuePlanningTurn turn of
        Nothing ->
          idle executor config replay ("active turn is not finished: " <> unTurnId activeTurn.activeTurnId)
        Just observation -> do
          normalized <- normalizePlanningObservation executor plannerConfig observation
          observeWithExecutor executor config events (DaemonIssuePlanningObservation normalized)

normalizePlanningObservation :: Monad m => ActionExecutor m -> PlannerConfig -> IssuePlanningObservation -> m IssuePlanningObservation
normalizePlanningObservation executor plannerConfig = \case
  ObservedPlanningGraphUpdated graph ->
    ObservedPlanningGraphUpdated <$> filterClosedPlanningDependencies executor plannerConfig graph
  observation ->
    pure observation

filterClosedPlanningDependencies :: Monad m => ActionExecutor m -> PlannerConfig -> PlanningGraph -> m PlanningGraph
filterClosedPlanningDependencies executor plannerConfig graph = do
  closedIssues <- filterM isClosedIssue dependencyIssues
  let unresolved issue = issue `notElem` closedIssues
      filterUnresolved = filter unresolved
      filterBlocked blocked =
        blocked {blockedPlanningDependsOn = filterUnresolved blocked.blockedPlanningDependsOn}
      filterDependency dependency =
        dependency {dependencyDependsOn = filterUnresolved dependency.dependencyDependsOn}
  pure
    graph
      { planningBlockedIssues = fmap filterBlocked graph.planningBlockedIssues
      , planningDependencies = fmap filterDependency graph.planningDependencies
      }
 where
  dependencyIssues =
    nub
      ( concatMap blockedPlanningDependsOn graph.planningBlockedIssues
          <> concatMap dependencyDependsOn graph.planningDependencies
      )
  isClosedIssue issue = do
    result <- runGhIssueView executor.actionRuntime plannerConfig.plannerRepo issue
    pure case result of
      Right remote -> remote.remoteIssueClosed || Text.toUpper remote.remoteIssueState == "CLOSED"
      Left _reason -> False

handleMissingActiveTurn
  :: Monad m
  => ActionExecutor m
  -> DaemonLoopConfig
  -> [WatcherEvent]
  -> EventReplayResult
  -> ActiveTurn
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
handleMissingActiveTurn executor config events replay activeTurn =
  case config.loopDaemonOptions.daemonExecutionMode of
    DryRunActions ->
      idle executor config replay (missingActiveTurnReason activeTurn)
    ExecuteActions -> do
      marker <- updateStaleActiveTurnMarker executor config replay activeTurn
      if marker.staleMarkerCount >= staleActiveTurnThreshold
        then do
          clearStaleActiveTurnMarker executor config
          case activeTurnBlockedObservation replay.replayState activeTurn of
            Just observation -> observeWithExecutor executor config events observation
            Nothing -> idle executor config replay (missingActiveTurnReason activeTurn)
        else idle executor config replay (missingActiveTurnReason activeTurn)

staleActiveTurnThreshold :: Int
staleActiveTurnThreshold = 3

updateStaleActiveTurnMarker
  :: Monad m
  => ActionExecutor m
  -> DaemonLoopConfig
  -> EventReplayResult
  -> ActiveTurn
  -> m StaleActiveTurnMarker
updateStaleActiveTurnMarker executor config replay activeTurn = do
  previous <- readStaleActiveTurnMarker executor config
  let fingerprint = activeTurnStateFingerprint replay.replayState activeTurn
      reason = missingActiveTurnReason activeTurn
      matchesActiveTurn = maybe False (`markerMatchesActiveTurn` (activeTurn, fingerprint)) previous
      count =
        if matchesActiveTurn
          then maybe 1 (\prior -> prior.staleMarkerCount + 1) previous
          else 1
      firstSeenAt =
        if matchesActiveTurn
          then maybe "unknown" (\prior -> prior.staleMarkerFirstSeenAt) previous
          else "unknown"
      marker =
        StaleActiveTurnMarker
          { staleMarkerDomain = Text.pack (show (someDomain replay.replayState))
          , staleMarkerThreadId = unThreadId activeTurn.activeThreadId
          , staleMarkerTurnId = unTurnId activeTurn.activeTurnId
          , staleMarkerStateFingerprint = fingerprint
          , staleMarkerReason = reason
          , staleMarkerFirstSeenAt = firstSeenAt
          , staleMarkerLastSeenAt = "unknown"
          , staleMarkerCount = count
          }
  runtimeWriteJsonValue (actionRuntime executor) (staleActiveTurnMarkerPath config) (toJSON marker)
  pure marker

missingActiveTurnReason :: ActiveTurn -> Text
missingActiveTurnReason activeTurn =
  "active turn not found: " <> unTurnId activeTurn.activeTurnId

markerMatchesActiveTurn :: StaleActiveTurnMarker -> (ActiveTurn, Text) -> Bool
markerMatchesActiveTurn marker (activeTurn, fingerprint) =
  marker.staleMarkerThreadId == unThreadId activeTurn.activeThreadId
    && marker.staleMarkerTurnId == unTurnId activeTurn.activeTurnId
    && marker.staleMarkerStateFingerprint == fingerprint

readStaleActiveTurnMarker :: Monad m => ActionExecutor m -> DaemonLoopConfig -> m (Maybe StaleActiveTurnMarker)
readStaleActiveTurnMarker executor config = do
  value <- runtimeReadJsonValue (actionRuntime executor) (staleActiveTurnMarkerPath config)
  pure case value of
    Right Null -> Nothing
    Right jsonValue ->
      case fromJSON jsonValue of
        Success marker -> Just marker
        Error _ -> Nothing
    Left _ -> Nothing

clearStaleActiveTurnMarker :: Monad m => ActionExecutor m -> DaemonLoopConfig -> m ()
clearStaleActiveTurnMarker executor config =
  case config.loopDaemonOptions.daemonExecutionMode of
    DryRunActions -> pure ()
    ExecuteActions -> runtimeWriteJsonValue (actionRuntime executor) (staleActiveTurnMarkerPath config) Null

staleActiveTurnMarkerPath :: DaemonLoopConfig -> FilePath
staleActiveTurnMarkerPath config =
  config.loopDaemonOptions.daemonRuntimeConfig.effectRuntimeStateDir </> "stale-active-turn.json"

activeTurnStateFingerprint :: SomeWatcherState -> ActiveTurn -> Text
activeTurnStateFingerprint state activeTurn =
  Text.intercalate
    ":"
    [ Text.pack (show (someDomain state))
    , Text.pack (show (somePhase state))
    , unThreadId activeTurn.activeThreadId
    , unTurnId activeTurn.activeTurnId
    ]

activeTurnBlockedObservation :: SomeWatcherState -> ActiveTurn -> Maybe DaemonObservation
activeTurnBlockedObservation state activeTurn =
  let reason = BlockedReason ("active turn not found after 3 consecutive checks: " <> unTurnId activeTurn.activeTurnId)
   in case state of
        SomeWatcherState PlanningTurnActive {} ->
          Just (DaemonIssuePlanningObservation (ObservedPlanningBlocked reason))
        SomeWatcherState IssueTriageActive {} ->
          Just (DaemonIssueImplementObservation (ObservedIssueImplementBlocked reason))
        SomeWatcherState IssueInPlanMode {} ->
          Just (DaemonIssueImplementObservation (ObservedIssueImplementBlocked reason))
        SomeWatcherState IssueImplementing {} ->
          Just (DaemonIssueImplementObservation (ObservedIssueImplementBlocked reason))
        SomeWatcherState PrFixingReviews {} ->
          Just (DaemonPrReviewObservation (ObservedPrReviewBlocked reason))
        SomeWatcherState PrReviewingClean {} ->
          Just (DaemonPrReviewObservation (ObservedPrReviewBlocked reason))
        _ ->
          Nothing

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
           in prestartAndObserve executor config events (if hasUnresolved then StartWorkerTurnKind else StartReviewerTurnKind prConfig commit) targetThread \turnId ->
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
        Nothing -> retryCreatePullRequest executor config events replay issueConfig
        Just pullRequest ->
          observeWithExecutor
            executor
            config
            events
            (DaemonIssueImplementObservation (ObservedPullRequestReused pullRequest.ghPullRequestNumber))

retryCreatePullRequest
  :: Monad m
  => ActionExecutor m
  -> DaemonLoopConfig
  -> [WatcherEvent]
  -> EventReplayResult
  -> IssueConfig
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
retryCreatePullRequest executor config events replay issueConfig = do
  let retryPlan =
        compileEffectPlan
          config.loopDaemonOptions.daemonRuntimeConfig
          [ SomeEffect (CreatePullRequest issueConfig)
          ]
  reports <- executeCompiledEffectPlan executor config.loopDaemonOptions.daemonExecutionMode retryPlan
  case config.loopDaemonOptions.daemonExecutionMode of
    DryRunActions ->
      pure
        ( Right
            DaemonLoopTickResult
              { loopReplayResult = replay
              , loopObservation = Nothing
              , loopObservedTick = Nothing
              , loopIdleReason = Just ("would create pull request for branch " <> unBranchName issueConfig.issueBranch)
              , loopActionReports = reports
              }
        )
    ExecuteActions ->
      case reports of
        [report] ->
          case report.actionExecutionResult of
            CommandActionResult commandReport
              | not commandReport.ok ->
                  pure (Left (DaemonLoopDaemonFailure (DaemonActionFailed report.actionExecutionAction commandReport)))
              | otherwise ->
                  case parseGhPrCreateResult commandReport.stdout of
                    Left reason ->
                      pure (Left (DaemonLoopDaemonFailure (DaemonActionResultInvalid report.actionExecutionAction reason)))
                    Right (GhPullRequestCreated prNumber) ->
                      prependActionReport report <$> observeWithExecutor executor config events (DaemonIssueImplementObservation (ObservedPullRequestCreated prNumber))
                    Right (GhPullRequestReused prNumber) ->
                      prependActionReport report <$> observeWithExecutor executor config events (DaemonIssueImplementObservation (ObservedPullRequestReused prNumber))
            _ ->
              pure (Left (DaemonLoopDaemonFailure (DaemonActionResultInvalid report.actionExecutionAction "PR creation did not return a command report")))
        _ ->
          pure (Left (DaemonLoopExternalFailure "unexpected PR creation action report count"))

prependActionReport :: ActionExecutionReport -> Either DaemonLoopFailure DaemonLoopTickResult -> Either DaemonLoopFailure DaemonLoopTickResult
prependActionReport report =
  fmap \tick -> tick {loopActionReports = report : tick.loopActionReports}

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

observeIssuePullRequestMerged
  :: Monad m
  => ActionExecutor m
  -> DaemonLoopConfig
  -> [WatcherEvent]
  -> EventReplayResult
  -> IssueConfig
  -> PrNumber
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
observeIssuePullRequestMerged executor config events replay issueConfig prNumber = do
  pullRequest <- runGhPrView executor.actionRuntime issueConfig.issueRepo prNumber
  case pullRequest of
    Left reason -> pure (Left (DaemonLoopExternalFailure reason))
    Right remote
      | Text.toUpper remote.remotePullRequestState == "MERGED" -> do
          issue <- runGhIssueView executor.actionRuntime issueConfig.issueRepo issueConfig.issueNumber
          case issue of
            Left reason ->
              observeWithExecutor
                executor
                config
                events
                (DaemonIssueImplementObservation (ObservedIssueImplementBlocked (BlockedReason ("PR merged but GitHub issue close state could not be verified: " <> reason))))
            Right remoteIssue
              | remoteIssue.remoteIssueClosed || Text.toUpper remoteIssue.remoteIssueState == "CLOSED" ->
                  observeWithExecutor executor config events (DaemonIssueImplementObservation (ObservedPullRequestMerged prNumber))
              | otherwise ->
                  observeWithExecutor
                    executor
                    config
                    events
                    (DaemonIssueImplementObservation (ObservedIssueImplementBlocked (BlockedReason "PR merged but GitHub issue remains open")))
      | otherwise ->
          idle executor config replay ("waiting for PR merge before completing issue implementer: #" <> Text.pack (show (unPrNumber prNumber)))

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
    StartIssueTriageWorkerTurnKind -> SomeEffect (StartIssueTriageWorkerTurn threadId)
    StartIssuePlanWorkerTurnKind issueConfig -> SomeEffect (StartIssuePlanWorkerTurn issueConfig threadId)
    StartIssueImplementationWorkerTurnKind -> SomeEffect (StartIssueImplementationWorkerTurn threadId)
    StartReviewerTurnKind prConfig reviewTargetSha -> SomeEffect (StartReviewerTurn prConfig reviewTargetSha threadId)

syntheticTurnId :: StartTurnKind -> Int -> TurnId
syntheticTurnId kind requestId =
  TurnId ("dry-run-" <> kindText kind <> "-" <> Text.pack (show requestId))

kindText :: StartTurnKind -> Text
kindText = \case
  StartPlannerTurnKind -> "planner-turn"
  StartWorkerTurnKind -> "worker-turn"
  StartIssueTriageWorkerTurnKind -> "issue-triage-turn"
  StartIssuePlanWorkerTurnKind {} -> "issue-plan-turn"
  StartIssueImplementationWorkerTurnKind -> "issue-implementation-turn"
  StartReviewerTurnKind {} -> "reviewer-turn"

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
  case config.loopDaemonOptions.daemonExecutionMode of
    DryRunActions -> pure ()
    ExecuteActions ->
      mapM_ writeIdleCompatibility (compatibilityStateWrites config.loopDaemonOptions.daemonRuntimeConfig.effectRuntimeStateDir replay.replayState)
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
 where
  writeIdleCompatibility write =
    runtimeWriteJsonValue (actionRuntime executor) (compatibilityWritePath write) (compatibilityWriteValue write)

terminalStop
  :: Monad m
  => ActionExecutor m
  -> DaemonLoopConfig
  -> EventReplayResult
  -> Text
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
terminalStop executor config replay reason = do
  case config.loopDaemonOptions.daemonExecutionMode of
    DryRunActions -> pure ()
    ExecuteActions ->
      mapM_ writeTerminalCompatibility (compatibilityStateWrites config.loopDaemonOptions.daemonRuntimeConfig.effectRuntimeStateDir replay.replayState)
  let stopPlan = compileEffectPlan config.loopDaemonOptions.daemonRuntimeConfig [SomeEffect StopDaemon]
  reports <- executeCompiledEffectPlan executor config.loopDaemonOptions.daemonExecutionMode stopPlan
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
 where
  writeTerminalCompatibility write =
    runtimeWriteJsonValue (actionRuntime executor) (compatibilityWritePath write) (compatibilityWriteValue write)

formatDaemonLoopFailure :: DaemonLoopFailure -> Text
formatDaemonLoopFailure = \case
  DaemonLoopDaemonFailure failure -> formatDaemonFailure failure
  DaemonLoopExternalFailure reason -> "external observation failed: " <> reason
  DaemonLoopAppServerFailure failure -> formatAppServerClientFailure failure
  DaemonLoopMissingPlannerThread -> "issue planning loop requires a planner thread id"
  DaemonLoopUnexpectedStartPlan reason -> "unexpected start-turn plan: " <> reason
