{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}

module CodexWatcher.Workflow.Moifold.IssuePlanning.Indexed
  ( IssuePlanningIndexedActiveTurn
  , IssuePlanningIndexedBlocked
  , IssuePlanningIndexedComplete
  , IssuePlanningIndexedEffect (..)
  , IssuePlanningIndexedEffectPlan (..)
  , IssuePlanningIndexedEvent (..)
  , IssuePlanningIndexedInitialized
  , IssuePlanningIndexedObservation (..)
  , IssuePlanningIndexedPoint
  , IssuePlanningIndexedReplayResult (..)
  , IssuePlanningIndexedSpec
  , IssuePlanningIndexedState (..)
  , IssuePlanningIndexedTick (..)
  , IssuePlanningIndexedWaitingReadyIssues
  , issuePlanningIndexedSomeEvent
  , issuePlanningIndexedTransitionToCompatibility
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

data IssuePlanningIndexedPoint

data IssuePlanningIndexedInitialized

data IssuePlanningIndexedActiveTurn

data IssuePlanningIndexedWaitingReadyIssues

data IssuePlanningIndexedBlocked

data IssuePlanningIndexedComplete

data IssuePlanningIndexedSpec

newtype IssuePlanningIndexedState state =
  IssuePlanningIndexedState SomeWatcherState

data IssuePlanningIndexedEvent source target =
  IssuePlanningIndexedEvent Text Text WatcherEvent

data IssuePlanningIndexedObservation source target =
  IssuePlanningIndexedObservation Text Text DaemonObservation

newtype IssuePlanningIndexedEffect source target =
  IssuePlanningIndexedEffect SomeEffect

newtype IssuePlanningIndexedEffectPlan source target =
  IssuePlanningIndexedEffectPlan EffectPlan

data IssuePlanningIndexedTick source target =
  IssuePlanningIndexedTick Text Text ObservedPolicyTick

newtype IssuePlanningIndexedReplayResult state =
  IssuePlanningIndexedReplayResult EventReplayResult

type instance IndexedWorkflow.WorkflowIndex IssuePlanningIndexedSpec = IssuePlanningIndexedPoint

instance IndexedWorkflow.IndexedWorkflowSpec IssuePlanningIndexedSpec where
  type IndexedWorkflowState IssuePlanningIndexedSpec state = IssuePlanningIndexedState state
  type IndexedWorkflowEvent IssuePlanningIndexedSpec source target = IssuePlanningIndexedEvent source target
  type IndexedWorkflowObservation IssuePlanningIndexedSpec source target = IssuePlanningIndexedObservation source target
  type IndexedWorkflowObservedTick IssuePlanningIndexedSpec source target = IssuePlanningIndexedTick source target
  type IndexedWorkflowEffect IssuePlanningIndexedSpec source target = IssuePlanningIndexedEffect source target
  type IndexedWorkflowEffectPlan IssuePlanningIndexedSpec source target = IssuePlanningIndexedEffectPlan source target
  type IndexedWorkflowReplayResult IssuePlanningIndexedSpec state = IssuePlanningIndexedReplayResult state
  type IndexedWorkflowError IssuePlanningIndexedSpec = Text

  indexedWorkflowInitialEvent (IssuePlanningIndexedEvent _sourceLabel _targetLabel event) =
    case workflowInitialEvent @MoifoldSpec event of
      Right (state, effects) -> Right (IssuePlanningIndexedState state, IssuePlanningIndexedEffectPlan effects)
      Left failure -> Left failure
  indexedWorkflowApplyEvent (IssuePlanningIndexedState state) (IssuePlanningIndexedEvent _sourceLabel _targetLabel event) =
    case workflowApplyEvent @MoifoldSpec state event of
      Right (nextState, effects) -> Right (IssuePlanningIndexedState nextState, IssuePlanningIndexedEffectPlan effects)
      Left failure -> Left failure
  indexedWorkflowObserve (IssuePlanningIndexedState state) (IssuePlanningIndexedObservation sourceLabel targetLabel observation) =
    case workflowObserve @MoifoldSpec state observation of
      Right observed -> Right (IssuePlanningIndexedTick sourceLabel targetLabel observed)
      Left failure -> Left failure
  indexedWorkflowObservedTransition (IssuePlanningIndexedTick sourceLabel targetLabel observed) =
    issuePlanningIndexedPlannedTransitionFromCompatibility
      sourceLabel
      targetLabel
      (legacyObservedPlannedTransition observed)
  indexedWorkflowObservedState (IssuePlanningIndexedTick _sourceLabel _targetLabel observed) =
    IssuePlanningIndexedState observed.observedState
  indexedWorkflowPlanTransition (IssuePlanningIndexedEvent sourceLabel targetLabel event) (IssuePlanningIndexedEffectPlan effects) =
    issuePlanningIndexedPlannedTransitionFromCompatibility
      sourceLabel
      targetLabel
      (moifoldPlannedTransitionFromEffects event effects)
  indexedWorkflowReplayEvents events =
    case workflowReplayEvents @MoifoldSpec (issuePlanningIndexedSomeEvent <$> events) of
      Right replay -> Right (IndexedWorkflow.SomeIndexedWorkflowReplayResult (IssuePlanningIndexedReplayResult replay))
      Left failure -> Left failure
  indexedWorkflowReplayState (IssuePlanningIndexedReplayResult replay) =
    IssuePlanningIndexedState replay.replayState
  indexedWorkflowValidateEffects (IssuePlanningIndexedState state) (IssuePlanningIndexedEffectPlan effects) =
    workflowValidateEffects @MoifoldSpec state effects
  indexedWorkflowEffectPlanEffects (IssuePlanningIndexedEffectPlan effects) =
    IssuePlanningIndexedEffect <$> effects
  indexedWorkflowEffectAllowed (IssuePlanningIndexedState state) (IssuePlanningIndexedEffect effect) =
    workflowEffectAllowed @MoifoldSpec state effect
  indexedWorkflowIsTerminal (IssuePlanningIndexedState state) =
    workflowIsTerminal @MoifoldSpec state
  indexedWorkflowStateLabel (IssuePlanningIndexedState state) =
    workflowStateLabel @MoifoldSpec state
  indexedWorkflowEventLabel (IssuePlanningIndexedEvent _sourceLabel _targetLabel event) =
    workflowEventLabel @MoifoldSpec event
  indexedWorkflowEventSourceLabel (IssuePlanningIndexedEvent sourceLabel _targetLabel _event) =
    sourceLabel
  indexedWorkflowEventTargetLabel (IssuePlanningIndexedEvent _sourceLabel targetLabel _event) =
    targetLabel
  indexedWorkflowObservationLabel (IssuePlanningIndexedObservation _sourceLabel _targetLabel observation) =
    workflowObservationLabel @MoifoldSpec observation
  indexedWorkflowObservationSourceLabel (IssuePlanningIndexedObservation sourceLabel _targetLabel _observation) =
    sourceLabel
  indexedWorkflowObservationTargetLabel (IssuePlanningIndexedObservation _sourceLabel targetLabel _observation) =
    targetLabel
  indexedWorkflowEffectLabel (IssuePlanningIndexedEffect effect) =
    workflowEffectLabel @MoifoldSpec effect

issuePlanningIndexedPlannedTransitionFromCompatibility
  :: Text
  -> Text
  -> PlannedTransition MoifoldSpec
  -> IndexedWorkflow.IndexedPlannedTransition IssuePlanningIndexedSpec source target
issuePlanningIndexedPlannedTransitionFromCompatibility sourceLabel targetLabel planned =
  IndexedWorkflow.IndexedPlannedTransition
    { IndexedWorkflow.indexedPlannedEvent =
        IssuePlanningIndexedEvent sourceLabel targetLabel planned.plannedEvent
    , IndexedWorkflow.indexedPlannedPreCommitEffects =
        IssuePlanningIndexedEffectPlan planned.plannedPreCommitEffects
    , IndexedWorkflow.indexedPlannedPostCommitEffects =
        IssuePlanningIndexedEffectPlan planned.plannedPostCommitEffects
    }

issuePlanningIndexedSomeEvent :: IndexedWorkflow.SomeIndexedWorkflowEvent IssuePlanningIndexedSpec -> WatcherEvent
issuePlanningIndexedSomeEvent (IndexedWorkflow.SomeIndexedWorkflowEvent (IssuePlanningIndexedEvent _sourceLabel _targetLabel event)) =
  event

issuePlanningIndexedTransitionToCompatibility
  :: IndexedWorkflow.IndexedPlannedTransition IssuePlanningIndexedSpec source target
  -> PlannedTransition MoifoldSpec
issuePlanningIndexedTransitionToCompatibility transition =
  PlannedTransition
    { plannedEvent = event
    , plannedPreCommitEffects = preCommitEffects
    , plannedPostCommitEffects = postCommitEffects
    }
 where
  IssuePlanningIndexedEvent _sourceLabel _targetLabel event =
    IndexedWorkflow.indexedPlannedEvent transition
  IssuePlanningIndexedEffectPlan preCommitEffects =
    IndexedWorkflow.indexedPlannedPreCommitEffects transition
  IssuePlanningIndexedEffectPlan postCommitEffects =
    IndexedWorkflow.indexedPlannedPostCommitEffects transition
