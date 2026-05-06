{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}

module CodexWatcher.Workflow.Permission
  ( PhaseActionValidationError (..)
  , formatPhaseActionValidationError
  , validateMoifoldEffectPlan
  , validateWorkflowEffectPlan
  ) where

import CodexWatcher.Effects (EffectPlan)
import CodexWatcher.Core.State (SomeWatcherState)
import CodexWatcher.StateMachine
  ( PhaseActionValidationError (..)
  , formatPhaseActionValidationError
  , validatePhaseActionPlan
  )
import CodexWatcher.Workflow.Types (WorkflowSpec (..))

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
