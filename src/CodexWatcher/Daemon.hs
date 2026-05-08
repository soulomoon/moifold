{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications #-}

module CodexWatcher.Daemon
  ( DaemonFailure (..)
  , DaemonObservation (..)
  , DaemonOptions (..)
  , DaemonObservedTransactionFailure (..)
  , DaemonObservedTickResult (..)
  , PreMergeGateResult (..)
  , DaemonTickResult (..)
  , ObservedPolicyTick (..)
  , appendWatcherEvent
  , daemonCoreTickResult
  , daemonObservedCoreTickResult
  , formatDaemonFailure
  , observeDaemonState
  , replayDaemonEventLog
  , runObservedDaemonTickFromFile
  , runObservedDaemonTickWithEvents
  , runDaemonTickFromFile
  , runDaemonTickWithEvents
  , prChecksGate
  , runPreMergeGate
  ) where

import CodexWatcher.Runtime.Compatibility
import CodexWatcher.Effects
import CodexWatcher.EventLog.File (loadEventLogFile)
import CodexWatcher.EventLog.Replay (replayEventLog)
import CodexWatcher.EventLog.Types
import CodexWatcher.Failure
import CodexWatcher.GhGit
import CodexWatcher.Logging qualified as Log
import CodexWatcher.Runtime.Command.Render (commandText)
import CodexWatcher.Runtime.Command.Types (CommandReport (..))
import CodexWatcher.Runtime.Interpreter (RuntimeInterpreter (..))
import CodexWatcher.Runtime.Paths (runtimeStateDirPath)
import CodexWatcher.Core.Ids (CommitSha (..))
import CodexWatcher.Core.State (SomeWatcherState (..), WatcherState (..), someDomain, somePhase)
import CodexWatcher.Domain.IssuePlanning.Watcher (IssuePlanningObservation (..))
import CodexWatcher.Domain.PrReview.Types (CleanReviewEvidence (..), PrConfig (..))
import CodexWatcher.Domain.PrReview.Watcher (PrReviewObservation (..))
import CodexWatcher.Workflow.Daemon.Core qualified as WorkflowDaemon
import CodexWatcher.Workflow.Execution
import CodexWatcher.Workflow.Audit qualified as WorkflowAudit
import CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog
import CodexWatcher.Workflow.EventLog.Commit.Core
  ( WorkflowEventCommitter (..)
  , appendEncodedWorkflowEvent
  )
import CodexWatcher.Workflow.Observation (DaemonObservation (..), ObservedPolicyTick (..), observeDaemonState)
import CodexWatcher.Workflow.Spec (PlannedTransition (..))
import CodexWatcher.Workflow.Transaction.Core
  ( WorkflowObservedTransactionHooks (..)
  , WorkflowObservedTransactionFailure (..)
  , WorkflowObservedTransactionResult (..)
  , WorkflowTransactionFailureStage (..)
  , runWorkflowPreparedDryRunTransaction
  , runWorkflowPreparedExecuteTransactionDetailed
  )
import CodexWatcher.Workflow.Types (MoifoldSpec, legacyObservedPlannedTransition)
import CodexWatcher.Workflow.Moifold.IssuePlanning.Indexed qualified as WorkflowIssuePlanningIndexed
import CodexWatcher.Workflow.Moifold.PrReview.Mergeability.Indexed qualified as WorkflowPrReviewMergeabilityIndexed
import Data.Aeson (toJSON)
import Data.Aeson ((.=))
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
  | DaemonObservedTransactionFailed DaemonObservedTransactionFailure
  deriving stock (Eq, Show, Generic)

data DaemonObservedTransactionFailure = DaemonObservedTransactionFailure
  { daemonObservedTransactionFailureStage :: WorkflowTransactionFailureStage
  , daemonObservedTransactionFailureReason :: DaemonFailure
  , daemonObservedTransactionFailurePlannedEvent :: Maybe WatcherEvent
  , daemonObservedTransactionFailureCommittedEvents :: [WatcherEvent]
  , daemonObservedTransactionFailureCompiledEffects :: Maybe WorkflowCompiledEffectPlan
  , daemonObservedTransactionFailurePreCommitReports :: [ActionExecutionReport]
  , daemonObservedTransactionFailurePostCommitReports :: [ActionExecutionReport]
  , daemonObservedTransactionFailureAudit :: Maybe (WorkflowAudit.WorkflowTickAudit MoifoldSpec DaemonFailure ActionExecutionReport)
  }
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
  , daemonObservedCommittedEvents :: [WatcherEvent]
  , daemonObservedState :: SomeWatcherState
  , daemonObservedCompatibilityWrites :: [CompatibilityWrite]
  , daemonObservedCompiledEffects :: CompiledEffectPlan
  , daemonObservedActionReports :: [ActionExecutionReport]
  , daemonObservedAudit :: WorkflowEventLog.WorkflowTickAudit MoifoldSpec ActionExecutionReport
  }
  deriving stock (Show, Generic)

data PreparedDaemonObservation = PreparedDaemonObservation
  { preparedDaemonObservationPlanned :: PlannedTransition MoifoldSpec
  , preparedDaemonObservationFinalState :: SomeWatcherState
  }

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
      let workflowEffects = compileWorkflowEffectPlanWithMetadata runtimeConfig nextEffects
          compiledEffects = workflowCompiledEffectPlanLegacy workflowEffects
      actionReportsResult <-
        case executionMode of
          DryRunActions -> Right <$> executeWorkflowCompiledEffectPlan executor DryRunActions workflowEffects
          ExecuteActions -> do
            checked <- executeWorkflowCheckedActions executor workflowEffects.workflowCompiledActions
            pure (either (Left . daemonFailureFromWorkflowActionFailure) Right checked)
      case actionReportsResult of
        Left failure -> do
          logDaemonFailure executor "daemon_tick_failed" "daemon tick failed" failure
          pure (Left failure)
        Right actionReports -> do
          let coreTick = WorkflowDaemon.workflowDaemonTickResult @MoifoldSpec replay compiledEffects actionReports
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
                  { daemonReplayResult = coreTick.workflowDaemonReplayResult
                  , daemonCompiledEffects = coreTick.workflowDaemonCompiledEffects
                  , daemonActionReports = coreTick.workflowDaemonActionReports
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
      case prepareDaemonObservation replay.replayState observation of
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
        Right prepared -> do
          case options.daemonExecutionMode of
            DryRunActions -> runObservedDaemonDryRun executor options events replay observation prepared
            ExecuteActions -> runObservedDaemonExecute executor options events replay observation prepared

replayDaemonEventLog :: FilePath -> IO (Either DaemonFailure EventReplayResult)
replayDaemonEventLog path = do
  loaded <- loadEventLogFile path
  pure case loaded of
    Left errorMessage -> Left (DaemonEventLogDecodeFailed (Text.pack errorMessage))
    Right events -> replayEventLogFromEvents events

appendWatcherEvent :: RuntimeInterpreter m -> FilePath -> WatcherEvent -> m ()
appendWatcherEvent interpreter path event =
  appendEncodedWorkflowEvent toJSON (interpreter.runtimeAppendJsonLine path) event

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
  DaemonObservedTransactionFailed failure ->
    formatDaemonObservedTransactionFailure failure

formatDaemonObservedTransactionFailure :: DaemonObservedTransactionFailure -> Text
formatDaemonObservedTransactionFailure failure =
  "observed transaction failed during "
    <> Text.pack (show failure.daemonObservedTransactionFailureStage)
    <> ": "
    <> formatDaemonFailure failure.daemonObservedTransactionFailureReason
    <> "; committed events: "
    <> Text.pack (show (length failure.daemonObservedTransactionFailureCommittedEvents))
    <> maybe "" formatAudit failure.daemonObservedTransactionFailureAudit
 where
  formatAudit audit =
    "; audit prior="
      <> WorkflowAudit.workflowAuditPriorStateLabel audit
      <> ", committed="
      <> maybe "<none>" id (WorkflowAudit.workflowAuditCommittedEventLabel audit)
      <> ", final="
      <> maybe "<none>" id (WorkflowAudit.workflowAuditFinalStateLabel audit)
      <> ", recommendation="
      <> Text.pack (show (WorkflowAudit.workflowAuditNextDaemonRecommendation audit))

replayEventLogFromEvents :: [WatcherEvent] -> Either DaemonFailure EventReplayResult
replayEventLogFromEvents events =
  case replayEventLog events of
    Left failure -> Left (DaemonReplayFailed failure)
    Right replay -> Right replay

prepareDaemonObservation
  :: SomeWatcherState
  -> DaemonObservation
  -> Either Text PreparedDaemonObservation
prepareDaemonObservation state observation =
  case (state, observation) of
    (SomeWatcherState PlanningReady {}, DaemonIssuePlanningObservation (ObservedPlanningTurnStarted threadId turnId)) -> do
      projected <-
        WorkflowIssuePlanningIndexed.projectIssuePlanningTurnStartedObservation
          state
          threadId
          turnId
      pure
        PreparedDaemonObservation
          { preparedDaemonObservationPlanned =
              projected.issuePlanningIndexedProjectionPlanned
          , preparedDaemonObservationFinalState =
              projected.issuePlanningIndexedProjectionFinalState
          }
    (SomeWatcherState PrWaitingForMergeability {}, DaemonPrReviewObservation (ObservedMergeabilityClean commit)) -> do
      projected <-
        WorkflowPrReviewMergeabilityIndexed.projectPrReviewMergeabilityCleanObservation
          state
          commit
      pure
        PreparedDaemonObservation
          { preparedDaemonObservationPlanned =
              projected.prReviewMergeabilityIndexedProjectionPlanned
          , preparedDaemonObservationFinalState =
              projected.prReviewMergeabilityIndexedProjectionFinalState
          }
    _ -> do
      observed <- observeDaemonState state observation
      pure
        PreparedDaemonObservation
          { preparedDaemonObservationPlanned =
              legacyObservedPlannedTransition observed
          , preparedDaemonObservationFinalState = observed.observedState
          }

runObservedDaemonDryRun
  :: Monad m
  => ActionExecutor m
  -> DaemonOptions
  -> [WatcherEvent]
  -> EventReplayResult
  -> DaemonObservation
  -> PreparedDaemonObservation
  -> m (Either DaemonFailure DaemonObservedTickResult)
runObservedDaemonDryRun executor options _events replay observation prepared =
  pure $
    observedTransactionResultToDaemon options
      <$> runWorkflowPreparedDryRunTransaction @MoifoldSpec
        (moifoldObservedTransactionHooks executor options)
        replay
        observation
        prepared.preparedDaemonObservationPlanned
        prepared.preparedDaemonObservationFinalState

runObservedDaemonExecute
  :: Monad m
  => ActionExecutor m
  -> DaemonOptions
  -> [WatcherEvent]
  -> EventReplayResult
  -> DaemonObservation
  -> PreparedDaemonObservation
  -> m (Either DaemonFailure DaemonObservedTickResult)
runObservedDaemonExecute executor options events replay observation prepared = do
  result <-
    runWorkflowPreparedExecuteTransactionDetailed @MoifoldSpec
      (moifoldObservedTransactionHooks executor options)
      events
      replay
      observation
      prepared.preparedDaemonObservationPlanned
  pure case result of
    Left failure -> Left (daemonFailureFromObservedTransactionFailure failure)
    Right success -> Right (observedDetailedTransactionResultToDaemon options observation success)

moifoldObservedTransactionHooks
  :: Monad m
  => ActionExecutor m
  -> DaemonOptions
  -> WorkflowObservedTransactionHooks m MoifoldSpec WorkflowCompiledEffectPlan WorkflowPlannedAction ActionExecutionReport DaemonFailure
moifoldObservedTransactionHooks executor options =
  WorkflowObservedTransactionHooks
    { workflowTransactionMapError = DaemonObservationRejected
    , workflowTransactionCompileEffects = compileWorkflowEffectPlanWithMetadata options.daemonRuntimeConfig
    , workflowTransactionPartitionActions = partitionWorkflowActions
    , workflowTransactionDryRunActions = fmap dryRunWorkflowAction
    , workflowTransactionExecuteActions = executeMoifoldWorkflowActions executor
    , workflowTransactionCommitEvent = commitMoifoldObservedEvent executor options
    , workflowTransactionAfterCommit = writeMoifoldCompatibilityState executor options
    , workflowTransactionFailureIsRetryable = const False
    }

executeMoifoldWorkflowActions :: Monad m => ActionExecutor m -> [WorkflowPlannedAction] -> m (Either DaemonFailure [ActionExecutionReport])
executeMoifoldWorkflowActions executor actions = do
  result <- executeWorkflowCheckedActions executor actions
  pure case result of
    Left failure -> Left (daemonFailureFromWorkflowActionFailure failure)
    Right reports -> Right reports

commitMoifoldObservedEvent :: Monad m => ActionExecutor m -> DaemonOptions -> WorkflowEventCommitter m WatcherEvent DaemonFailure
commitMoifoldObservedEvent executor options =
  WorkflowEventCommitter \event -> do
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
    pure (Right ())

writeMoifoldCompatibilityState :: Monad m => ActionExecutor m -> DaemonOptions -> SomeWatcherState -> m (Either DaemonFailure ())
writeMoifoldCompatibilityState executor options finalState = do
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
    (observedCompatibilityWrites options finalState)
  pure (Right ())

observedTransactionResultToDaemon
  :: DaemonOptions
  -> WorkflowObservedTransactionResult MoifoldSpec WorkflowCompiledEffectPlan ActionExecutionReport FailureClassification
  -> DaemonObservedTickResult
observedTransactionResultToDaemon options result =
  observedTransactionResultToDaemonWithAudit options result result.workflowTransactionAudit

observedDetailedTransactionResultToDaemon
  :: DaemonOptions
  -> DaemonObservation
  -> WorkflowObservedTransactionResult MoifoldSpec WorkflowCompiledEffectPlan ActionExecutionReport DaemonFailure
  -> DaemonObservedTickResult
observedDetailedTransactionResultToDaemon options observation result =
  observedTransactionResultToDaemonWithAudit
    options
    result
    ( WorkflowEventLog.workflowSuccessAudit @MoifoldSpec
        result.workflowTransactionPriorReplay.replayState
        observation
        result.workflowTransactionPlanned
        result.workflowTransactionFinalState
        result.workflowTransactionPreCommitReports
        result.workflowTransactionPostCommitReports
    )

observedTransactionResultToDaemonWithAudit
  :: DaemonOptions
  -> WorkflowObservedTransactionResult MoifoldSpec WorkflowCompiledEffectPlan ActionExecutionReport failure
  -> WorkflowEventLog.WorkflowTickAudit MoifoldSpec ActionExecutionReport
  -> DaemonObservedTickResult
observedTransactionResultToDaemonWithAudit options result audit =
  let coreTick = WorkflowDaemon.workflowObservedDaemonTickResult result
   in
  DaemonObservedTickResult
    { daemonObservedReplayResult = coreTick.workflowObservedDaemonPriorReplay
    , daemonObservedEvent = coreTick.workflowObservedDaemonEvent
    , daemonObservedCommittedEvents = coreTick.workflowObservedDaemonCommittedEvents
    , daemonObservedState = coreTick.workflowObservedDaemonState
    , daemonObservedCompatibilityWrites = observedCompatibilityWrites options coreTick.workflowObservedDaemonState
    , daemonObservedCompiledEffects = workflowCompiledEffectPlanLegacy coreTick.workflowObservedDaemonCompiledEffects
    , daemonObservedActionReports = coreTick.workflowObservedDaemonActionReports
    , daemonObservedAudit = audit
    }

daemonCoreTickResult :: DaemonTickResult -> WorkflowDaemon.WorkflowDaemonTickResult MoifoldSpec CompiledEffectPlan ActionExecutionReport
daemonCoreTickResult tick =
  WorkflowDaemon.WorkflowDaemonTickResult
    { WorkflowDaemon.workflowDaemonReplayResult = tick.daemonReplayResult
    , WorkflowDaemon.workflowDaemonCompiledEffects = tick.daemonCompiledEffects
    , WorkflowDaemon.workflowDaemonActionReports = tick.daemonActionReports
    }

daemonObservedCoreTickResult
  :: DaemonObservedTickResult
  -> WorkflowDaemon.WorkflowObservedDaemonTickResult MoifoldSpec CompiledEffectPlan ActionExecutionReport FailureClassification
daemonObservedCoreTickResult tick =
  WorkflowDaemon.WorkflowObservedDaemonTickResult
    { WorkflowDaemon.workflowObservedDaemonPriorReplay = tick.daemonObservedReplayResult
    , WorkflowDaemon.workflowObservedDaemonEvent = tick.daemonObservedEvent
    , WorkflowDaemon.workflowObservedDaemonState = tick.daemonObservedState
    , WorkflowDaemon.workflowObservedDaemonCommittedEvents = tick.daemonObservedCommittedEvents
    , WorkflowDaemon.workflowObservedDaemonCompiledEffects = tick.daemonObservedCompiledEffects
    , WorkflowDaemon.workflowObservedDaemonPreCommitReports =
        WorkflowEventLog.workflowAuditPreCommitReports tick.daemonObservedAudit
    , WorkflowDaemon.workflowObservedDaemonPostCommitReports =
        WorkflowEventLog.workflowAuditPostCommitReports tick.daemonObservedAudit
    , WorkflowDaemon.workflowObservedDaemonActionReports = tick.daemonObservedActionReports
    , WorkflowDaemon.workflowObservedDaemonAudit = tick.daemonObservedAudit
    }

dryRunWorkflowAction :: WorkflowPlannedAction -> ActionExecutionReport
dryRunWorkflowAction action =
  ActionExecutionReport
    { actionExecutionMode = DryRunActions
    , actionExecutionAction = action.workflowPlannedAction
    , actionExecutionResult = DryRunActionResult
    , actionExecutionOutcome = ActionSucceeded
    }

observedCompatibilityWrites :: DaemonOptions -> SomeWatcherState -> [CompatibilityWrite]
observedCompatibilityWrites options =
  compatibilityStateWrites (runtimeStateDirPath options.daemonRuntimeConfig.effectRuntimeStateDir)

daemonFailureFromWorkflowActionFailure :: WorkflowActionFailure -> DaemonFailure
daemonFailureFromWorkflowActionFailure failure =
  case failure.workflowFailureCommandReport of
    Just commandReport ->
      DaemonActionFailed failure.workflowFailedAction.workflowPlannedAction commandReport
    Nothing ->
      DaemonActionResultInvalid
        failure.workflowFailedAction.workflowPlannedAction
        failure.workflowFailureClassification.failureReason

daemonFailureFromObservedTransactionFailure
  :: WorkflowObservedTransactionFailure MoifoldSpec WorkflowCompiledEffectPlan ActionExecutionReport DaemonFailure
  -> DaemonFailure
daemonFailureFromObservedTransactionFailure failure =
  DaemonObservedTransactionFailed
    DaemonObservedTransactionFailure
      { daemonObservedTransactionFailureStage = failure.workflowTransactionFailureStage
      , daemonObservedTransactionFailureReason = failure.workflowTransactionFailureReason
      , daemonObservedTransactionFailurePlannedEvent = plannedEvent <$> failure.workflowTransactionFailurePlanned
      , daemonObservedTransactionFailureCommittedEvents = failure.workflowTransactionFailureCommittedEvents
      , daemonObservedTransactionFailureCompiledEffects = failure.workflowTransactionFailureCompiledEffects
      , daemonObservedTransactionFailurePreCommitReports = failure.workflowTransactionFailurePreCommitReports
      , daemonObservedTransactionFailurePostCommitReports = failure.workflowTransactionFailurePostCommitReports
      , daemonObservedTransactionFailureAudit = failure.workflowTransactionFailureAudit
      }

data PreMergeGateResult
  = PreMergeGatePassed
  | PreMergeGateRetry Text
  | PreMergeGateRecheck Text
  | PreMergeGateFixRequired Text
  | PreMergeGateBlocked Text

runPreMergeGate :: Monad m => ActionExecutor m -> PrConfig -> CleanReviewEvidence -> m PreMergeGateResult
runPreMergeGate executor prConfig evidence = do
  remoteResult <- runGhPrView executor.actionRuntime prConfig.prRepo prConfig.prNumber
  case remoteResult of
    Left reason -> pure (preMergeExternalFailure "pre-merge PR read failed" reason)
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
          case result of
            PreMergeGateRetry reason
              | mergeStateRetryCanBeOverriddenByChecks remote.remotePullRequestMergeStateStatus ->
                  mergeStateRetryWithCheckOverride executor prConfig reason
            _ ->
              pure result
      | otherwise -> do
          threadsResult <- runGhReviewThreads executor.actionRuntime prConfig
          case threadsResult of
            Left reason -> pure (preMergeExternalFailure "pre-merge review-thread read failed" reason)
            Right threads
              | not (null threads.unresolvedReviewThreads) ->
                  pure (PreMergeGateRecheck "pre-merge found unresolved review threads")
              | otherwise -> prChecksGate executor prConfig

mergeStateRetryWithCheckOverride :: Monad m => ActionExecutor m -> PrConfig -> Text -> m PreMergeGateResult
mergeStateRetryWithCheckOverride executor prConfig mergeStateRetryReason = do
  checksGate <- prChecksGate executor prConfig
  pure case checksGate of
    PreMergeGatePassed -> PreMergeGateRetry mergeStateRetryReason
    PreMergeGateRetry reason -> PreMergeGateRetry reason
    PreMergeGateFixRequired reason -> PreMergeGateFixRequired reason
    PreMergeGateBlocked reason -> PreMergeGateBlocked reason
    PreMergeGateRecheck reason -> PreMergeGateRecheck reason

prChecksGate :: Monad m => ActionExecutor m -> PrConfig -> m PreMergeGateResult
prChecksGate executor prConfig = do
  checksResult <- runGhPrChecks executor.actionRuntime prConfig.prRepo prConfig.prNumber
  pure case checksResult of
    Left reason -> preMergeExternalFailure "pre-merge PR checks could not be read" reason
    Right checks
      | all checkPassed checks -> PreMergeGatePassed
      | any checkPending checks -> PreMergeGateRetry ("pre-merge PR checks are still pending: " <> failedCheckNames checks)
      | otherwise -> PreMergeGateFixRequired ("pre-merge PR checks are not successful: " <> failedCheckNames checks)

mergeStateRetryCanBeOverriddenByChecks :: Maybe Text -> Bool
mergeStateRetryCanBeOverriddenByChecks status =
  case classifyRemotePullRequestMergeState status of
    RemotePullRequestMergeStateTransient _ -> True
    _ -> False

preMergeExternalFailure :: Text -> Text -> PreMergeGateResult
preMergeExternalFailure prefix reason =
  let classification = classifyExternalFailureText reason
      message = prefix <> ": " <> reason
   in if failureIsRetryable classification
        then PreMergeGateRetry message
        else PreMergeGateBlocked message

mergeStateGateResult :: Maybe Text -> Maybe PreMergeGateResult
mergeStateGateResult status =
  case classifyRemotePullRequestMergeState status of
    RemotePullRequestMergeStateUnavailable ->
      Just (PreMergeGateRetry "pre-merge merge state could not be read")
    RemotePullRequestMergeStateClean _ ->
      Nothing
    RemotePullRequestMergeStateTransient rawStatus ->
      Just (PreMergeGateRetry ("pre-merge merge state is " <> rawStatus))
    RemotePullRequestMergeStateFixRequired rawStatus ->
      Just (PreMergeGateFixRequired (remotePullRequestMergeStateFixMessage "pre-merge merge state" rawStatus))
    RemotePullRequestMergeStateBlocked rawStatus ->
      Just (PreMergeGateBlocked ("pre-merge merge state is " <> rawStatus))

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
