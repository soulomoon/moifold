{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Domain.IssuePlanning.Loop
  ( planningRetryAvailable
  , runPlanningActive
  , runPlanningReady
  , runPlanningWaiting
  ) where

import CodexWatcher.ActionExecutor
import CodexWatcher.AppServerClient
import CodexWatcher.AppServerProtocol
import CodexWatcher.Daemon (DaemonObservation (..), DaemonOptions (..))
import CodexWatcher.DaemonLoop.Types
import CodexWatcher.EffectInterpreter
import CodexWatcher.EventLog.Types
import CodexWatcher.GhGit
import CodexWatcher.Domain.IssuePlanning.Graph.Canonical
import CodexWatcher.Domain.IssuePlanning.TurnClassifier
import CodexWatcher.Domain.IssuePlanning.Watcher
import CodexWatcher.Logging qualified as Log
import CodexWatcher.Runtime.Command.Render (commandText)
import CodexWatcher.Runtime.Command.Types (CommandReport (..), RuntimeCommand (..))
import CodexWatcher.Runtime.Interpreter (RuntimeInterpreter (..))
import CodexWatcher.Runtime.Json (decodeJsonText)
import CodexWatcher.Runtime.Defaults (defaultThreadStartOptions)
import CodexWatcher.Core.Types
import Control.Monad (filterM)
import Data.Aeson (Value (..), object, toJSON, (.=))
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.List (nub)
import Data.Text (Text)
import Data.Text qualified as Text

runPlanningReady
  :: Monad m
  => DomainLoopOps m
  -> ActionExecutor m
  -> DaemonLoopConfig
  -> [WatcherEvent]
  -> EventReplayResult
  -> PlannerConfig
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
runPlanningReady ops executor config events _replay plannerConfig =
  case config.loopDaemonOptions.daemonExecutionMode of
    DryRunActions ->
      startPlannerTurn ops executor config events
    ExecuteActions -> do
      snapshot <- ensureIssuePlanningSnapshot executor config plannerConfig
      case snapshot of
        Left failure -> pure (Left failure)
        Right snapshotValue ->
          case planningSnapshotScopeCompleted plannerConfig snapshotValue of
            Right True ->
              ops.loopObserveWithExecutor executor config events (DaemonIssuePlanningObservation ObservedPlanningScopeCompleted)
            Right False ->
              startPlannerTurn ops executor config events
            Left reason ->
              pure (Left (DaemonLoopExternalFailure ("could not evaluate issue planning snapshot completeness: " <> reason)))

startPlannerTurn
  :: Monad m
  => DomainLoopOps m
  -> ActionExecutor m
  -> DaemonLoopConfig
  -> [WatcherEvent]
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
startPlannerTurn ops executor config events = do
  planner <- ensurePlannerThread executor config
  case planner of
    Left failure ->
      pure (Left failure)
    Right (plannerThread, plannerConfig, plannerReports) ->
      withPrependedActionReports plannerReports
        <$> ops.loopPrestartAndObserve
          executor
          plannerConfig
          events
          StartPlannerTurnKind
          plannerThread
          (DaemonIssuePlanningObservation . ObservedPlanningTurnStarted plannerThread)

runPlanningActive
  :: Monad m
  => DomainLoopOps m
  -> ActionExecutor m
  -> DaemonLoopConfig
  -> [WatcherEvent]
  -> EventReplayResult
  -> PlannerConfig
  -> ActiveTurn
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
runPlanningActive ops executor config events replay plannerConfig activeTurn = do
  turnResult <- ops.loopReadActiveTurn executor config activeTurn
  case turnResult of
    Left failure -> pure (Left failure)
    Right readResult ->
      case readResult.activeTurnReadThreadSystemError of
        Just status
          | Just observation <- planningSystemErrorObservation events status readResult.activeTurnReadTurn ->
              ops.loopClearActiveTurnMarker executor config *>
              ops.loopObserveWithExecutor executor config events (DaemonIssuePlanningObservation observation)
        _ ->
          case readResult.activeTurnReadTurn of
            Nothing ->
              ops.loopHandleMissingActiveTurn executor config events replay activeTurn
            Just turn -> do
              ops.loopClearActiveTurnMarker executor config
              case classifyIssuePlanningTurn turn of
                Nothing ->
                  ops.loopIdle executor config replay ("active turn is not finished: " <> unTurnId (activeTurn.activeTurnId))
                Just observation -> do
                  normalized <- normalizePlanningObservation executor config plannerConfig observation
                  ops.loopObserveWithExecutor executor config events (DaemonIssuePlanningObservation normalized)

runPlanningWaiting
  :: DomainLoopOps m
  -> ActionExecutor m
  -> DaemonLoopConfig
  -> EventReplayResult
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
runPlanningWaiting ops executor config replay =
  ops.loopIdle executor config replay "issue planning is waiting for ready issues"

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
          (defaultThreadStartOptions (runtimeCwdPath runtimeConfig.effectRuntimePlannerTurn.turnRuntimeCwd) runtimeConfig.effectRuntimePlannerThreadInstructions)
      nextConfig = withRuntimeNextRequestId (nextRequestId requestId) config
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

syntheticPlannerThreadId :: RequestId -> ThreadId
syntheticPlannerThreadId requestId =
  ThreadId ("dry-run-planner-thread-" <> Text.pack (show (unRequestId requestId)))

withRuntimeNextRequestId :: RequestId -> DaemonLoopConfig -> DaemonLoopConfig
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
ensureIssuePlanningSnapshot executor config plannerConfig = do
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
  runtimeStateDirFile config.loopDaemonOptions.daemonRuntimeConfig.effectRuntimeStateDir "issue-snapshot.json"

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
      then decodeJsonText label report.stdout
      else Left (label <> " command failed: " <> commandText report)

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
      Right remote -> remoteIssueIsClosed remote
      Left _reason -> False

planningSystemErrorObservation :: [WatcherEvent] -> Text -> Maybe AppServerTurn -> Maybe IssuePlanningObservation
planningSystemErrorObservation events status maybeTurn =
  case maybeTurn of
    Nothing ->
      Just (planningSystemErrorRecoveryObservation events status)
    Just turn ->
      case classifyIssuePlanningTurn turn of
        Nothing ->
          Just (planningSystemErrorRecoveryObservation events status)
        Just observation
          | retryablePlanningSystemErrorObservation observation ->
              Just (planningSystemErrorRecoveryObservation events status)
          | otherwise ->
              Nothing

planningSystemErrorRecoveryObservation :: [WatcherEvent] -> Text -> IssuePlanningObservation
planningSystemErrorRecoveryObservation events status
  | planningRetryAvailable events =
      ObservedPlanningTurnRetryRequested (BlockedReason ("retrying planner turn after app-server systemError: " <> status))
  | otherwise =
      ObservedPlanningBlocked (BlockedReason ("app-server thread entered systemError: " <> status))

retryablePlanningSystemErrorObservation :: IssuePlanningObservation -> Bool
retryablePlanningSystemErrorObservation = \case
  ObservedPlanningBlocked (BlockedReason reason) ->
    normalizedPlanningRetryReason reason `elem` planningSystemErrorRetryReasons
  _ ->
    False

maxPlanningTurnRetries :: Int
maxPlanningTurnRetries = 1

planningRetryAvailable :: [WatcherEvent] -> Bool
planningRetryAvailable events =
  planningRetryCount events < maxPlanningTurnRetries

planningRetryCount :: [WatcherEvent] -> Int
planningRetryCount =
  go 0 . reverse
 where
  go count [] = count
  go count (IssuePlanningTurnStarted {} : rest) = go count rest
  go count (IssuePlanningTurnRetryRequested {} : rest) = go (count + 1) rest
  go count (_ : _) = count

planningSystemErrorRetryReasons :: [Text]
planningSystemErrorRetryReasons =
  [ "planning turn completed without output"
  , "planning turn completed without structured outcome"
  ]

normalizedPlanningRetryReason :: Text -> Text
normalizedPlanningRetryReason =
  Text.toLower . Text.strip
