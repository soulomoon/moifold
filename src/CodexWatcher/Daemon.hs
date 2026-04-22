{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Daemon
  ( DaemonFailure (..)
  , DaemonObservation (..)
  , DaemonOptions (..)
  , DaemonObservedTickResult (..)
  , DaemonTickResult (..)
  , appendWatcherEvent
  , formatDaemonFailure
  , replayDaemonEventLog
  , runObservedDaemonTickFromFile
  , runObservedDaemonTickWithEvents
  , runDaemonTickFromFile
  , runDaemonTickWithEvents
  ) where

import CodexWatcher.ActionExecutor
import CodexWatcher.CompatibilityState
import CodexWatcher.EffectInterpreter
import CodexWatcher.Effects
import CodexWatcher.EventLog
import CodexWatcher.IssueImplementWatcher
import CodexWatcher.IssuePlanningWatcher
import CodexWatcher.PrReviewWatcher
import CodexWatcher.Runtime
import CodexWatcher.Types (SomeWatcherState)
import Data.Aeson (toJSON)
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
    Left failure -> pure (Left failure)
    Right replay -> do
      let compiledEffects = compileEffectPlan runtimeConfig nextEffects
      actionReports <- executeCompiledEffectPlan executor executionMode compiledEffects
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
    Left failure -> pure (Left failure)
    Right replay ->
      case observeDaemonState replay.replayState observation of
        Left reason -> pure (Left (DaemonObservationRejected reason))
        Right observed -> do
          let compatibilityWrites = compatibilityStateWrites options.daemonRuntimeConfig.effectRuntimeStateDir observed.observedState
              compiledEffects = compileEffectPlan options.daemonRuntimeConfig observed.observedEffects
          case options.daemonExecutionMode of
            DryRunActions -> pure ()
            ExecuteActions -> do
              appendWatcherEvent executor.actionRuntime options.daemonEventLogPath observed.observedEvent
              mapM_ (writeCompatibility executor.actionRuntime) compatibilityWrites
          actionReports <- executeCompiledEffectPlan executor options.daemonExecutionMode compiledEffects
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

writeCompatibility :: RuntimeInterpreter m -> CompatibilityWrite -> m ()
writeCompatibility interpreter write =
  interpreter.runtimeWriteJsonValue write.compatibilityWritePath write.compatibilityWriteValue
