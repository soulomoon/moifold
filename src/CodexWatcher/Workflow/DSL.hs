{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

module CodexWatcher.Workflow.DSL
  ( Transition (..)
  , WorkflowM (..)
  , advance
  , emit
  , transitionEffects
  , transitionEvent
  , transitionFromPlan
  , transitionPostCommitEffects
  , transitionPreCommitEffects
  ) where

import CodexWatcher.Workflow.Spec (PlannedTransition (..), WorkflowSpec (..))
import Data.Text (Text)

newtype WorkflowM spec domain phase a = WorkflowM
  { runWorkflowM :: Either Text (a, WorkflowEffectPlan spec)
  }

instance Functor (WorkflowM spec domain phase) where
  fmap f (WorkflowM result) =
    WorkflowM (fmap (\(value, effects) -> (f value, effects)) result)

instance Monoid (WorkflowEffectPlan spec) => Applicative (WorkflowM spec domain phase) where
  pure value =
    WorkflowM (Right (value, mempty))
  WorkflowM left <*> WorkflowM right =
    WorkflowM do
      (f, leftEffects) <- left
      (value, rightEffects) <- right
      pure (f value, leftEffects <> rightEffects)

instance Monoid (WorkflowEffectPlan spec) => Monad (WorkflowM spec domain phase) where
  WorkflowM result >>= next =
    WorkflowM do
      (value, effects) <- result
      let WorkflowM nextResult = next value
      (nextValue, nextEffects) <- nextResult
      pure (nextValue, effects <> nextEffects)

data Transition spec domain from to a = Transition
  { transitionPlannedTransition :: PlannedTransition spec
  , transitionValue :: a
  }

emit :: WorkflowEffectPlan spec -> WorkflowM spec domain phase ()
emit effects =
  WorkflowM (Right ((), effects))

advance
  :: WorkflowSpec spec
  => WorkflowEvent spec
  -> WorkflowM spec domain from a
  -> Either Text (Transition spec domain from to a)
advance event (WorkflowM result) = do
  (value, effects) <- result
  pure (transitionFromPlan event value effects)

transitionFromPlan
  :: WorkflowSpec spec
  => WorkflowEvent spec
  -> a
  -> WorkflowEffectPlan spec
  -> Transition spec domain from to a
transitionFromPlan event value effects =
  Transition
    { transitionPlannedTransition = workflowPlanTransition event effects
    , transitionValue = value
    }

transitionEvent :: Transition spec domain from to a -> WorkflowEvent spec
transitionEvent =
  plannedEvent . transitionPlannedTransition

transitionPreCommitEffects :: Transition spec domain from to a -> WorkflowEffectPlan spec
transitionPreCommitEffects =
  plannedPreCommitEffects . transitionPlannedTransition

transitionPostCommitEffects :: Transition spec domain from to a -> WorkflowEffectPlan spec
transitionPostCommitEffects =
  plannedPostCommitEffects . transitionPlannedTransition

transitionEffects :: Semigroup (WorkflowEffectPlan spec) => Transition spec domain from to a -> WorkflowEffectPlan spec
transitionEffects transition =
  transitionPreCommitEffects transition <> transitionPostCommitEffects transition
