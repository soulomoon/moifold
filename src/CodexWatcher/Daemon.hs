{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Daemon
  ( DaemonFailure (..)
  , DaemonObservation (..)
  , DaemonOptions (..)
  , DaemonObservedTickResult (..)
  , PreMergeGateResult (..)
  , DaemonTickResult (..)
  , appendWatcherEvent
  , formatDaemonFailure
  , replayDaemonEventLog
  , runObservedDaemonTickFromFile
  , runObservedDaemonTickWithEvents
  , runDaemonTickFromFile
  , runDaemonTickWithEvents
  , runPreMergeGate
  ) where

import CodexWatcher.ActionExecutor
import CodexWatcher.Runtime.Compatibility
import CodexWatcher.EffectInterpreter
import CodexWatcher.Effects
import CodexWatcher.EventLog.File (loadEventLogFile)
import CodexWatcher.EventLog.Replay (replayEventLog)
import CodexWatcher.EventLog.Types
import CodexWatcher.GhGit
import CodexWatcher.Domain.IssueImplement.Watcher
import CodexWatcher.Domain.IssuePlanning.Watcher
import CodexWatcher.Logging qualified as Log
import CodexWatcher.Domain.PrReview.Watcher
import CodexWatcher.Runtime.Command.Render (commandText)
import CodexWatcher.Runtime.Command.Types (CommandReport (..))
import CodexWatcher.Runtime.Interpreter (RuntimeInterpreter (..))
import CodexWatcher.Runtime.Paths (runtimeStateDirPath)
import CodexWatcher.Core.Ids (CommitSha (..))
import CodexWatcher.Core.State (SomeWatcherState, someDomain, somePhase)
import CodexWatcher.Domain.PrReview.Types (CleanReviewEvidence (..), PrConfig (..))
import Data.Aeson (toJSON)
import Data.Aeson ((.=))
import Data.List (partition)
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)

data DaemonOptions = DaemonOptions
  { daemonEventLogPath :: FilePath
  , daemonRuntimeConfig :: EffectRuntimeConfig
  , daemonExecutionMode :: ActionExecutionMode
  }
  deriving stock (Eq, Show, Generic)

data DaemonFailure
  = DaemonEventLogDecodeFailed Text
  | DaemonReplayFailed ReplayFailure
  | DaemonObservationRejected Text
  | DaemonActionFailed PlannedAction CommandReport
  | DaemonActionResultInvalid PlannedAction Text
  deriving stock (Eq, Show, Generic)

data DaemonObservation
  = DaemonPrReviewObservation PrReviewObservation
  | DaemonIssueImplementObservation IssueImplementObservation
  | DaemonIssuePlanningObservation IssuePlanningObservation
  deriving stock (Eq, Show, Generic)

data DaemonTickResult = DaemonTickResult
  { daemonReplayResult :: EventReplayResult
  , daemonCompiledEffects :: CompiledEffectPlan
  , daemonActionReports :: [ActionExecutionReport]
  }
  deriving stock (Show, Generic)

data DaemonObservedTickResult = DaemonObservedTickResult
  { daemonObservedReplayResult :: EventReplayResult
  , daemonObservedEvent :: WatcherEvent
  , daemonObservedState :: SomeWatcherState
  , daemonObservedCompatibilityWrites :: [CompatibilityWrite]
  , daemonObservedCompiledEffects :: CompiledEffectPlan
  , daemonObservedActionReports :: [ActionExecutionReport]
  }
  deriving stock (Show, Generic)

runDaemonTickFromFile :: ActionExecutor IO -> DaemonOptions -> EffectPlan -> IO (Either DaemonFailure DaemonTickResult)
runDaemonTickFromFile executor options nextEffects = do
  loaded <- loadEventLogFile options.daemonEventLogPath
  case loaded of
    Left errorMessage -> pure (Left (DaemonEventLogDecodeFailed (Text.pack errorMessage)))
    Right events ->
      runDaemonTickWithEvents
        executor
        options.daemonRuntimeConfig
        options.daemonExecutionMode
        events
        nextEffects

runDaemonTickWithEvents
  :: Monad m
  => ActionExecutor m
  -> EffectRuntimeConfig
  -> ActionExecutionMode
  -> [WatcherEvent]
  -> EffectPlan
  -> m (Either DaemonFailure DaemonTickResult)
runDaemonTickWithEvents executor runtimeConfig executionMode events nextEffects =
  case replayEventLogFromEvents events of
    Left failure -> do
      logDaemonFailure executor "daemon_replay_failed" "daemon tick replay failed" failure
      pure (Left failure)
    Right replay -> do
      logReplaySucceeded executor "daemon_replay_succeeded" events replay
      let compiledEffects = compileEffectPlan runtimeConfig nextEffects
      actionReportsResult <-
        case executionMode of
          DryRunActions -> Right <$> executeCompiledEffectPlan executor DryRunActions compiledEffects
          ExecuteActions -> executeCheckedActions executor compiledEffects.compiledActions
      case actionReportsResult of
        Left failure -> do
          logDaemonFailure executor "daemon_tick_failed" "daemon tick failed" failure
          pure (Left failure)
        Right actionReports -> do
          Log.logWatcher
            executor.actionLogger
            ( Log.watcherLog
                Log.Info
                "daemon_tick_finished"
                "daemon tick finished"
                [ "domain" .= Text.pack (show (someDomain replay.replayState))
                , "phase" .= Text.pack (show (somePhase replay.replayState))
                , "actions" .= length actionReports
                ]
            )
          pure
            ( Right
                DaemonTickResult
                  { daemonReplayResult = replay
                  , daemonCompiledEffects = compiledEffects
                  , daemonActionReports = actionReports
                  }
            )

runObservedDaemonTickFromFile :: ActionExecutor IO -> DaemonOptions -> DaemonObservation -> IO (Either DaemonFailure DaemonObservedTickResult)
runObservedDaemonTickFromFile executor options observation = do
  loaded <- loadEventLogFile options.daemonEventLogPath
  case loaded of
    Left errorMessage -> pure (Left (DaemonEventLogDecodeFailed (Text.pack errorMessage)))
    Right events ->
      runObservedDaemonTickWithEvents
        executor
        options
        events
        observation

runObservedDaemonTickWithEvents
  :: Monad m
  => ActionExecutor m
  -> DaemonOptions
  -> [WatcherEvent]
  -> DaemonObservation
  -> m (Either DaemonFailure DaemonObservedTickResult)
runObservedDaemonTickWithEvents executor options events observation =
  case replayEventLogFromEvents events of
    Left failure -> do
      logDaemonFailure executor "observed_replay_failed" "observed daemon replay failed" failure
      pure (Left failure)
    Right replay -> do
      logReplaySucceeded executor "observed_replay_succeeded" events replay
      Log.logWatcher
        executor.actionLogger
        ( Log.watcherLog
            Log.Info
            "observation_received"
            "daemon observation received"
            [ "observation" .= Text.pack (show observation)
            , "domain" .= Text.pack (show (someDomain replay.replayState))
            , "phase" .= Text.pack (show (somePhase replay.replayState))
            ]
        )
      case observeDaemonState replay.replayState observation of
        Left reason -> do
          Log.logWatcher
            executor.actionLogger
            ( Log.watcherLog
                Log.Warn
                "observation_rejected"
                "daemon observation rejected"
                [ "reason" .= reason
                , "observation" .= Text.pack (show observation)
                ]
            )
          pure (Left (DaemonObservationRejected reason))
        Right observed -> do
          case options.daemonExecutionMode of
            DryRunActions -> runObservedDaemonDryRun executor options replay observed
            ExecuteActions -> runObservedDaemonExecute executor options events replay observed

replayDaemonEventLog :: FilePath -> IO (Either DaemonFailure EventReplayResult)
replayDaemonEventLog path = do
  loaded <- loadEventLogFile path
  pure case loaded of
    Left errorMessage -> Left (DaemonEventLogDecodeFailed (Text.pack errorMessage))
    Right events -> replayEventLogFromEvents events

appendWatcherEvent :: RuntimeInterpreter m -> FilePath -> WatcherEvent -> m ()
appendWatcherEvent interpreter path event =
  interpreter.runtimeAppendJsonLine path (toJSON event)

formatDaemonFailure :: DaemonFailure -> Text
formatDaemonFailure = \case
  DaemonEventLogDecodeFailed message ->
    "event log decode failed: " <> message
  DaemonReplayFailed failure ->
    "event replay failed at event "
      <> Text.pack (show failure.eventIndex)
      <> " ("
      <> Text.pack (show failure.event)
      <> "): "
      <> failure.reason
  DaemonObservationRejected message ->
    "observation rejected: " <> message
  DaemonActionFailed action report ->
    "action failed before event commit: " <> Text.pack (show action) <> ": " <> commandText report
  DaemonActionResultInvalid action message ->
    "action returned invalid result before event commit: " <> Text.pack (show action) <> ": " <> message

replayEventLogFromEvents :: [WatcherEvent] -> Either DaemonFailure EventReplayResult
replayEventLogFromEvents events =
  case replayEventLog events of
    Left failure -> Left (DaemonReplayFailed failure)
    Right replay -> Right replay

data ObservedPolicyTick = ObservedPolicyTick
  { observedEvent :: WatcherEvent
  , observedState :: SomeWatcherState
  , observedEffects :: EffectPlan
  }

data PreparedObservedCommit = PreparedObservedCommit
  { preparedFinalReplay :: EventReplayResult
  , preparedEvents :: [WatcherEvent]
  , preparedCompatibilityWrites :: [CompatibilityWrite]
  , preparedCompiledEffects :: CompiledEffectPlan
  , preparedPostActions :: [PlannedAction]
  }

observeDaemonState :: SomeWatcherState -> DaemonObservation -> Either Text ObservedPolicyTick
observeDaemonState state = \case
  DaemonPrReviewObservation observation ->
    fromPrReviewTick <$> prReviewObserve state observation
  DaemonIssueImplementObservation observation ->
    fromIssueImplementTick <$> issueImplementObserve state observation
  DaemonIssuePlanningObservation observation ->
    fromIssuePlanningTick <$> issuePlanningObserve state observation

fromPrReviewTick :: PrReviewTick -> ObservedPolicyTick
fromPrReviewTick tick =
  ObservedPolicyTick tick.prReviewTickEvent tick.prReviewTickState tick.prReviewTickEffects

fromIssueImplementTick :: IssueImplementTick -> ObservedPolicyTick
fromIssueImplementTick tick =
  ObservedPolicyTick tick.issueImplementTickEvent tick.issueImplementTickState tick.issueImplementTickEffects

fromIssuePlanningTick :: IssuePlanningTick -> ObservedPolicyTick
fromIssuePlanningTick tick =
  ObservedPolicyTick tick.issuePlanningTickEvent tick.issuePlanningTickState tick.issuePlanningTickEffects

runObservedDaemonDryRun
  :: Monad m
  => ActionExecutor m
  -> DaemonOptions
  -> EventReplayResult
  -> ObservedPolicyTick
  -> m (Either DaemonFailure DaemonObservedTickResult)
runObservedDaemonDryRun executor options replay observed = do
  let compatibilityWrites = compatibilityStateWrites (runtimeStateDirPath options.daemonRuntimeConfig.effectRuntimeStateDir) observed.observedState
      compiledEffects = compileEffectPlan options.daemonRuntimeConfig observed.observedEffects
  actionReports <- executeCompiledEffectPlan executor DryRunActions compiledEffects
  pure
    ( Right
        DaemonObservedTickResult
          { daemonObservedReplayResult = replay
          , daemonObservedEvent = observed.observedEvent
          , daemonObservedState = observed.observedState
          , daemonObservedCompatibilityWrites = compatibilityWrites
          , daemonObservedCompiledEffects = compiledEffects
          , daemonObservedActionReports = actionReports
          }
    )

runObservedDaemonExecute
  :: Monad m
  => ActionExecutor m
  -> DaemonOptions
  -> [WatcherEvent]
  -> EventReplayResult
  -> ObservedPolicyTick
  -> m (Either DaemonFailure DaemonObservedTickResult)
runObservedDaemonExecute executor options events replay observed0 = do
  let observed = observed0
      compiledEffects = compileEffectPlan options.daemonRuntimeConfig observed.observedEffects
      (preCommitActions, postCommitActions) = partition actionRunsBeforeEventCommit compiledEffects.compiledActions
  preReportsResult <- executeCheckedActions executor preCommitActions
  case preReportsResult of
    Left failure -> pure (Left failure)
    Right preReports -> do
      case prepareObservedCommit options events observed compiledEffects postCommitActions preReports of
        Left failure -> pure (Left failure)
        Right prepared -> do
          mapM_
            ( \event -> do
                appendWatcherEvent executor.actionRuntime options.daemonEventLogPath event
                Log.logWatcher
                  executor.actionLogger
                  ( Log.watcherLog
                      Log.Info
                      "event_committed"
                      "watcher event committed"
                      [ "event" .= Text.pack (show event)
                      , "eventsPath" .= options.daemonEventLogPath
                      ]
                  )
            )
            prepared.preparedEvents
          mapM_
            ( \write -> do
                writeCompatibility executor.actionRuntime write
                Log.logWatcher
                  executor.actionLogger
                  ( Log.watcherLog
                      Log.Debug
                      "compatibility_written"
                      "compatibility state written"
                      ["path" .= compatibilityWritePath write]
                  )
            )
            prepared.preparedCompatibilityWrites
          postReportsResult <- executeCheckedActions executor prepared.preparedPostActions
          pure case postReportsResult of
            Left failure -> Left failure
            Right postReports ->
              Right
                DaemonObservedTickResult
                  { daemonObservedReplayResult = replay
                  , daemonObservedEvent = observed.observedEvent
                  , daemonObservedState = prepared.preparedFinalReplay.replayState
                  , daemonObservedCompatibilityWrites = prepared.preparedCompatibilityWrites
                  , daemonObservedCompiledEffects = prepared.preparedCompiledEffects
                  , daemonObservedActionReports = preReports <> postReports
                  }

prepareObservedCommit
  :: DaemonOptions
  -> [WatcherEvent]
  -> ObservedPolicyTick
  -> CompiledEffectPlan
  -> [PlannedAction]
  -> [ActionExecutionReport]
  -> Either DaemonFailure PreparedObservedCommit
prepareObservedCommit options priorEvents observed compiledEffects postCommitActions _preReports = do
  let committedEvents = [observed.observedEvent]
  finalReplay <- replayEventLogFromEvents (priorEvents <> committedEvents)
  let finalState = finalReplay.replayState
      compatibilityWrites = compatibilityStateWrites (runtimeStateDirPath options.daemonRuntimeConfig.effectRuntimeStateDir) finalState
  pure
    PreparedObservedCommit
      { preparedFinalReplay = finalReplay
      , preparedEvents = committedEvents
      , preparedCompatibilityWrites = compatibilityWrites
      , preparedCompiledEffects = compiledEffects
      , preparedPostActions = postCommitActions
      }

actionRunsBeforeEventCommit :: PlannedAction -> Bool
actionRunsBeforeEventCommit = \case
  PlannedCommand {} -> True
  PlannedAppServerRequest {} -> True
  PlannedWriteJson {} -> False
  PlannedWriteText {} -> True
  PlannedSleepUntilNextPoll -> False
  PlannedStopDaemon -> False

executeCheckedActions :: Monad m => ActionExecutor m -> [PlannedAction] -> m (Either DaemonFailure [ActionExecutionReport])
executeCheckedActions executor =
  go []
 where
  go reports [] = pure (Right (reverse reports))
  go reports (action : rest) = do
    report <- executePlannedAction executor ExecuteActions action
    case actionFailure report of
      Just failure -> pure (Left failure)
      Nothing -> go (report : reports) rest

actionFailure :: ActionExecutionReport -> Maybe DaemonFailure
actionFailure report =
  case report.actionExecutionResult of
    CommandActionResult commandReport
      | not commandReport.ok -> Just (DaemonActionFailed report.actionExecutionAction commandReport)
    _ -> Nothing

data PreMergeGateResult
  = PreMergeGatePassed
  | PreMergeGateRetry Text
  | PreMergeGateRecheck Text
  | PreMergeGateBlocked Text

runPreMergeGate :: Monad m => ActionExecutor m -> PrConfig -> CleanReviewEvidence -> m PreMergeGateResult
runPreMergeGate executor prConfig evidence = do
  remoteResult <- runGhPrView executor.actionRuntime prConfig.prRepo prConfig.prNumber
  case remoteResult of
    Left reason -> pure (PreMergeGateBlocked ("pre-merge PR read failed: " <> reason))
    Right remote
      | not (remotePullRequestIsOpen remote) ->
          pure (PreMergeGateBlocked ("pre-merge PR state is " <> renderRemotePullRequestState remote.remotePullRequestState <> ", expected OPEN"))
      | remote.remotePullRequestHeadRefOid /= Just evidence.cleanReviewCommit ->
          pure
            ( PreMergeGateRecheck
                ( "pre-merge PR head changed from reviewed commit "
                    <> unCommitSha evidence.cleanReviewCommit
                    <> " to "
                    <> maybe "unknown" unCommitSha remote.remotePullRequestHeadRefOid
                )
            )
      | Just result <- mergeStateGateResult remote.remotePullRequestMergeStateStatus ->
          pure result
      | otherwise -> do
          threadsResult <- runGhReviewThreads executor.actionRuntime prConfig
          case threadsResult of
            Left reason -> pure (PreMergeGateBlocked ("pre-merge review-thread read failed: " <> reason))
            Right threads
              | not (null threads.unresolvedReviewThreads) ->
                  pure (PreMergeGateRecheck "pre-merge found unresolved review threads")
              | otherwise -> do
                  checksResult <- runGhPrChecks executor.actionRuntime prConfig.prRepo prConfig.prNumber
                  pure case checksResult of
                    Left reason -> PreMergeGateBlocked ("pre-merge required checks could not be read: " <> reason)
                    Right checks
                      | all checkPassed checks -> PreMergeGatePassed
                      | any checkPending checks -> PreMergeGateRetry ("pre-merge required checks are still pending: " <> failedCheckNames checks)
                      | otherwise -> PreMergeGateBlocked ("pre-merge required checks are not successful: " <> failedCheckNames checks)

mergeStateGateResult :: Maybe Text -> Maybe PreMergeGateResult
mergeStateGateResult Nothing =
  Just (PreMergeGateRetry "pre-merge merge state could not be read")
mergeStateGateResult (Just status)
  | normalized `elem` ["CLEAN", "HAS_HOOKS"] = Nothing
  | normalized `elem` ["UNSTABLE", "UNKNOWN"] = Just (PreMergeGateRetry ("pre-merge merge state is " <> status))
  | otherwise = Just (PreMergeGateBlocked ("pre-merge merge state is " <> status))
 where
  normalized = Text.toUpper (Text.strip status)

checkPassed :: GhPullRequestCheck -> Bool
checkPassed check =
  normalizeCheckStatus check.ghPullRequestCheckState `elem` passStates
    || maybe False (`elem` passBuckets) (normalizeCheckStatus <$> check.ghPullRequestCheckBucket)
 where
  passStates = ["success", "successful", "skipped", "neutral", "passed"]
  passBuckets = ["pass", "passing", "skipping"]

checkPending :: GhPullRequestCheck -> Bool
checkPending check =
  normalizeCheckStatus check.ghPullRequestCheckState `elem` pendingStates
    || maybe False (`elem` pendingBuckets) (normalizeCheckStatus <$> check.ghPullRequestCheckBucket)
 where
  pendingStates = ["pending", "queued", "in_progress", "in progress", "waiting", "requested", ""]
  pendingBuckets = ["pending", "queued", "in_progress", "in progress", "waiting"]

failedCheckNames :: [GhPullRequestCheck] -> Text
failedCheckNames checks =
  Text.intercalate ", " [check.ghPullRequestCheckName | check <- checks, not (checkPassed check)]

normalizeCheckStatus :: Text -> Text
normalizeCheckStatus =
  Text.toLower . Text.strip

logReplaySucceeded :: ActionExecutor m -> Text -> [WatcherEvent] -> EventReplayResult -> m ()
logReplaySucceeded executor event events replay =
  Log.logWatcher
    executor.actionLogger
    ( Log.watcherLog
        Log.Debug
        event
        "watcher event log replay succeeded"
        [ "eventCount" .= length events
        , "domain" .= Text.pack (show (someDomain replay.replayState))
        , "phase" .= Text.pack (show (somePhase replay.replayState))
        ]
    )

logDaemonFailure :: ActionExecutor m -> Text -> Text -> DaemonFailure -> m ()
logDaemonFailure executor event message failure =
  Log.logWatcher
    executor.actionLogger
    ( Log.watcherLog
        Log.Error
        event
        message
        ["failure" .= formatDaemonFailure failure]
    )
