{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}

module CodexWatcher.Workflow.Moifold.PrReview.Reviewer.Indexed
  ( PrReviewReviewerIndexedBlocked
  , PrReviewReviewerIndexedCheckingReviews
  , PrReviewReviewerIndexedEffect (..)
  , PrReviewReviewerIndexedEffectPlan (..)
  , PrReviewReviewerIndexedEvent (..)
  , PrReviewReviewerIndexedFixingReviews
  , PrReviewReviewerIndexedObservation (..)
  , PrReviewReviewerIndexedPoint
  , PrReviewReviewerIndexedReplayResult (..)
  , PrReviewReviewerIndexedReviewingClean
  , PrReviewReviewerIndexedSpec
  , PrReviewReviewerIndexedState (..)
  , PrReviewReviewerIndexedTick (..)
  , PrReviewReviewerIndexedUninitialized
  , PrReviewReviewerIndexedVerifyingReviewFix
  , PrReviewReviewerIndexedWaitingMergeability
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

data PrReviewReviewerIndexedPoint

data PrReviewReviewerIndexedUninitialized

data PrReviewReviewerIndexedCheckingReviews

data PrReviewReviewerIndexedFixingReviews

data PrReviewReviewerIndexedReviewingClean

data PrReviewReviewerIndexedWaitingMergeability

data PrReviewReviewerIndexedVerifyingReviewFix

data PrReviewReviewerIndexedBlocked

data PrReviewReviewerIndexedSpec

newtype PrReviewReviewerIndexedState state =
  PrReviewReviewerIndexedState SomeWatcherState

data PrReviewReviewerIndexedEvent source target =
  PrReviewReviewerIndexedEvent Text Text WatcherEvent

data PrReviewReviewerIndexedObservation source target =
  PrReviewReviewerIndexedObservation Text Text DaemonObservation

newtype PrReviewReviewerIndexedEffect source target =
  PrReviewReviewerIndexedEffect SomeEffect

newtype PrReviewReviewerIndexedEffectPlan source target =
  PrReviewReviewerIndexedEffectPlan EffectPlan

data PrReviewReviewerIndexedTick source target =
  PrReviewReviewerIndexedTick Text Text ObservedPolicyTick

newtype PrReviewReviewerIndexedReplayResult state =
  PrReviewReviewerIndexedReplayResult EventReplayResult

type instance IndexedWorkflow.WorkflowIndex PrReviewReviewerIndexedSpec = PrReviewReviewerIndexedPoint

instance IndexedWorkflow.IndexedWorkflowSpec PrReviewReviewerIndexedSpec where
  type IndexedWorkflowState PrReviewReviewerIndexedSpec state = PrReviewReviewerIndexedState state
  type IndexedWorkflowEvent PrReviewReviewerIndexedSpec source target = PrReviewReviewerIndexedEvent source target
  type IndexedWorkflowObservation PrReviewReviewerIndexedSpec source target = PrReviewReviewerIndexedObservation source target
  type IndexedWorkflowObservedTick PrReviewReviewerIndexedSpec source target = PrReviewReviewerIndexedTick source target
  type IndexedWorkflowEffect PrReviewReviewerIndexedSpec source target = PrReviewReviewerIndexedEffect source target
  type IndexedWorkflowEffectPlan PrReviewReviewerIndexedSpec source target = PrReviewReviewerIndexedEffectPlan source target
  type IndexedWorkflowReplayResult PrReviewReviewerIndexedSpec state = PrReviewReviewerIndexedReplayResult state
  type IndexedWorkflowError PrReviewReviewerIndexedSpec = Text

  indexedWorkflowInitialEvent (PrReviewReviewerIndexedEvent _sourceLabel _targetLabel event) =
    case workflowInitialEvent @MoifoldSpec event of
      Right (state, effects) -> Right (PrReviewReviewerIndexedState state, PrReviewReviewerIndexedEffectPlan effects)
      Left failure -> Left failure
  indexedWorkflowApplyEvent (PrReviewReviewerIndexedState state) (PrReviewReviewerIndexedEvent _sourceLabel _targetLabel event) =
    case workflowApplyEvent @MoifoldSpec state event of
      Right (nextState, effects) -> Right (PrReviewReviewerIndexedState nextState, PrReviewReviewerIndexedEffectPlan effects)
      Left failure -> Left failure
  indexedWorkflowObserve (PrReviewReviewerIndexedState state) (PrReviewReviewerIndexedObservation sourceLabel targetLabel observation) =
    case workflowObserve @MoifoldSpec state observation of
      Right observed -> Right (PrReviewReviewerIndexedTick sourceLabel targetLabel observed)
      Left failure -> Left failure
  indexedWorkflowObservedTransition (PrReviewReviewerIndexedTick sourceLabel targetLabel observed) =
    prReviewReviewerIndexedPlannedTransitionFromCompatibility
      sourceLabel
      targetLabel
      (legacyObservedPlannedTransition observed)
  indexedWorkflowObservedState (PrReviewReviewerIndexedTick _sourceLabel _targetLabel observed) =
    PrReviewReviewerIndexedState observed.observedState
  indexedWorkflowPlanTransition (PrReviewReviewerIndexedEvent sourceLabel targetLabel event) (PrReviewReviewerIndexedEffectPlan effects) =
    prReviewReviewerIndexedPlannedTransitionFromCompatibility
      sourceLabel
      targetLabel
      (moifoldPlannedTransitionFromEffects event effects)
  indexedWorkflowReplayEvents events =
    case workflowReplayEvents @MoifoldSpec (prReviewReviewerIndexedSomeEvent <$> events) of
      Right replay -> Right (IndexedWorkflow.SomeIndexedWorkflowReplayResult (PrReviewReviewerIndexedReplayResult replay))
      Left failure -> Left failure
  indexedWorkflowReplayState (PrReviewReviewerIndexedReplayResult replay) =
    PrReviewReviewerIndexedState replay.replayState
  indexedWorkflowValidateEffects (PrReviewReviewerIndexedState state) (PrReviewReviewerIndexedEffectPlan effects) =
    workflowValidateEffects @MoifoldSpec state effects
  indexedWorkflowEffectPlanEffects (PrReviewReviewerIndexedEffectPlan effects) =
    PrReviewReviewerIndexedEffect <$> effects
  indexedWorkflowEffectAllowed (PrReviewReviewerIndexedState state) (PrReviewReviewerIndexedEffect effect) =
    workflowEffectAllowed @MoifoldSpec state effect
  indexedWorkflowIsTerminal (PrReviewReviewerIndexedState state) =
    workflowIsTerminal @MoifoldSpec state
  indexedWorkflowStateLabel (PrReviewReviewerIndexedState state) =
    workflowStateLabel @MoifoldSpec state
  indexedWorkflowEventLabel (PrReviewReviewerIndexedEvent _sourceLabel _targetLabel event) =
    workflowEventLabel @MoifoldSpec event
  indexedWorkflowEventSourceLabel (PrReviewReviewerIndexedEvent sourceLabel _targetLabel _event) =
    sourceLabel
  indexedWorkflowEventTargetLabel (PrReviewReviewerIndexedEvent _sourceLabel targetLabel _event) =
    targetLabel
  indexedWorkflowObservationLabel (PrReviewReviewerIndexedObservation _sourceLabel _targetLabel observation) =
    workflowObservationLabel @MoifoldSpec observation
  indexedWorkflowObservationSourceLabel (PrReviewReviewerIndexedObservation sourceLabel _targetLabel _observation) =
    sourceLabel
  indexedWorkflowObservationTargetLabel (PrReviewReviewerIndexedObservation _sourceLabel targetLabel _observation) =
    targetLabel
  indexedWorkflowEffectLabel (PrReviewReviewerIndexedEffect effect) =
    workflowEffectLabel @MoifoldSpec effect

prReviewReviewerIndexedPlannedTransitionFromCompatibility
  :: Text
  -> Text
  -> PlannedTransition MoifoldSpec
  -> IndexedWorkflow.IndexedPlannedTransition PrReviewReviewerIndexedSpec source target
prReviewReviewerIndexedPlannedTransitionFromCompatibility sourceLabel targetLabel planned =
  IndexedWorkflow.IndexedPlannedTransition
    { IndexedWorkflow.indexedPlannedEvent =
        PrReviewReviewerIndexedEvent sourceLabel targetLabel planned.plannedEvent
    , IndexedWorkflow.indexedPlannedPreCommitEffects =
        PrReviewReviewerIndexedEffectPlan planned.plannedPreCommitEffects
    , IndexedWorkflow.indexedPlannedPostCommitEffects =
        PrReviewReviewerIndexedEffectPlan planned.plannedPostCommitEffects
    }

prReviewReviewerIndexedSomeEvent :: IndexedWorkflow.SomeIndexedWorkflowEvent PrReviewReviewerIndexedSpec -> WatcherEvent
prReviewReviewerIndexedSomeEvent (IndexedWorkflow.SomeIndexedWorkflowEvent (PrReviewReviewerIndexedEvent _sourceLabel _targetLabel event)) =
  event
