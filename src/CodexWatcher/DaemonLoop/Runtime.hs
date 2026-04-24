{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.DaemonLoop.Runtime
  ( clearStaleActiveTurnMarkerWhenInactive
  , domainLoopOps
  , idle
  , observeWithExecutor
  , terminalStop
  ) where

import CodexWatcher.ActionExecutor
import CodexWatcher.CompatibilityState
import CodexWatcher.Daemon
import CodexWatcher.DaemonLoop.ActiveTurn qualified as ActiveTurn
import CodexWatcher.DaemonLoop.TurnStart qualified as TurnStart
import CodexWatcher.DaemonLoop.Types
import CodexWatcher.EffectInterpreter
import CodexWatcher.Effects
import CodexWatcher.EventLog.Types
import CodexWatcher.Logging qualified as Log
import CodexWatcher.Runtime.Interpreter (RuntimeInterpreter (..))
import CodexWatcher.Types
import Data.Aeson ((.=))
import Data.Text (Text)
import Data.Text qualified as Text

domainLoopOps :: Monad m => DomainLoopOps m
domainLoopOps =
  DomainLoopOps
    { loopPrestartAndObserve = TurnStart.prestartAndObserve observeWithExecutor
    , loopObserveWithExecutor = observeWithExecutor
    , loopIdle = idle
    , loopReadActiveTurn = ActiveTurn.readActiveTurn
    , loopHandleMissingActiveTurn = ActiveTurn.handleMissingActiveTurn idle observeWithExecutor
    , loopClearActiveTurnMarker = ActiveTurn.clearStaleActiveTurnMarker
    }

clearStaleActiveTurnMarkerWhenInactive :: Monad m => ActionExecutor m -> DaemonLoopConfig -> SomeWatcherState -> m ()
clearStaleActiveTurnMarkerWhenInactive =
  ActiveTurn.clearStaleActiveTurnMarkerWhenInactive

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
      mapM_
        writeIdleCompatibility
        (compatibilityStateWrites (runtimeStateDirPath config.loopDaemonOptions.daemonRuntimeConfig.effectRuntimeStateDir) replay.replayState)
  let sleepPlan = compileEffectPlan config.loopDaemonOptions.daemonRuntimeConfig [SomeEffect SleepUntilNextPoll]
  reports <- executeCompiledEffectPlan executor config.loopDaemonOptions.daemonExecutionMode sleepPlan
  pure (Right (idleTickResult replay reason reports))
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
      mapM_
        writeTerminalCompatibility
        (compatibilityStateWrites (runtimeStateDirPath config.loopDaemonOptions.daemonRuntimeConfig.effectRuntimeStateDir) replay.replayState)
  let stopPlan = compileEffectPlan config.loopDaemonOptions.daemonRuntimeConfig [SomeEffect StopDaemon]
  reports <- executeCompiledEffectPlan executor config.loopDaemonOptions.daemonExecutionMode stopPlan
  pure (Right (idleTickResult replay reason reports))
 where
  writeTerminalCompatibility write =
    runtimeWriteJsonValue (actionRuntime executor) (compatibilityWritePath write) (compatibilityWriteValue write)
