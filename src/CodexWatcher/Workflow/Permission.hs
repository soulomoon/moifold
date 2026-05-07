{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}

module CodexWatcher.Workflow.Permission
  ( PhaseActionValidationError (..)
  , WorkflowEffectPermissionCheck (..)
  , WorkflowPermissionValidationError (..)
  , formatPhaseActionValidationError
  , formatWorkflowPermissionValidationError
  , validateMoifoldEffectPlan
  , validateWorkflowEffectPlanCore
  , validateWorkflowEffectPlan
  , workflowEffectPermissionChecks
  ) where

import CodexWatcher.Effects (EffectPlan)
import CodexWatcher.Core.State (SomeWatcherState)
import CodexWatcher.StateMachine
  ( PhaseActionValidationError (..)
  , formatPhaseActionValidationError
  , validatePhaseActionPlan
  )
import CodexWatcher.Workflow.Permission.Core
  ( WorkflowEffectPermissionCheck (..)
  , WorkflowPermissionValidationError (..)
  , formatWorkflowPermissionValidationError
  , validateWorkflowEffectPlanCore
  , workflowEffectPermissionChecks
  )
import CodexWatcher.Workflow.Spec (WorkflowSpec (..))

validateMoifoldEffectPlan :: SomeWatcherState -> EffectPlan -> Either PhaseActionValidationError ()
validateMoifoldEffectPlan =
  validatePhaseActionPlan

validateWorkflowEffectPlan
  :: forall spec. WorkflowSpec spec
  => WorkflowState spec
  -> WorkflowEffectPlan spec
  -> Either (WorkflowError spec) ()
validateWorkflowEffectPlan =
  workflowValidateEffects @spec
