{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}

-- | Core workflow spec contract for the pure state, event, observation, and
-- effect-planning boundary. Concrete workflows provide their own states,
-- events, effect plans, replay, permissions, and interpreters.
module CodexWatcher.Workflow.Spec
  ( PlannedTransition (..)
  , WorkflowSpec (..)
  , workflowPlanObservation
  ) where

import Data.Text (Text)

data PlannedTransition spec = PlannedTransition
  { plannedEvent :: WorkflowEvent spec
  , plannedPreCommitEffects :: WorkflowEffectPlan spec
  , plannedPostCommitEffects :: WorkflowEffectPlan spec
  }

class WorkflowSpec spec where
  type WorkflowState spec
  type WorkflowEvent spec
  type WorkflowObservation spec
  type WorkflowObservedTick spec
  type WorkflowEffect spec
  type WorkflowEffectPlan spec
  type WorkflowReplayResult spec
  type WorkflowError spec

  workflowInitialEvent
    :: WorkflowEvent spec
    -> Either (WorkflowError spec) (WorkflowState spec, WorkflowEffectPlan spec)

  workflowApplyEvent
    :: WorkflowState spec
    -> WorkflowEvent spec
    -> Either (WorkflowError spec) (WorkflowState spec, WorkflowEffectPlan spec)

  workflowObserve
    :: WorkflowState spec
    -> WorkflowObservation spec
    -> Either (WorkflowError spec) (WorkflowObservedTick spec)

  workflowObservedTransition
    :: WorkflowObservedTick spec
    -> PlannedTransition spec

  workflowObservedState
    :: WorkflowObservedTick spec
    -> WorkflowState spec

  workflowPlanTransition
    :: WorkflowEvent spec
    -> WorkflowEffectPlan spec
    -> PlannedTransition spec

  workflowReplayEvents
    :: [WorkflowEvent spec]
    -> Either (WorkflowError spec) (WorkflowReplayResult spec)

  workflowReplayState
    :: WorkflowReplayResult spec
    -> WorkflowState spec

  workflowValidateEffects
    :: WorkflowState spec
    -> WorkflowEffectPlan spec
    -> Either (WorkflowError spec) ()

  workflowEffectPlanEffects
    :: WorkflowEffectPlan spec
    -> [WorkflowEffect spec]

  workflowEffectAllowed
    :: WorkflowState spec
    -> WorkflowEffect spec
    -> Either Text ()

  workflowIsTerminal
    :: WorkflowState spec
    -> Bool

  workflowStateLabel
    :: WorkflowState spec
    -> Text

  workflowEventLabel
    :: WorkflowEvent spec
    -> Text

  workflowObservationLabel
    :: WorkflowObservation spec
    -> Text

  workflowEffectLabel
    :: WorkflowEffect spec
    -> Text

workflowPlanObservation
  :: forall spec. WorkflowSpec spec
  => WorkflowState spec
  -> WorkflowObservation spec
  -> Either (WorkflowError spec) (PlannedTransition spec)
workflowPlanObservation state observation =
  workflowObservedTransition @spec <$> workflowObserve @spec state observation
