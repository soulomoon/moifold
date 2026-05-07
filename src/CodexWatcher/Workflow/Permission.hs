{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}

module CodexWatcher.Workflow.Permission
  ( PhaseActionValidationError (..)
  , WorkflowEffectPermissionCheck (..)
  , WorkflowPermissionPolicy (..)
  , WorkflowPermissionValidationError (..)
  , formatPhaseActionValidationError
  , formatWorkflowPermissionValidationError
  , moifoldPermissionPolicy
  , validateMoifoldEffectPlan
  , validateWorkflowEffectPlanCore
  , validateWorkflowEffectPlanWithPolicy
  , validateWorkflowEffectPlan
  , workflowEffectPermissionChecks
  , workflowEffectPermissionChecksWithPolicy
  , workflowSpecPermissionPolicy
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
  , WorkflowPermissionPolicy (..)
  , WorkflowPermissionValidationError (..)
  , formatWorkflowPermissionValidationError
  , validateWorkflowEffectPlanCore
  , validateWorkflowEffectPlanWithPolicy
  , workflowEffectPermissionChecks
  , workflowEffectPermissionChecksWithPolicy
  , workflowSpecPermissionPolicy
  )
import CodexWatcher.Workflow.Spec (WorkflowSpec (..))
import CodexWatcher.Workflow.Types (MoifoldSpec)

validateMoifoldEffectPlan :: SomeWatcherState -> EffectPlan -> Either PhaseActionValidationError ()
validateMoifoldEffectPlan =
  validatePhaseActionPlan

moifoldPermissionPolicy :: WorkflowPermissionPolicy MoifoldSpec
moifoldPermissionPolicy =
  workflowSpecPermissionPolicy @MoifoldSpec

validateWorkflowEffectPlan
  :: forall spec. WorkflowSpec spec
  => WorkflowState spec
  -> WorkflowEffectPlan spec
  -> Either (WorkflowError spec) ()
validateWorkflowEffectPlan =
  workflowValidateEffects @spec
