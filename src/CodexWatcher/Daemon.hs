{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Daemon
  ( DaemonFailure (..)
  , DaemonOptions (..)
  , DaemonTickResult (..)
  , appendWatcherEvent
  , formatDaemonFailure
  , replayDaemonEventLog
  , runDaemonTickFromFile
  , runDaemonTickWithEvents
  ) where

import CodexWatcher.ActionExecutor
import CodexWatcher.EffectInterpreter
import CodexWatcher.Effects
import CodexWatcher.EventLog
import CodexWatcher.Runtime
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
  deriving stock (Eq, Show, Generic)

data DaemonTickResult = DaemonTickResult
  { daemonReplayResult :: EventReplayResult
  , daemonCompiledEffects :: CompiledEffectPlan
  , daemonActionReports :: [ActionExecutionReport]
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

replayEventLogFromEvents :: [WatcherEvent] -> Either DaemonFailure EventReplayResult
replayEventLogFromEvents events =
  case replayEventLog events of
    Left failure -> Left (DaemonReplayFailed failure)
    Right replay -> Right replay
