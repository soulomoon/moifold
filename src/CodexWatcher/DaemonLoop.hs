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
import CodexWatcher.Logging qualified as Log
import CodexWatcher.PlanningGraphCanonical
import CodexWatcher.PrReviewWatcher
import CodexWatcher.Runtime (CommandReport (..), RuntimeCommand (..), RuntimeInterpreter (..), commandText, runtimeReadJsonValue, runtimeWriteJsonValue)
import CodexWatcher.RuntimeDefaults (defaultThreadStartOptions)
import CodexWatcher.TurnClassifier
import CodexWatcher.Types
import Control.Monad (filterM)
import Data.Aeson (FromJSON (..), Result (..), ToJSON (..), Value (..), eitherDecodeStrict', fromJSON, object, withObject, (.:), (.=))
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Foldable (toList)
import Data.List (find, nub)
import Data.Maybe (mapMaybe, maybeToList)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text.Encoding
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
  | StartIssuePlanWorkerTurnKind IssueConfig PrNumber
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
      case config.loopDaemonOptions.daemonExecutionMode of
        DryRunActions -> do
          planner <- ensurePlannerThread executor config
          case planner of
            Left failure -> pure (Left failure)
            Right (plannerThread, plannerConfig', plannerReports) ->
              prependActionReports plannerReports
                <$> prestartAndObserve
                  executor
                  plannerConfig'
                  events
                  StartPlannerTurnKind
                  plannerThread
                  (DaemonIssuePlanningObservation . ObservedPlanningTurnStarted plannerThread)
        ExecuteActions -> do
          snapshot <- ensureIssuePlanningSnapshot executor config plannerConfig
          case snapshot of
            Left failure -> pure (Left failure)
            Right snapshotValue ->
              case planningSnapshotScopeCompleted plannerConfig snapshotValue of
                Right True ->
                  observeWithExecutor executor config events (DaemonIssuePlanningObservation ObservedPlanningScopeCompleted)
                Right False -> do
                  planner <- ensurePlannerThread executor config
                  case planner of
                    Left failure -> pure (Left failure)
                    Right (plannerThread, plannerConfig', plannerReports) ->
                      prependActionReports plannerReports
                        <$> prestartAndObserve
                          executor
                          plannerConfig'
                          events
                          StartPlannerTurnKind
                          plannerThread
                          (DaemonIssuePlanningObservation . ObservedPlanningTurnStarted plannerThread)
                Left reason ->
                  pure (Left (DaemonLoopExternalFailure ("could not evaluate issue planning snapshot completeness: " <> reason)))
    SomeWatcherState (PlanningTurnActive plannerConfig activeTurn) ->
      observePlanningActiveTurn executor config events replay plannerConfig activeTurn
    SomeWatcherState (PlanningWaitingForReadyIssues {}) ->
      idle executor config replay "issue planning is waiting for ready issues"
    SomeWatcherState (IssueReadyToPlan issueConfig prNumber (WorkerIdle workerThread)) ->
      prestartAndObserve executor config events (StartIssuePlanWorkerTurnKind issueConfig prNumber) workerThread (DaemonIssueImplementObservation . ObservedPlanTurnStarted)
    SomeWatcherState (IssueInPlanMode _issueConfig _prNumber (WorkerActive activeTurn)) ->
      observeIssuePlanActiveTurn executor config events replay activeTurn
    SomeWatcherState (IssuePlanReady issueConfig prNumber (WorkerIdle _workerThread)) ->
      updatePullRequestBody executor config events replay issueConfig prNumber
    SomeWatcherState (IssueImplementationReady issueConfig Nothing _worker) ->
      observeExistingPullRequest executor config events replay issueConfig
    SomeWatcherState (IssueImplementationReady _issueConfig (Just _prNumber) (WorkerIdle workerThread)) ->
      prestartAndObserve executor config events StartIssueImplementationWorkerTurnKind workerThread (DaemonIssueImplementObservation . ObservedImplementationTurnStarted)
    SomeWatcherState (IssueImplementing _issueConfig maybePr (WorkerActive activeTurn)) ->
      observeActiveTurn executor config events replay activeTurn (fmap DaemonIssueImplementObservation . classifyIssueImplementationTurn maybePr)
    SomeWatcherState (IssueHandoffReady _issueConfig prNumber) ->
      observeWithExecutor executor config events (DaemonIssueImplementObservation (ObservedReviewHandoffInitialized prNumber))
    SomeWatcherState (IssueHandoffInitialized _issueConfig prNumber) ->
      observeWithExecutor executor config events (DaemonIssueImplementObservation (ObservedReviewHandoffStarted prNumber))
    SomeWatcherState (IssueWaitingForPrMerge issueConfig prNumber) ->
      observeIssuePullRequestMerged executor config events replay issueConfig prNumber
    SomeWatcherState (IssueWaitingForIssueClose issueConfig prNumber) ->
      observeIssueClosed executor config events replay issueConfig prNumber
    SomeWatcherState (PrCheckingReviews prConfig (WorkerIdle workerThread) (ReviewerIdle reviewerThread)) ->
      observeReviewThreads executor config events prConfig workerThread reviewerThread
    SomeWatcherState (PrFixingReviews _prConfig _evidence (WorkerActive activeTurn) _reviewer) ->
      observeActiveTurn executor config events replay activeTurn (fmap DaemonPrReviewObservation . classifyPrReviewWorkerTurn)
    SomeWatcherState (PrReviewingClean _prConfig commit _worker (ReviewerActive activeTurn)) ->
      observeActiveTurn executor config events replay activeTurn (fmap DaemonPrReviewObservation . classifyPrReviewReviewerTurn commit)
    SomeWatcherState (PrWaitingForMergeability prConfig evidence _worker _reviewer) ->
      observeMergeability executor config events prConfig evidence
    SomeWatcherState (PrMerging prConfig _evidence) ->
      observeMergeCompletion executor config events replay prConfig
    SomeWatcherState (BlockedState {}) ->
      terminalStop executor config replay "watcher is blocked"
    SomeWatcherState (CompleteState {}) ->
      terminalStop executor config replay "watcher is complete"
    SomeWatcherState (StoppedState {}) ->
      terminalStop executor config replay "watcher is stopped"

ensurePlannerThread
  :: Monad m
  => ActionExecutor m
  -> DaemonLoopConfig
  -> m (Either DaemonLoopFailure (ThreadId, DaemonLoopConfig, [ActionExecutionReport]))
ensurePlannerThread executor config =
  case config.loopPlannerThreadId of
    Just threadId ->
      pure (Right (threadId, config, []))
    Nothing ->
      startPlannerThread executor config

startPlannerThread
  :: Monad m
  => ActionExecutor m
  -> DaemonLoopConfig
  -> m (Either DaemonLoopFailure (ThreadId, DaemonLoopConfig, [ActionExecutionReport]))
startPlannerThread executor config = do
  let runtimeConfig = config.loopDaemonOptions.daemonRuntimeConfig
      requestId = runtimeConfig.effectRuntimeNextRequestId
      request =
        threadStartRequest
          requestId
          (defaultThreadStartOptions runtimeConfig.effectRuntimeWorkdir runtimeConfig.effectRuntimePlannerThreadInstructions)
      nextConfig = withRuntimeNextRequestId (requestId + 1) config
  report <- executePlannedAction executor config.loopDaemonOptions.daemonExecutionMode (PlannedAppServerRequest request)
  case config.loopDaemonOptions.daemonExecutionMode of
    DryRunActions ->
      pure (Right (syntheticPlannerThreadId requestId, nextConfig, [report]))
    ExecuteActions ->
      case report.actionExecutionResult of
        AppServerActionResult response ->
          case parseThreadStartThreadId response of
            Left failure -> pure (Left (DaemonLoopAppServerFailure failure))
            Right threadId -> pure (Right (threadId, nextConfig, [report]))
        _ ->
          pure (Left (DaemonLoopUnexpectedStartPlan ("planner thread start returned unexpected action result: " <> Text.pack (show report.actionExecutionResult))))

syntheticPlannerThreadId :: Int -> ThreadId
syntheticPlannerThreadId requestId =
  ThreadId ("dry-run-planner-thread-" <> Text.pack (show requestId))

withRuntimeNextRequestId :: Int -> DaemonLoopConfig -> DaemonLoopConfig
withRuntimeNextRequestId requestId config =
  config
    { loopDaemonOptions =
        config.loopDaemonOptions
          { daemonRuntimeConfig =
              config.loopDaemonOptions.daemonRuntimeConfig
                { effectRuntimeNextRequestId = requestId
                }
          }
    }

clearStaleActiveTurnMarkerWhenInactive :: Monad m => ActionExecutor m -> DaemonLoopConfig -> SomeWatcherState -> m ()
clearStaleActiveTurnMarkerWhenInactive executor config state =
  if watcherStateHasActiveTurn state
    then pure ()
    else clearStaleActiveTurnMarker executor config

watcherStateHasActiveTurn :: SomeWatcherState -> Bool
watcherStateHasActiveTurn = \case
  SomeWatcherState PlanningTurnActive {} -> True
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

observeIssuePlanActiveTurn
  :: Monad m
  => ActionExecutor m
  -> DaemonLoopConfig
  -> [WatcherEvent]
  -> EventReplayResult
  -> ActiveTurn
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
observeIssuePlanActiveTurn executor config events replay activeTurn = do
  turnResult <- readActiveTurn executor config activeTurn
  case turnResult of
    Left failure -> pure (Left failure)
    Right Nothing ->
      handleMissingActiveTurn executor config events replay activeTurn
    Right (Just turn) -> do
      clearStaleActiveTurnMarker executor config
      case classifyIssuePlanTurn turn of
        Nothing ->
          idle executor config replay ("active turn is not finished: " <> unTurnId activeTurn.activeTurnId)
        Just (ObservedPlanCompleted planMarkdown maybeImplementationTurnId) ->
          observeWithExecutor executor config events (DaemonIssueImplementObservation (ObservedPlanCompleted planMarkdown maybeImplementationTurnId))
        Just observation ->
          observeWithExecutor executor config events (DaemonIssueImplementObservation observation)

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
          normalized <- normalizePlanningObservation executor config plannerConfig observation
          observeWithExecutor executor config events (DaemonIssuePlanningObservation normalized)

normalizePlanningObservation :: Monad m => ActionExecutor m -> DaemonLoopConfig -> PlannerConfig -> IssuePlanningObservation -> m IssuePlanningObservation
normalizePlanningObservation executor config plannerConfig = \case
  ObservedPlanningGraphUpdated graph ->
    ObservedPlanningGraphUpdated <$> normalizePlanningGraph executor config plannerConfig graph
  observation ->
    pure observation

normalizePlanningGraph :: Monad m => ActionExecutor m -> DaemonLoopConfig -> PlannerConfig -> PlanningGraph -> m PlanningGraph
normalizePlanningGraph executor config plannerConfig graph
  | null plannerConfig.plannerScopeIssues =
      filterClosedPlanningDependencies executor plannerConfig graph
  | config.loopDaemonOptions.daemonExecutionMode == DryRunActions =
      filterClosedPlanningDependencies executor plannerConfig graph
  | otherwise = do
      snapshot <- buildIssuePlanningSnapshot executor plannerConfig
      case snapshot >>= planningIssueFactsFromSnapshot of
        Right facts ->
          pure (canonicalPlanningGraph plannerConfig facts graph)
        Left reason -> do
          Log.logWatcher
            executor.actionLogger
            ( Log.watcherLog
                Log.Warn
                "planning_graph_canonicalization_failed"
                "could not compute canonical planning graph; falling back to dependency filtering"
                ["reason" .= reason]
            )
          filterClosedPlanningDependencies executor plannerConfig graph

ensureIssuePlanningSnapshot :: Monad m => ActionExecutor m -> DaemonLoopConfig -> PlannerConfig -> m (Either DaemonLoopFailure Value)
ensureIssuePlanningSnapshot executor config plannerConfig =
  do
    snapshot <- buildIssuePlanningSnapshot executor plannerConfig
    case snapshot of
      Left reason -> pure (Left (DaemonLoopExternalFailure ("could not build issue planning snapshot: " <> reason)))
      Right value -> do
        case config.loopDaemonOptions.daemonExecutionMode of
          DryRunActions -> pure ()
          ExecuteActions ->
            runtimeWriteJsonValue (executor.actionRuntime) (issuePlanningSnapshotPath config) value
        pure (Right value)

issuePlanningSnapshotPath :: DaemonLoopConfig -> FilePath
issuePlanningSnapshotPath config =
  config.loopDaemonOptions.daemonRuntimeConfig.effectRuntimeStateDir </> "issue-snapshot.json"

planningSnapshotScopeCompleted :: PlannerConfig -> Value -> Either Text Bool
planningSnapshotScopeCompleted plannerConfig snapshotValue
  | null plannerConfig.plannerScopeIssues =
      Right False
  | otherwise = do
      facts <- planningIssueFactsFromSnapshot snapshotValue
      pure
        ( not (null facts)
            && all planningIssueFactClosed facts
        )

buildIssuePlanningSnapshot :: Monad m => ActionExecutor m -> PlannerConfig -> m (Either Text Value)
buildIssuePlanningSnapshot executor plannerConfig
  | null plannerConfig.plannerScopeIssues =
      pure
        ( Right
            ( object
                [ "repoFullName" .= unRepoName plannerConfig.plannerRepo
                , "scopeIssueNumbers" .= ([] :: [Int])
                , "issues" .= ([] :: [Value])
                , "note" .= ("No explicit issue scope was configured; planner may inspect GitHub open issues if needed." :: Text)
                ]
            )
        )
  | otherwise = do
      issues <- traverse (fetchScopedIssueSnapshot executor plannerConfig.plannerRepo) plannerConfig.plannerScopeIssues
      pure do
        issueValues <- sequence issues
        Right
          ( object
              [ "repoFullName" .= unRepoName plannerConfig.plannerRepo
              , "scopeIssueNumbers" .= fmap unIssueNumber plannerConfig.plannerScopeIssues
              , "issues" .= issueValues
              ]
          )

fetchScopedIssueSnapshot :: Monad m => ActionExecutor m -> RepoName -> IssueNumber -> m (Either Text Value)
fetchScopedIssueSnapshot executor repo issueNumber = do
  issue <- fetchIssueJson executor repo issueNumber
  subIssues <- fetchSubIssuesJson executor repo issueNumber
  pure do
    issueValue <- issue
    subIssueValue <- subIssues
    Right (issueValue `withObjectField` ("parentIssueNumber", Null) `withObjectField` ("subIssues", arrayOrEmpty subIssueValue))

fetchIssueJson :: Monad m => ActionExecutor m -> RepoName -> IssueNumber -> m (Either Text Value)
fetchIssueJson executor repo issueNumber =
  runJsonCommand
    executor
    ("issue #" <> issueNumberText issueNumber)
    ( RawCommand
        "gh"
        [ "issue"
        , "view"
        , show (unIssueNumber issueNumber)
        , "--repo"
        , Text.unpack (unRepoName repo)
        , "--json"
        , "number,title,state,closed,body,url,labels,assignees,createdAt,updatedAt"
        ]
        Nothing
    )

fetchSubIssuesJson :: Monad m => ActionExecutor m -> RepoName -> IssueNumber -> m (Either Text Value)
fetchSubIssuesJson executor repo issueNumber =
  runJsonCommand
    executor
    ("sub-issues for #" <> issueNumberText issueNumber)
    ( RawCommand
        "gh"
        [ "api"
        , "repos/" <> Text.unpack (unRepoName repo) <> "/issues/" <> show (unIssueNumber issueNumber) <> "/sub_issues"
        , "--paginate"
        , "--jq"
        , "[.[] | {number,title,state,closed:(.closed_at != null),body,url:.html_url,parentIssueNumber:" <> show (unIssueNumber issueNumber) <> "}]"
        ]
        Nothing
    )

runJsonCommand :: Monad m => ActionExecutor m -> Text -> RuntimeCommand -> m (Either Text Value)
runJsonCommand executor label command = do
  report <- executor.actionRuntime.runtimeRunCommand command
  pure
    if report.ok
      then decodeJsonReport label report.stdout
      else Left (label <> " command failed: " <> commandText report)

decodeJsonReport :: Text -> Text -> Either Text Value
decodeJsonReport label output =
  case eitherDecodeStrict' (Text.Encoding.encodeUtf8 output) of
    Left errorMessage -> Left (label <> " returned invalid JSON: " <> Text.pack errorMessage)
    Right value -> Right value

withObjectField :: Value -> (Text, Value) -> Value
withObjectField (Object fields) (key, value) =
  Object (KeyMap.insert (Key.fromText key) value fields)
withObjectField value (key, fieldValue) =
  object [Key.fromText key .= fieldValue, "value" .= value]

arrayOrEmpty :: Value -> Value
arrayOrEmpty value@Array {} = value
arrayOrEmpty _ = toJSON ([] :: [Value])

issueNumberText :: IssueNumber -> Text
issueNumberText =
  Text.pack . show . unIssueNumber

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
      Log.logWatcher
        executor.actionLogger
        ( Log.watcherLog
            Log.Warn
            "stale_active_turn_seen"
            "active turn was not found"
            [ "turnId" .= unTurnId activeTurn.activeTurnId
            , "threadId" .= unThreadId activeTurn.activeThreadId
            , "count" .= marker.staleMarkerCount
            ]
        )
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

observeMergeability
  :: Monad m
  => ActionExecutor m
  -> DaemonLoopConfig
  -> [WatcherEvent]
  -> PrConfig
  -> CleanReviewEvidence
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
observeMergeability executor config events prConfig evidence = do
  gate <- runPreMergeGate executor prConfig evidence
  let observation =
        case gate of
          PreMergeGatePassed ->
            ObservedMergeabilityClean evidence.cleanReviewCommit
          PreMergeGateRetry reason ->
            ObservedMergeabilityRetry reason
          PreMergeGateRecheck reason ->
            ObservedMergeabilityRecheck reason
          PreMergeGateBlocked reason ->
            ObservedPrReviewBlocked (BlockedReason reason)
  observeWithExecutor executor config events (DaemonPrReviewObservation observation)

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
        Just pullRequest -> do
          linked <- validateExistingPullRequestLink executor issueConfig pullRequest
          case linked of
            Left reason ->
              pure (Left (DaemonLoopExternalFailure reason))
            Right True ->
              observeWithExecutor
                executor
                config
                events
                (DaemonIssueImplementObservation (ObservedPullRequestReused pullRequest.ghPullRequestNumber))
            Right False ->
              observeWithExecutor
                executor
                config
                events
                ( DaemonIssueImplementObservation
                    ( ObservedIssueImplementBlocked
                        ( BlockedReason
                            ( "open PR #"
                                <> Text.pack (show (unPrNumber pullRequest.ghPullRequestNumber))
                                <> " already uses branch "
                                <> unBranchName issueConfig.issueBranch
                                <> " but is not linked to issue #"
                                <> Text.pack (show (unIssueNumber issueConfig.issueNumber))
                            )
                        )
                    )
                )

validateExistingPullRequestLink :: Monad m => ActionExecutor m -> IssueConfig -> GhPullRequest -> m (Either Text Bool)
validateExistingPullRequestLink executor issueConfig pullRequest
  | pullRequestLinkedToIssue issueConfig pullRequest =
      pure (Right True)
  | otherwise = do
      report <-
        executor.actionRuntime.runtimeRunCommand
          (GhPrView issueConfig.issueRepo pullRequest.ghPullRequestNumber ["body", "closingIssuesReferences"])
      pure do
        if report.ok
          then pullRequestLinkJsonLinksIssue issueConfig.issueNumber <$> decodeJsonReport ("PR #" <> Text.pack (show (unPrNumber pullRequest.ghPullRequestNumber))) report.stdout
          else Left ("could not validate existing PR link: " <> commandText report)

pullRequestLinkedToIssue :: IssueConfig -> GhPullRequest -> Bool
pullRequestLinkedToIssue issueConfig pullRequest =
  issueConfig.issueNumber `elem` pullRequest.ghPullRequestLinkedIssueNumbers
    || maybe False (bodyLinksIssue issueConfig.issueNumber) pullRequest.ghPullRequestBody

pullRequestLinkJsonLinksIssue :: IssueNumber -> Value -> Bool
pullRequestLinkJsonLinksIssue issueNumber value =
  issueNumber `elem` jsonLinkedIssueNumbers value
    || maybe False (bodyLinksIssue issueNumber) (jsonTextField "body" value)

jsonLinkedIssueNumbers :: Value -> [IssueNumber]
jsonLinkedIssueNumbers value =
  case jsonField "closingIssuesReferences" value of
    Just (Array references) -> mapMaybe jsonIssueNumber (toList references)
    _ -> []

jsonIssueNumber :: Value -> Maybe IssueNumber
jsonIssueNumber (Object objectValue) = do
  value <- KeyMap.lookup (Key.fromText "number") objectValue
  case fromJSON value of
    Success number -> Just (IssueNumber number)
    Error _ -> Nothing
jsonIssueNumber _ = Nothing

jsonTextField :: Text -> Value -> Maybe Text
jsonTextField key value = do
  String text <- jsonField key value
  pure text

jsonField :: Text -> Value -> Maybe Value
jsonField key (Object objectValue) =
  KeyMap.lookup (Key.fromText key) objectValue
jsonField _ _ =
  Nothing

bodyLinksIssue :: IssueNumber -> Text -> Bool
bodyLinksIssue issueNumber body =
  any (`Text.isInfixOf` normalizedBody) linkPhrases
 where
  issueRef = "#" <> Text.pack (show (unIssueNumber issueNumber))
  normalizedBody = Text.toLower body
  linkPhrases =
    [ "close " <> issueRef
    , "closes " <> issueRef
    , "closed " <> issueRef
    , "fix " <> issueRef
    , "fixes " <> issueRef
    , "fixed " <> issueRef
    , "resolve " <> issueRef
    , "resolves " <> issueRef
    , "resolved " <> issueRef
    ]

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

updatePullRequestBody
  :: Monad m
  => ActionExecutor m
  -> DaemonLoopConfig
  -> [WatcherEvent]
  -> EventReplayResult
  -> IssueConfig
  -> PrNumber
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
updatePullRequestBody executor config events replay issueConfig prNumber = do
  let planRecordEffects =
        [ SomeEffect (RecordIssuePlan issueConfig prNumber planMarkdown)
        | planMarkdown <- maybeToList (latestIssuePlanMarkdown events)
        ]
  let updatePlan =
        compileEffectPlan
          config.loopDaemonOptions.daemonRuntimeConfig
          (planRecordEffects <> [SomeEffect (UpdatePullRequestBody issueConfig prNumber)])
  reports <- executeCompiledEffectPlan executor config.loopDaemonOptions.daemonExecutionMode updatePlan
  case config.loopDaemonOptions.daemonExecutionMode of
    DryRunActions ->
      pure
        ( Right
            DaemonLoopTickResult
              { loopReplayResult = replay
              , loopObservation = Nothing
              , loopObservedTick = Nothing
              , loopIdleReason = Just ("would update pull request body for PR #" <> Text.pack (show (unPrNumber prNumber)))
              , loopActionReports = reports
              }
        )
    ExecuteActions ->
      case finalCommandReport reports of
        Nothing ->
          pure (Left (DaemonLoopExternalFailure "PR body update did not return a command report"))
        Just (report, commandReport)
          | not commandReport.ok ->
              pure (Left (DaemonLoopDaemonFailure (DaemonActionFailed report.actionExecutionAction commandReport)))
          | otherwise ->
              prependActionReports reports <$> observeWithExecutor executor config events (DaemonIssueImplementObservation (ObservedPullRequestBodyUpdated prNumber))

latestIssuePlanMarkdown :: [WatcherEvent] -> Maybe Text
latestIssuePlanMarkdown =
  foldl' step Nothing
 where
  step _latestPlan (IssuePlanCompletedEvent planMarkdown _maybeImplementationTurn) = Just planMarkdown
  step latestPlan _event = latestPlan

finalCommandReport :: [ActionExecutionReport] -> Maybe (ActionExecutionReport, CommandReport)
finalCommandReport reports =
  case reverse reports of
    [] -> Nothing
    report : _ ->
      case report.actionExecutionResult of
        CommandActionResult commandReport -> Just (report, commandReport)
        _ -> Nothing

prependActionReport :: ActionExecutionReport -> Either DaemonLoopFailure DaemonLoopTickResult -> Either DaemonLoopFailure DaemonLoopTickResult
prependActionReport report =
  fmap \tick -> tick {loopActionReports = report : tick.loopActionReports}

prependActionReports :: [ActionExecutionReport] -> Either DaemonLoopFailure DaemonLoopTickResult -> Either DaemonLoopFailure DaemonLoopTickResult
prependActionReports reports =
  fmap \tick -> tick {loopActionReports = reports <> tick.loopActionReports}

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
      | Text.toUpper remote.remotePullRequestState == "MERGED" ->
          observeWithExecutor executor config events (DaemonIssueImplementObservation (ObservedPullRequestMerged prNumber))
      | otherwise ->
          idle executor config replay ("waiting for PR merge before closing issue: #" <> Text.pack (show (unPrNumber prNumber)))

observeIssueClosed
  :: Monad m
  => ActionExecutor m
  -> DaemonLoopConfig
  -> [WatcherEvent]
  -> EventReplayResult
  -> IssueConfig
  -> PrNumber
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
observeIssueClosed executor config events replay issueConfig prNumber = do
  issue <- runGhIssueView executor.actionRuntime issueConfig.issueRepo issueConfig.issueNumber
  case issue of
    Left reason -> pure (Left (DaemonLoopExternalFailure reason))
    Right remote
      | remoteIssueIsClosed remote ->
          observeWithExecutor executor config events (DaemonIssueImplementObservation (ObservedIssueClosed prNumber))
      | otherwise ->
          retryCloseIssue executor config replay issueConfig prNumber

retryCloseIssue
  :: Monad m
  => ActionExecutor m
  -> DaemonLoopConfig
  -> EventReplayResult
  -> IssueConfig
  -> PrNumber
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
retryCloseIssue executor config replay issueConfig prNumber = do
  let closePlan =
        compileEffectPlan
          config.loopDaemonOptions.daemonRuntimeConfig
          [ SomeEffect (CloseIssue issueConfig prNumber)
          , SomeEffect SleepUntilNextPoll
          ]
  reports <- executeCompiledEffectPlan executor config.loopDaemonOptions.daemonExecutionMode closePlan
  pure case config.loopDaemonOptions.daemonExecutionMode of
    DryRunActions ->
      Right
        DaemonLoopTickResult
          { loopReplayResult = replay
          , loopObservation = Nothing
          , loopObservedTick = Nothing
          , loopIdleReason = Just ("would close issue after merged PR #" <> Text.pack (show (unPrNumber prNumber)))
          , loopActionReports = reports
          }
    ExecuteActions ->
      case firstCommandFailure reports of
        Just failure -> Left (DaemonLoopDaemonFailure failure)
        Nothing ->
          Right
            DaemonLoopTickResult
              { loopReplayResult = replay
              , loopObservation = Nothing
              , loopObservedTick = Nothing
              , loopIdleReason = Just ("closed issue after merged PR #" <> Text.pack (show (unPrNumber prNumber)) <> "; waiting to observe closed issue")
              , loopActionReports = reports
              }

firstCommandFailure :: [ActionExecutionReport] -> Maybe DaemonFailure
firstCommandFailure [] =
  Nothing
firstCommandFailure (report : rest) =
  case report.actionExecutionResult of
    CommandActionResult commandReport
      | not commandReport.ok ->
          Just (DaemonActionFailed report.actionExecutionAction commandReport)
    _ ->
      firstCommandFailure rest

remoteIssueIsClosed :: RemoteIssue -> Bool
remoteIssueIsClosed issue =
  issue.remoteIssueClosed || Text.toUpper issue.remoteIssueState == "CLOSED"

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
    StartIssuePlanWorkerTurnKind issueConfig prNumber -> SomeEffect (StartIssuePlanWorkerTurn issueConfig prNumber threadId)
    StartIssueImplementationWorkerTurnKind -> SomeEffect (StartIssueImplementationWorkerTurn threadId)
    StartReviewerTurnKind prConfig reviewTargetSha -> SomeEffect (StartReviewerTurn prConfig reviewTargetSha threadId)

syntheticTurnId :: StartTurnKind -> Int -> TurnId
syntheticTurnId kind requestId =
  TurnId ("dry-run-" <> kindText kind <> "-" <> Text.pack (show requestId))

kindText :: StartTurnKind -> Text
kindText = \case
  StartPlannerTurnKind -> "planner-turn"
  StartWorkerTurnKind -> "worker-turn"
  StartIssuePlanWorkerTurnKind {} -> "issue-plan-turn"
  StartIssueImplementationWorkerTurnKind -> "issue-implementation-turn"
  StartReviewerTurnKind {} -> "reviewer-turn"

readActiveTurn :: Monad m => ActionExecutor m -> DaemonLoopConfig -> ActiveTurn -> m (Either DaemonLoopFailure (Maybe AppServerTurn))
readActiveTurn executor config activeTurn = do
  response <-
    executor.actionAppServer.appServerSendRequest
      (threadReadRequest config.loopDaemonOptions.daemonRuntimeConfig.effectRuntimeNextRequestId activeTurn.activeThreadId True)
  pure case threadSystemError response of
    Just status ->
      Right
        ( Just
            ( AppServerTurn
                activeTurn.activeTurnId
                "failed"
                (Just ("app-server thread entered systemError: " <> status))
            )
        )
    Nothing ->
      case parseThreadReadTurns response of
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
  Log.logWatcher
    executor.actionLogger
    ( Log.watcherLog
        Log.Info
        "observation_classified"
        "automatic loop classified an observation"
        ["observation" .= Text.pack (show observation)]
    )
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
  Log.logWatcher
    executor.actionLogger
    ( Log.watcherLog
        Log.Debug
        "loop_idle"
        "automatic loop tick is idle"
        [ "reason" .= reason
        , "domain" .= Text.pack (show (someDomain replay.replayState))
        , "phase" .= Text.pack (show (somePhase replay.replayState))
        ]
    )
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
  Log.logWatcher
    executor.actionLogger
    ( Log.watcherLog
        Log.Info
        "loop_terminal"
        "automatic loop reached terminal state"
        [ "reason" .= reason
        , "domain" .= Text.pack (show (someDomain replay.replayState))
        , "phase" .= Text.pack (show (somePhase replay.replayState))
        ]
    )
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
