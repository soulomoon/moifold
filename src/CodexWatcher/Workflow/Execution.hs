module CodexWatcher.Workflow.Execution
  ( ActionExecutionMode (..)
  , ActionExecutionReport (..)
  , ActionExecutionResult (..)
  , ActionExecutor (..)
  , ActionOutcome (..)
  , AppServerInterpreter (..)
  , CompiledEffectPlan (..)
  , EffectRuntimeConfig (..)
  , PlannedAction (..)
  , TurnRuntimeConfig (..)
  , compileWorkflowEffect
  , compileWorkflowEffectPlan
  , dryRunWorkflowEffectPlan
  , executeWorkflowEffectPlan
  ) where

import CodexWatcher.ActionExecutor
  ( ActionExecutionMode (..)
  , ActionExecutionReport (..)
  , ActionExecutionResult (..)
  , ActionExecutor (..)
  , ActionOutcome (..)
  , AppServerInterpreter (..)
  , dryRunCompiledEffectPlan
  , executeCompiledEffectPlan
  )
import CodexWatcher.EffectInterpreter
  ( CompiledEffectPlan (..)
  , EffectRuntimeConfig (..)
  , PlannedAction (..)
  , TurnRuntimeConfig (..)
  , compileEffect
  , compileEffectPlan
  )
import CodexWatcher.Effects (EffectPlan, SomeEffect)
import CodexWatcher.Core.Ids (RequestId)

compileWorkflowEffectPlan :: EffectRuntimeConfig -> EffectPlan -> CompiledEffectPlan
compileWorkflowEffectPlan =
  compileEffectPlan

compileWorkflowEffect :: EffectRuntimeConfig -> RequestId -> SomeEffect -> ([PlannedAction], RequestId)
compileWorkflowEffect =
  compileEffect

dryRunWorkflowEffectPlan :: EffectRuntimeConfig -> EffectPlan -> [ActionExecutionReport]
dryRunWorkflowEffectPlan config =
  dryRunCompiledEffectPlan . compileWorkflowEffectPlan config

executeWorkflowEffectPlan
  :: Monad m
  => ActionExecutor m
  -> ActionExecutionMode
  -> EffectRuntimeConfig
  -> EffectPlan
  -> m [ActionExecutionReport]
executeWorkflowEffectPlan executor mode config =
  executeCompiledEffectPlan executor mode . compileWorkflowEffectPlan config
