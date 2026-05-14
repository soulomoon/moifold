{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}

module CodexWatcher.Workflow.Moifold.IssueImplement.Indexed.Types
  ( IssueImplementIndexedBlocked
  , IssueImplementIndexedComplete
  , IssueImplementIndexedEffect (..)
  , IssueImplementIndexedEffectPlan (..)
  , IssueImplementIndexedEvent (..)
  , IssueImplementIndexedHandoffInitialized
  , IssueImplementIndexedHandoffReady
  , IssueImplementIndexedImplementationReady
  , IssueImplementIndexedImplementing
  , IssueImplementIndexedInPlanMode
  , IssueImplementIndexedObservation (..)
  , IssueImplementIndexedPlanReady
  , IssueImplementIndexedPoint
  , IssueImplementIndexedPostMergeReviewPendingReviewer
  , IssueImplementIndexedPostMergeReviewReady
  , IssueImplementIndexedPostMergeReviewing
  , IssueImplementIndexedProjection (..)
  , IssueImplementIndexedReadyToPlan
  , IssueImplementIndexedReplayResult (..)
  , IssueImplementIndexedSpec
  , IssueImplementIndexedState (..)
  , IssueImplementIndexedTick (..)
  , IssueImplementIndexedWaitingForIssueClose
  , IssueImplementIndexedWaitingForPrMerge
  , issueImplementIndexedSomeEvent
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

data IssueImplementIndexedPoint

data IssueImplementIndexedReadyToPlan

data IssueImplementIndexedInPlanMode

data IssueImplementIndexedPlanReady

data IssueImplementIndexedImplementationReady

data IssueImplementIndexedImplementing

data IssueImplementIndexedHandoffReady

data IssueImplementIndexedHandoffInitialized

data IssueImplementIndexedWaitingForPrMerge

data IssueImplementIndexedPostMergeReviewPendingReviewer

data IssueImplementIndexedPostMergeReviewReady

data IssueImplementIndexedPostMergeReviewing

data IssueImplementIndexedWaitingForIssueClose

data IssueImplementIndexedBlocked

data IssueImplementIndexedComplete

data IssueImplementIndexedSpec

newtype IssueImplementIndexedState state =
  IssueImplementIndexedState SomeWatcherState

data IssueImplementIndexedEvent source target =
  IssueImplementIndexedEvent Text Text WatcherEvent

data IssueImplementIndexedObservation source target =
  IssueImplementIndexedObservation Text Text DaemonObservation

newtype IssueImplementIndexedEffect source target =
  IssueImplementIndexedEffect SomeEffect

newtype IssueImplementIndexedEffectPlan source target =
  IssueImplementIndexedEffectPlan EffectPlan

data IssueImplementIndexedTick source target =
  IssueImplementIndexedTick Text Text ObservedPolicyTick

newtype IssueImplementIndexedReplayResult state =
  IssueImplementIndexedReplayResult EventReplayResult

data IssueImplementIndexedProjection = IssueImplementIndexedProjection
  { issueImplementIndexedProjectionPlanned :: PlannedTransition MoifoldSpec
  , issueImplementIndexedProjectionFinalState :: SomeWatcherState
  , issueImplementIndexedProjectionSourceLabel :: Text
  , issueImplementIndexedProjectionTargetLabel :: Text
  , issueImplementIndexedProjectionEffectPlan :: EffectPlan
  }

type instance IndexedWorkflow.WorkflowIndex IssueImplementIndexedSpec = IssueImplementIndexedPoint

instance IndexedWorkflow.IndexedWorkflowSpec IssueImplementIndexedSpec where
  type IndexedWorkflowState IssueImplementIndexedSpec state = IssueImplementIndexedState state
  type IndexedWorkflowEvent IssueImplementIndexedSpec source target = IssueImplementIndexedEvent source target
  type IndexedWorkflowObservation IssueImplementIndexedSpec source target = IssueImplementIndexedObservation source target
  type IndexedWorkflowObservedTick IssueImplementIndexedSpec source target = IssueImplementIndexedTick source target
  type IndexedWorkflowEffect IssueImplementIndexedSpec source target = IssueImplementIndexedEffect source target
  type IndexedWorkflowEffectPlan IssueImplementIndexedSpec source target = IssueImplementIndexedEffectPlan source target
  type IndexedWorkflowReplayResult IssueImplementIndexedSpec state = IssueImplementIndexedReplayResult state
  type IndexedWorkflowError IssueImplementIndexedSpec = Text

  indexedWorkflowInitialEvent (IssueImplementIndexedEvent _sourceLabel _targetLabel event) =
    case workflowInitialEvent @MoifoldSpec event of
      Right (state, effects) -> Right (IssueImplementIndexedState state, IssueImplementIndexedEffectPlan effects)
      Left failure -> Left failure
  indexedWorkflowApplyEvent (IssueImplementIndexedState state) (IssueImplementIndexedEvent _sourceLabel _targetLabel event) =
    case workflowApplyEvent @MoifoldSpec state event of
      Right (nextState, effects) -> Right (IssueImplementIndexedState nextState, IssueImplementIndexedEffectPlan effects)
      Left failure -> Left failure
  indexedWorkflowObserve (IssueImplementIndexedState state) (IssueImplementIndexedObservation sourceLabel targetLabel observation) =
    case workflowObserve @MoifoldSpec state observation of
      Right observed -> Right (IssueImplementIndexedTick sourceLabel targetLabel observed)
      Left failure -> Left failure
  indexedWorkflowObservedTransition (IssueImplementIndexedTick sourceLabel targetLabel observed) =
    issueImplementIndexedPlannedTransitionFromCompatibility
      sourceLabel
      targetLabel
      (legacyObservedPlannedTransition observed)
  indexedWorkflowObservedState (IssueImplementIndexedTick _sourceLabel _targetLabel observed) =
    IssueImplementIndexedState observed.observedState
  indexedWorkflowPlanTransition (IssueImplementIndexedEvent sourceLabel targetLabel event) (IssueImplementIndexedEffectPlan effects) =
    issueImplementIndexedPlannedTransitionFromCompatibility
      sourceLabel
      targetLabel
      (moifoldPlannedTransitionFromEffects event effects)
  indexedWorkflowReplayEvents events =
    case workflowReplayEvents @MoifoldSpec (issueImplementIndexedSomeEvent <$> events) of
      Right replay -> Right (IndexedWorkflow.SomeIndexedWorkflowReplayResult (IssueImplementIndexedReplayResult replay))
      Left failure -> Left failure
  indexedWorkflowReplayState (IssueImplementIndexedReplayResult replay) =
    IssueImplementIndexedState replay.replayState
  indexedWorkflowValidateEffects (IssueImplementIndexedState state) (IssueImplementIndexedEffectPlan effects) =
    workflowValidateEffects @MoifoldSpec state effects
  indexedWorkflowEffectPlanEffects (IssueImplementIndexedEffectPlan effects) =
    IssueImplementIndexedEffect <$> effects
  indexedWorkflowEffectAllowed (IssueImplementIndexedState state) (IssueImplementIndexedEffect effect) =
    workflowEffectAllowed @MoifoldSpec state effect
  indexedWorkflowIsTerminal (IssueImplementIndexedState state) =
    workflowIsTerminal @MoifoldSpec state
  indexedWorkflowStateLabel (IssueImplementIndexedState state) =
    workflowStateLabel @MoifoldSpec state
  indexedWorkflowEventLabel (IssueImplementIndexedEvent _sourceLabel _targetLabel event) =
    workflowEventLabel @MoifoldSpec event
  indexedWorkflowEventSourceLabel (IssueImplementIndexedEvent sourceLabel _targetLabel _event) =
    sourceLabel
  indexedWorkflowEventTargetLabel (IssueImplementIndexedEvent _sourceLabel targetLabel _event) =
    targetLabel
  indexedWorkflowObservationLabel (IssueImplementIndexedObservation _sourceLabel _targetLabel observation) =
    workflowObservationLabel @MoifoldSpec observation
  indexedWorkflowObservationSourceLabel (IssueImplementIndexedObservation sourceLabel _targetLabel _observation) =
    sourceLabel
  indexedWorkflowObservationTargetLabel (IssueImplementIndexedObservation _sourceLabel targetLabel _observation) =
    targetLabel
  indexedWorkflowEffectLabel (IssueImplementIndexedEffect effect) =
    workflowEffectLabel @MoifoldSpec effect

issueImplementIndexedPlannedTransitionFromCompatibility
  :: Text
  -> Text
  -> PlannedTransition MoifoldSpec
  -> IndexedWorkflow.IndexedPlannedTransition IssueImplementIndexedSpec source target
issueImplementIndexedPlannedTransitionFromCompatibility sourceLabel targetLabel planned =
  IndexedWorkflow.IndexedPlannedTransition
    { IndexedWorkflow.indexedPlannedEvent =
        IssueImplementIndexedEvent sourceLabel targetLabel planned.plannedEvent
    , IndexedWorkflow.indexedPlannedPreCommitEffects =
        IssueImplementIndexedEffectPlan planned.plannedPreCommitEffects
    , IndexedWorkflow.indexedPlannedPostCommitEffects =
        IssueImplementIndexedEffectPlan planned.plannedPostCommitEffects
    }

issueImplementIndexedSomeEvent :: IndexedWorkflow.SomeIndexedWorkflowEvent IssueImplementIndexedSpec -> WatcherEvent
issueImplementIndexedSomeEvent (IndexedWorkflow.SomeIndexedWorkflowEvent (IssueImplementIndexedEvent _sourceLabel _targetLabel event)) =
  event
