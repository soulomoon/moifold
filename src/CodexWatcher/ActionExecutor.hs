{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE OverloadedRecordDot #-}

module CodexWatcher.ActionExecutor
  ( ActionExecutionMode (..)
  , ActionExecutionReport (..)
  , ActionExecutionResult (..)
  , ActionExecutor (..)
  , AppServerInterpreter (..)
  , dryRunCompiledEffectPlan
  , executeCompiledEffectPlan
  , executePlannedAction
  , ioActionExecutor
  ) where

import CodexWatcher.AppServerProtocol
import CodexWatcher.EffectInterpreter
import CodexWatcher.Runtime
import Data.Aeson (Value)
import GHC.Generics (Generic)

data ActionExecutionMode
  = ExecuteActions
  | DryRunActions
  deriving stock (Eq, Show, Generic)

data AppServerInterpreter m = AppServerInterpreter
  { appServerSendRequest :: AppServerRequest -> m Value
  }

data ActionExecutor m = ActionExecutor
  { actionRuntime :: RuntimeInterpreter m
  , actionAppServer :: AppServerInterpreter m
  , actionSleepUntilNextPoll :: m ()
  , actionStopDaemon :: m ()
  }

data ActionExecutionResult
  = CommandActionResult CommandReport
  | AppServerActionResult Value
  | WriteJsonActionResult FilePath
  | SleepActionResult
  | StopDaemonActionResult
  | DryRunActionResult
  deriving stock (Eq, Show, Generic)

data ActionExecutionReport = ActionExecutionReport
  { actionExecutionMode :: ActionExecutionMode
  , actionExecutionAction :: PlannedAction
  , actionExecutionResult :: ActionExecutionResult
  }
  deriving stock (Eq, Show, Generic)

ioActionExecutor :: AppServerInterpreter IO -> IO () -> IO () -> ActionExecutor IO
ioActionExecutor appServerInterpreter sleepUntilNextPoll stopDaemon =
  ActionExecutor
    { actionRuntime = ioRuntimeInterpreter
    , actionAppServer = appServerInterpreter
    , actionSleepUntilNextPoll = sleepUntilNextPoll
    , actionStopDaemon = stopDaemon
    }

dryRunCompiledEffectPlan :: CompiledEffectPlan -> [ActionExecutionReport]
dryRunCompiledEffectPlan plan =
  fmap dryRunAction plan.compiledActions

executeCompiledEffectPlan :: Monad m => ActionExecutor m -> ActionExecutionMode -> CompiledEffectPlan -> m [ActionExecutionReport]
executeCompiledEffectPlan executor mode plan =
  traverse (executePlannedAction executor mode) plan.compiledActions

executePlannedAction :: Monad m => ActionExecutor m -> ActionExecutionMode -> PlannedAction -> m ActionExecutionReport
executePlannedAction _ DryRunActions action =
  pure (dryRunAction action)
executePlannedAction executor ExecuteActions action =
  case action of
    PlannedCommand command -> do
      report <- executor.actionRuntime.runtimeRunCommand command
      pure (executed action (CommandActionResult report))
    PlannedAppServerRequest request -> do
      response <- executor.actionAppServer.appServerSendRequest request
      pure (executed action (AppServerActionResult response))
    PlannedWriteJson path value -> do
      executor.actionRuntime.runtimeWriteJsonValue path value
      pure (executed action (WriteJsonActionResult path))
    PlannedSleepUntilNextPoll -> do
      executor.actionSleepUntilNextPoll
      pure (executed action SleepActionResult)
    PlannedStopDaemon -> do
      executor.actionStopDaemon
      pure (executed action StopDaemonActionResult)

dryRunAction :: PlannedAction -> ActionExecutionReport
dryRunAction action =
  ActionExecutionReport
    { actionExecutionMode = DryRunActions
    , actionExecutionAction = action
    , actionExecutionResult = DryRunActionResult
    }

executed :: PlannedAction -> ActionExecutionResult -> ActionExecutionReport
executed action result =
  ActionExecutionReport
    { actionExecutionMode = ExecuteActions
    , actionExecutionAction = action
    , actionExecutionResult = result
    }
