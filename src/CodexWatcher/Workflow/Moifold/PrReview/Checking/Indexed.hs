{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}

module CodexWatcher.Workflow.Moifold.PrReview.Checking.Indexed
  ( PrReviewCheckingIndexedSpec
  , PrReviewCheckingIndexedCheckingReviews
  , PrReviewCheckingIndexedEffect (..)
  , PrReviewCheckingIndexedEffectPlan (..)
  , PrReviewCheckingIndexedEvent (..)
  , PrReviewCheckingIndexedFixingReviews
  , PrReviewCheckingIndexedObservation (..)
  , PrReviewCheckingIndexedPoint
  , PrReviewCheckingIndexedReplayResult (..)
  , PrReviewCheckingIndexedReviewingClean
  , PrReviewCheckingIndexedState (..)
  , PrReviewCheckingIndexedTick (..)
  , PrReviewCheckingIndexedUninitialized
  ) where

import CodexWatcher.Effects (EffectPlan, SomeEffect)
import CodexWatcher.EventLog.Types (EventReplayResult (..), WatcherEvent)
import CodexWatcher.Core.State (SomeWatcherState)
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

data PrReviewCheckingIndexedPoint

data PrReviewCheckingIndexedUninitialized

data PrReviewCheckingIndexedCheckingReviews

data PrReviewCheckingIndexedFixingReviews

data PrReviewCheckingIndexedReviewingClean

data PrReviewCheckingIndexedSpec

newtype PrReviewCheckingIndexedState state =
  PrReviewCheckingIndexedState SomeWatcherState

data PrReviewCheckingIndexedEvent source target =
  PrReviewCheckingIndexedEvent Text Text WatcherEvent

data PrReviewCheckingIndexedObservation source target =
  PrReviewCheckingIndexedObservation Text Text DaemonObservation

newtype PrReviewCheckingIndexedEffect source target =
  PrReviewCheckingIndexedEffect SomeEffect

newtype PrReviewCheckingIndexedEffectPlan source target =
  PrReviewCheckingIndexedEffectPlan EffectPlan

data PrReviewCheckingIndexedTick source target =
  PrReviewCheckingIndexedTick Text Text ObservedPolicyTick

newtype PrReviewCheckingIndexedReplayResult state =
  PrReviewCheckingIndexedReplayResult EventReplayResult

type instance IndexedWorkflow.WorkflowIndex PrReviewCheckingIndexedSpec = PrReviewCheckingIndexedPoint

instance IndexedWorkflow.IndexedWorkflowSpec PrReviewCheckingIndexedSpec where
  type IndexedWorkflowState PrReviewCheckingIndexedSpec state = PrReviewCheckingIndexedState state
  type IndexedWorkflowEvent PrReviewCheckingIndexedSpec source target = PrReviewCheckingIndexedEvent source target
  type IndexedWorkflowObservation PrReviewCheckingIndexedSpec source target = PrReviewCheckingIndexedObservation source target
  type IndexedWorkflowObservedTick PrReviewCheckingIndexedSpec source target = PrReviewCheckingIndexedTick source target
  type IndexedWorkflowEffect PrReviewCheckingIndexedSpec source target = PrReviewCheckingIndexedEffect source target
  type IndexedWorkflowEffectPlan PrReviewCheckingIndexedSpec source target = PrReviewCheckingIndexedEffectPlan source target
  type IndexedWorkflowReplayResult PrReviewCheckingIndexedSpec state = PrReviewCheckingIndexedReplayResult state
  type IndexedWorkflowError PrReviewCheckingIndexedSpec = Text

  indexedWorkflowInitialEvent (PrReviewCheckingIndexedEvent _sourceLabel _targetLabel event) =
    case workflowInitialEvent @MoifoldSpec event of
      Right (state, effects) -> Right (PrReviewCheckingIndexedState state, PrReviewCheckingIndexedEffectPlan effects)
      Left failure -> Left failure
  indexedWorkflowApplyEvent (PrReviewCheckingIndexedState state) (PrReviewCheckingIndexedEvent _sourceLabel _targetLabel event) =
    case workflowApplyEvent @MoifoldSpec state event of
      Right (nextState, effects) -> Right (PrReviewCheckingIndexedState nextState, PrReviewCheckingIndexedEffectPlan effects)
      Left failure -> Left failure
  indexedWorkflowObserve (PrReviewCheckingIndexedState state) (PrReviewCheckingIndexedObservation sourceLabel targetLabel observation) =
    case workflowObserve @MoifoldSpec state observation of
      Right observed -> Right (PrReviewCheckingIndexedTick sourceLabel targetLabel observed)
      Left failure -> Left failure
  indexedWorkflowObservedTransition (PrReviewCheckingIndexedTick sourceLabel targetLabel observed) =
    prReviewCheckingIndexedPlannedTransitionFromCompatibility
      sourceLabel
      targetLabel
      (legacyObservedPlannedTransition observed)
  indexedWorkflowObservedState (PrReviewCheckingIndexedTick _sourceLabel _targetLabel observed) =
    PrReviewCheckingIndexedState observed.observedState
  indexedWorkflowPlanTransition (PrReviewCheckingIndexedEvent sourceLabel targetLabel event) (PrReviewCheckingIndexedEffectPlan effects) =
    prReviewCheckingIndexedPlannedTransitionFromCompatibility
      sourceLabel
      targetLabel
      (moifoldPlannedTransitionFromEffects event effects)
  indexedWorkflowReplayEvents events =
    case workflowReplayEvents @MoifoldSpec (prReviewCheckingIndexedSomeEvent <$> events) of
      Right replay -> Right (IndexedWorkflow.SomeIndexedWorkflowReplayResult (PrReviewCheckingIndexedReplayResult replay))
      Left failure -> Left failure
  indexedWorkflowReplayState (PrReviewCheckingIndexedReplayResult replay) =
    PrReviewCheckingIndexedState replay.replayState
  indexedWorkflowValidateEffects (PrReviewCheckingIndexedState state) (PrReviewCheckingIndexedEffectPlan effects) =
    workflowValidateEffects @MoifoldSpec state effects
  indexedWorkflowEffectPlanEffects (PrReviewCheckingIndexedEffectPlan effects) =
    PrReviewCheckingIndexedEffect <$> effects
  indexedWorkflowEffectAllowed (PrReviewCheckingIndexedState state) (PrReviewCheckingIndexedEffect effect) =
    workflowEffectAllowed @MoifoldSpec state effect
  indexedWorkflowIsTerminal (PrReviewCheckingIndexedState state) =
    workflowIsTerminal @MoifoldSpec state
  indexedWorkflowStateLabel (PrReviewCheckingIndexedState state) =
    workflowStateLabel @MoifoldSpec state
  indexedWorkflowEventLabel (PrReviewCheckingIndexedEvent _sourceLabel _targetLabel event) =
    workflowEventLabel @MoifoldSpec event
  indexedWorkflowEventSourceLabel (PrReviewCheckingIndexedEvent sourceLabel _targetLabel _event) =
    sourceLabel
  indexedWorkflowEventTargetLabel (PrReviewCheckingIndexedEvent _sourceLabel targetLabel _event) =
    targetLabel
  indexedWorkflowObservationLabel (PrReviewCheckingIndexedObservation _sourceLabel _targetLabel observation) =
    workflowObservationLabel @MoifoldSpec observation
  indexedWorkflowObservationSourceLabel (PrReviewCheckingIndexedObservation sourceLabel _targetLabel _observation) =
    sourceLabel
  indexedWorkflowObservationTargetLabel (PrReviewCheckingIndexedObservation _sourceLabel targetLabel _observation) =
    targetLabel
  indexedWorkflowEffectLabel (PrReviewCheckingIndexedEffect effect) =
    workflowEffectLabel @MoifoldSpec effect

prReviewCheckingIndexedPlannedTransitionFromCompatibility
  :: Text
  -> Text
  -> PlannedTransition MoifoldSpec
  -> IndexedWorkflow.IndexedPlannedTransition PrReviewCheckingIndexedSpec source target
prReviewCheckingIndexedPlannedTransitionFromCompatibility sourceLabel targetLabel planned =
  IndexedWorkflow.IndexedPlannedTransition
    { IndexedWorkflow.indexedPlannedEvent =
        PrReviewCheckingIndexedEvent sourceLabel targetLabel planned.plannedEvent
    , IndexedWorkflow.indexedPlannedPreCommitEffects =
        PrReviewCheckingIndexedEffectPlan planned.plannedPreCommitEffects
    , IndexedWorkflow.indexedPlannedPostCommitEffects =
        PrReviewCheckingIndexedEffectPlan planned.plannedPostCommitEffects
    }

prReviewCheckingIndexedSomeEvent :: IndexedWorkflow.SomeIndexedWorkflowEvent PrReviewCheckingIndexedSpec -> WatcherEvent
prReviewCheckingIndexedSomeEvent (IndexedWorkflow.SomeIndexedWorkflowEvent (PrReviewCheckingIndexedEvent _sourceLabel _targetLabel event)) =
  event
