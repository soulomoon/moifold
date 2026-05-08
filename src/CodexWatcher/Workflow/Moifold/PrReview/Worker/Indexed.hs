{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}

module CodexWatcher.Workflow.Moifold.PrReview.Worker.Indexed
  ( PrReviewWorkerIndexedSpec
  , PrReviewWorkerIndexedBlocked
  , PrReviewWorkerIndexedCheckingReviews
  , PrReviewWorkerIndexedEffect (..)
  , PrReviewWorkerIndexedEffectPlan (..)
  , PrReviewWorkerIndexedEvent (..)
  , PrReviewWorkerIndexedFixingReviews
  , PrReviewWorkerIndexedObservation (..)
  , PrReviewWorkerIndexedPoint
  , PrReviewWorkerIndexedReplayResult (..)
  , PrReviewWorkerIndexedReviewingClean
  , PrReviewWorkerIndexedState (..)
  , PrReviewWorkerIndexedTick (..)
  , PrReviewWorkerIndexedUninitialized
  ) where

import CodexWatcher.Core.State (SomeWatcherState)
import CodexWatcher.Effects (EffectPlan, SomeEffect)
import CodexWatcher.EventLog.Types (EventReplayResult (..), WatcherEvent)
import CodexWatcher.Workflow.Indexed.Spec qualified as IndexedWorkflow
import CodexWatcher.Workflow.Observation (DaemonObservation, ObservedPolicyTick (..))
import CodexWatcher.Workflow.Types
  ( MoifoldSpec
  , PlannedTransition (..)
  , WorkflowSpec (..)
  , legacyObservedPlannedTransition
  , moifoldPlannedTransitionFromEffects
  )
import Data.Text (Text)

data PrReviewWorkerIndexedPoint

data PrReviewWorkerIndexedUninitialized

data PrReviewWorkerIndexedCheckingReviews

data PrReviewWorkerIndexedFixingReviews

data PrReviewWorkerIndexedReviewingClean

data PrReviewWorkerIndexedBlocked

data PrReviewWorkerIndexedSpec

newtype PrReviewWorkerIndexedState state =
  PrReviewWorkerIndexedState SomeWatcherState

data PrReviewWorkerIndexedEvent source target =
  PrReviewWorkerIndexedEvent Text Text WatcherEvent

data PrReviewWorkerIndexedObservation source target =
  PrReviewWorkerIndexedObservation Text Text DaemonObservation

newtype PrReviewWorkerIndexedEffect source target =
  PrReviewWorkerIndexedEffect SomeEffect

newtype PrReviewWorkerIndexedEffectPlan source target =
  PrReviewWorkerIndexedEffectPlan EffectPlan

data PrReviewWorkerIndexedTick source target =
  PrReviewWorkerIndexedTick Text Text ObservedPolicyTick

newtype PrReviewWorkerIndexedReplayResult state =
  PrReviewWorkerIndexedReplayResult EventReplayResult

type instance IndexedWorkflow.WorkflowIndex PrReviewWorkerIndexedSpec = PrReviewWorkerIndexedPoint

instance IndexedWorkflow.IndexedWorkflowSpec PrReviewWorkerIndexedSpec where
  type IndexedWorkflowState PrReviewWorkerIndexedSpec state = PrReviewWorkerIndexedState state
  type IndexedWorkflowEvent PrReviewWorkerIndexedSpec source target = PrReviewWorkerIndexedEvent source target
  type IndexedWorkflowObservation PrReviewWorkerIndexedSpec source target = PrReviewWorkerIndexedObservation source target
  type IndexedWorkflowObservedTick PrReviewWorkerIndexedSpec source target = PrReviewWorkerIndexedTick source target
  type IndexedWorkflowEffect PrReviewWorkerIndexedSpec source target = PrReviewWorkerIndexedEffect source target
  type IndexedWorkflowEffectPlan PrReviewWorkerIndexedSpec source target = PrReviewWorkerIndexedEffectPlan source target
  type IndexedWorkflowReplayResult PrReviewWorkerIndexedSpec state = PrReviewWorkerIndexedReplayResult state
  type IndexedWorkflowError PrReviewWorkerIndexedSpec = Text

  indexedWorkflowInitialEvent (PrReviewWorkerIndexedEvent _sourceLabel _targetLabel event) =
    case workflowInitialEvent @MoifoldSpec event of
      Right (state, effects) -> Right (PrReviewWorkerIndexedState state, PrReviewWorkerIndexedEffectPlan effects)
      Left failure -> Left failure
  indexedWorkflowApplyEvent (PrReviewWorkerIndexedState state) (PrReviewWorkerIndexedEvent _sourceLabel _targetLabel event) =
    case workflowApplyEvent @MoifoldSpec state event of
      Right (nextState, effects) -> Right (PrReviewWorkerIndexedState nextState, PrReviewWorkerIndexedEffectPlan effects)
      Left failure -> Left failure
  indexedWorkflowObserve (PrReviewWorkerIndexedState state) (PrReviewWorkerIndexedObservation sourceLabel targetLabel observation) =
    case workflowObserve @MoifoldSpec state observation of
      Right observed -> Right (PrReviewWorkerIndexedTick sourceLabel targetLabel observed)
      Left failure -> Left failure
  indexedWorkflowObservedTransition (PrReviewWorkerIndexedTick sourceLabel targetLabel observed) =
    prReviewWorkerIndexedPlannedTransitionFromCompatibility
      sourceLabel
      targetLabel
      (legacyObservedPlannedTransition observed)
  indexedWorkflowObservedState (PrReviewWorkerIndexedTick _sourceLabel _targetLabel observed) =
    PrReviewWorkerIndexedState observed.observedState
  indexedWorkflowPlanTransition (PrReviewWorkerIndexedEvent sourceLabel targetLabel event) (PrReviewWorkerIndexedEffectPlan effects) =
    prReviewWorkerIndexedPlannedTransitionFromCompatibility
      sourceLabel
      targetLabel
      (moifoldPlannedTransitionFromEffects event effects)
  indexedWorkflowReplayEvents events =
    case workflowReplayEvents @MoifoldSpec (prReviewWorkerIndexedSomeEvent <$> events) of
      Right replay -> Right (IndexedWorkflow.SomeIndexedWorkflowReplayResult (PrReviewWorkerIndexedReplayResult replay))
      Left failure -> Left failure
  indexedWorkflowReplayState (PrReviewWorkerIndexedReplayResult replay) =
    PrReviewWorkerIndexedState replay.replayState
  indexedWorkflowValidateEffects (PrReviewWorkerIndexedState state) (PrReviewWorkerIndexedEffectPlan effects) =
    workflowValidateEffects @MoifoldSpec state effects
  indexedWorkflowEffectPlanEffects (PrReviewWorkerIndexedEffectPlan effects) =
    PrReviewWorkerIndexedEffect <$> effects
  indexedWorkflowEffectAllowed (PrReviewWorkerIndexedState state) (PrReviewWorkerIndexedEffect effect) =
    workflowEffectAllowed @MoifoldSpec state effect
  indexedWorkflowIsTerminal (PrReviewWorkerIndexedState state) =
    workflowIsTerminal @MoifoldSpec state
  indexedWorkflowStateLabel (PrReviewWorkerIndexedState state) =
    workflowStateLabel @MoifoldSpec state
  indexedWorkflowEventLabel (PrReviewWorkerIndexedEvent _sourceLabel _targetLabel event) =
    workflowEventLabel @MoifoldSpec event
  indexedWorkflowEventSourceLabel (PrReviewWorkerIndexedEvent sourceLabel _targetLabel _event) =
    sourceLabel
  indexedWorkflowEventTargetLabel (PrReviewWorkerIndexedEvent _sourceLabel targetLabel _event) =
    targetLabel
  indexedWorkflowObservationLabel (PrReviewWorkerIndexedObservation _sourceLabel _targetLabel observation) =
    workflowObservationLabel @MoifoldSpec observation
  indexedWorkflowObservationSourceLabel (PrReviewWorkerIndexedObservation sourceLabel _targetLabel _observation) =
    sourceLabel
  indexedWorkflowObservationTargetLabel (PrReviewWorkerIndexedObservation _sourceLabel targetLabel _observation) =
    targetLabel
  indexedWorkflowEffectLabel (PrReviewWorkerIndexedEffect effect) =
    workflowEffectLabel @MoifoldSpec effect

prReviewWorkerIndexedPlannedTransitionFromCompatibility
  :: Text
  -> Text
  -> PlannedTransition MoifoldSpec
  -> IndexedWorkflow.IndexedPlannedTransition PrReviewWorkerIndexedSpec source target
prReviewWorkerIndexedPlannedTransitionFromCompatibility sourceLabel targetLabel planned =
  IndexedWorkflow.IndexedPlannedTransition
    { IndexedWorkflow.indexedPlannedEvent =
        PrReviewWorkerIndexedEvent sourceLabel targetLabel planned.plannedEvent
    , IndexedWorkflow.indexedPlannedPreCommitEffects =
        PrReviewWorkerIndexedEffectPlan planned.plannedPreCommitEffects
    , IndexedWorkflow.indexedPlannedPostCommitEffects =
        PrReviewWorkerIndexedEffectPlan planned.plannedPostCommitEffects
    }

prReviewWorkerIndexedSomeEvent :: IndexedWorkflow.SomeIndexedWorkflowEvent PrReviewWorkerIndexedSpec -> WatcherEvent
prReviewWorkerIndexedSomeEvent (IndexedWorkflow.SomeIndexedWorkflowEvent (PrReviewWorkerIndexedEvent _sourceLabel _targetLabel event)) =
  event
