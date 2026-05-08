{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}

module CodexWatcher.Workflow.Moifold.PrReview.Mergeability.Indexed
  ( PrReviewMergeabilityIndexedSpec
  , PrReviewIndexedBlocked
  , PrReviewIndexedCheckingReviews
  , PrReviewIndexedComplete
  , PrReviewIndexedEffect (..)
  , PrReviewIndexedEffectPlan (..)
  , PrReviewIndexedEvent (..)
  , PrReviewIndexedFixingReviews
  , PrReviewIndexedMerging
  , PrReviewIndexedObservation (..)
  , PrReviewIndexedPoint
  , PrReviewIndexedReplayResult (..)
  , PrReviewIndexedReviewingClean
  , PrReviewIndexedState (..)
  , PrReviewIndexedTick (..)
  , PrReviewIndexedUninitialized
  , PrReviewIndexedWaitingForMergeability
  , PrReviewMergeabilityIndexedProjection (..)
  , projectPrReviewMergeabilityCleanObservation
  ) where

import CodexWatcher.Effects (EffectPlan, SomeEffect)
import CodexWatcher.EventLog.Types (EventReplayResult (..), WatcherEvent)
import CodexWatcher.Core.Ids (CommitSha)
import CodexWatcher.Core.State (SomeWatcherState)
import CodexWatcher.Domain.PrReview.Watcher (PrReviewObservation (..))
import CodexWatcher.Workflow.Indexed.Spec qualified as IndexedWorkflow
import CodexWatcher.Workflow.Observation (DaemonObservation (..), ObservedPolicyTick (..))
import CodexWatcher.Workflow.Types
  ( MoifoldSpec
  , PlannedTransition (..)
  , WorkflowSpec (..)
  , legacyObservedPlannedTransition
  , moifoldPlannedTransitionFromEffects
  )
import Data.Text (Text)

data PrReviewIndexedPoint

data PrReviewIndexedUninitialized

data PrReviewIndexedCheckingReviews

data PrReviewIndexedFixingReviews

data PrReviewIndexedReviewingClean

data PrReviewIndexedWaitingForMergeability

data PrReviewIndexedMerging

data PrReviewIndexedBlocked

data PrReviewIndexedComplete

data PrReviewMergeabilityIndexedSpec

newtype PrReviewIndexedState state =
  PrReviewIndexedState SomeWatcherState

data PrReviewIndexedEvent source target =
  PrReviewIndexedEvent Text Text WatcherEvent

data PrReviewIndexedObservation source target =
  PrReviewIndexedObservation Text Text DaemonObservation

newtype PrReviewIndexedEffect source target =
  PrReviewIndexedEffect SomeEffect

newtype PrReviewIndexedEffectPlan source target =
  PrReviewIndexedEffectPlan EffectPlan

data PrReviewIndexedTick source target =
  PrReviewIndexedTick Text Text ObservedPolicyTick

newtype PrReviewIndexedReplayResult state =
  PrReviewIndexedReplayResult EventReplayResult

data PrReviewMergeabilityIndexedProjection = PrReviewMergeabilityIndexedProjection
  { prReviewMergeabilityIndexedProjectionPlanned :: PlannedTransition MoifoldSpec
  , prReviewMergeabilityIndexedProjectionFinalState :: SomeWatcherState
  , prReviewMergeabilityIndexedProjectionSourceLabel :: Text
  , prReviewMergeabilityIndexedProjectionTargetLabel :: Text
  , prReviewMergeabilityIndexedProjectionEffectPlan :: EffectPlan
  }

type instance IndexedWorkflow.WorkflowIndex PrReviewMergeabilityIndexedSpec = PrReviewIndexedPoint

instance IndexedWorkflow.IndexedWorkflowSpec PrReviewMergeabilityIndexedSpec where
  type IndexedWorkflowState PrReviewMergeabilityIndexedSpec state = PrReviewIndexedState state
  type IndexedWorkflowEvent PrReviewMergeabilityIndexedSpec source target = PrReviewIndexedEvent source target
  type IndexedWorkflowObservation PrReviewMergeabilityIndexedSpec source target = PrReviewIndexedObservation source target
  type IndexedWorkflowObservedTick PrReviewMergeabilityIndexedSpec source target = PrReviewIndexedTick source target
  type IndexedWorkflowEffect PrReviewMergeabilityIndexedSpec source target = PrReviewIndexedEffect source target
  type IndexedWorkflowEffectPlan PrReviewMergeabilityIndexedSpec source target = PrReviewIndexedEffectPlan source target
  type IndexedWorkflowReplayResult PrReviewMergeabilityIndexedSpec state = PrReviewIndexedReplayResult state
  type IndexedWorkflowError PrReviewMergeabilityIndexedSpec = Text

  indexedWorkflowInitialEvent (PrReviewIndexedEvent _sourceLabel _targetLabel event) =
    case workflowInitialEvent @MoifoldSpec event of
      Right (state, effects) -> Right (PrReviewIndexedState state, PrReviewIndexedEffectPlan effects)
      Left failure -> Left failure
  indexedWorkflowApplyEvent (PrReviewIndexedState state) (PrReviewIndexedEvent _sourceLabel _targetLabel event) =
    case workflowApplyEvent @MoifoldSpec state event of
      Right (nextState, effects) -> Right (PrReviewIndexedState nextState, PrReviewIndexedEffectPlan effects)
      Left failure -> Left failure
  indexedWorkflowObserve (PrReviewIndexedState state) (PrReviewIndexedObservation sourceLabel targetLabel observation) =
    case workflowObserve @MoifoldSpec state observation of
      Right observed -> Right (PrReviewIndexedTick sourceLabel targetLabel observed)
      Left failure -> Left failure
  indexedWorkflowObservedTransition (PrReviewIndexedTick sourceLabel targetLabel observed) =
    prReviewIndexedPlannedTransitionFromCompatibility
      sourceLabel
      targetLabel
      (legacyObservedPlannedTransition observed)
  indexedWorkflowObservedState (PrReviewIndexedTick _sourceLabel _targetLabel observed) =
    PrReviewIndexedState observed.observedState
  indexedWorkflowPlanTransition (PrReviewIndexedEvent sourceLabel targetLabel event) (PrReviewIndexedEffectPlan effects) =
    prReviewIndexedPlannedTransitionFromCompatibility
      sourceLabel
      targetLabel
      (moifoldPlannedTransitionFromEffects event effects)
  indexedWorkflowReplayEvents events =
    case workflowReplayEvents @MoifoldSpec (prReviewIndexedSomeEvent <$> events) of
      Right replay -> Right (IndexedWorkflow.SomeIndexedWorkflowReplayResult (PrReviewIndexedReplayResult replay))
      Left failure -> Left failure
  indexedWorkflowReplayState (PrReviewIndexedReplayResult replay) =
    PrReviewIndexedState replay.replayState
  indexedWorkflowValidateEffects (PrReviewIndexedState state) (PrReviewIndexedEffectPlan effects) =
    workflowValidateEffects @MoifoldSpec state effects
  indexedWorkflowEffectPlanEffects (PrReviewIndexedEffectPlan effects) =
    PrReviewIndexedEffect <$> effects
  indexedWorkflowEffectAllowed (PrReviewIndexedState state) (PrReviewIndexedEffect effect) =
    workflowEffectAllowed @MoifoldSpec state effect
  indexedWorkflowIsTerminal (PrReviewIndexedState state) =
    workflowIsTerminal @MoifoldSpec state
  indexedWorkflowStateLabel (PrReviewIndexedState state) =
    workflowStateLabel @MoifoldSpec state
  indexedWorkflowEventLabel (PrReviewIndexedEvent _sourceLabel _targetLabel event) =
    workflowEventLabel @MoifoldSpec event
  indexedWorkflowEventSourceLabel (PrReviewIndexedEvent sourceLabel _targetLabel _event) =
    sourceLabel
  indexedWorkflowEventTargetLabel (PrReviewIndexedEvent _sourceLabel targetLabel _event) =
    targetLabel
  indexedWorkflowObservationLabel (PrReviewIndexedObservation _sourceLabel _targetLabel observation) =
    workflowObservationLabel @MoifoldSpec observation
  indexedWorkflowObservationSourceLabel (PrReviewIndexedObservation sourceLabel _targetLabel _observation) =
    sourceLabel
  indexedWorkflowObservationTargetLabel (PrReviewIndexedObservation _sourceLabel targetLabel _observation) =
    targetLabel
  indexedWorkflowEffectLabel (PrReviewIndexedEffect effect) =
    workflowEffectLabel @MoifoldSpec effect

prReviewIndexedPlannedTransitionFromCompatibility
  :: Text
  -> Text
  -> PlannedTransition MoifoldSpec
  -> IndexedWorkflow.IndexedPlannedTransition PrReviewMergeabilityIndexedSpec source target
prReviewIndexedPlannedTransitionFromCompatibility sourceLabel targetLabel planned =
  IndexedWorkflow.IndexedPlannedTransition
    { IndexedWorkflow.indexedPlannedEvent =
        PrReviewIndexedEvent sourceLabel targetLabel planned.plannedEvent
    , IndexedWorkflow.indexedPlannedPreCommitEffects =
        PrReviewIndexedEffectPlan planned.plannedPreCommitEffects
    , IndexedWorkflow.indexedPlannedPostCommitEffects =
        PrReviewIndexedEffectPlan planned.plannedPostCommitEffects
    }

prReviewIndexedSomeEvent :: IndexedWorkflow.SomeIndexedWorkflowEvent PrReviewMergeabilityIndexedSpec -> WatcherEvent
prReviewIndexedSomeEvent (IndexedWorkflow.SomeIndexedWorkflowEvent (PrReviewIndexedEvent _sourceLabel _targetLabel event)) =
  event

projectPrReviewMergeabilityCleanObservation
  :: SomeWatcherState
  -> CommitSha
  -> Either Text PrReviewMergeabilityIndexedProjection
projectPrReviewMergeabilityCleanObservation state commit = do
  observed <-
    IndexedWorkflow.indexedWorkflowObserve
      @PrReviewMergeabilityIndexedSpec
      indexedState
      indexedObservation
  planned <-
    IndexedWorkflow.indexedWorkflowPlanObservation
      @PrReviewMergeabilityIndexedSpec
      indexedState
      indexedObservation
  let PrReviewIndexedState finalState =
        IndexedWorkflow.indexedWorkflowObservedState @PrReviewMergeabilityIndexedSpec observed
      projectedPlan = prReviewIndexedTransitionToCompatibility planned
  pure
    PrReviewMergeabilityIndexedProjection
      { prReviewMergeabilityIndexedProjectionPlanned = projectedPlan
      , prReviewMergeabilityIndexedProjectionFinalState = finalState
      , prReviewMergeabilityIndexedProjectionSourceLabel =
          IndexedWorkflow.indexedWorkflowPlannedTransitionSourceLabel
            @PrReviewMergeabilityIndexedSpec
            planned
      , prReviewMergeabilityIndexedProjectionTargetLabel =
          IndexedWorkflow.indexedWorkflowPlannedTransitionTargetLabel
            @PrReviewMergeabilityIndexedSpec
            planned
      , prReviewMergeabilityIndexedProjectionEffectPlan =
          projectedPlan.plannedPreCommitEffects <> projectedPlan.plannedPostCommitEffects
      }
 where
  indexedState =
    PrReviewIndexedState state
      :: PrReviewIndexedState PrReviewIndexedWaitingForMergeability
  indexedObservation =
    PrReviewIndexedObservation
      "PrReview/WaitingMergeability"
      "PrReview/Merging"
      (DaemonPrReviewObservation (ObservedMergeabilityClean commit))
      :: PrReviewIndexedObservation PrReviewIndexedWaitingForMergeability PrReviewIndexedMerging

prReviewIndexedTransitionToCompatibility
  :: IndexedWorkflow.IndexedPlannedTransition PrReviewMergeabilityIndexedSpec source target
  -> PlannedTransition MoifoldSpec
prReviewIndexedTransitionToCompatibility transition =
  PlannedTransition
    { plannedEvent = event
    , plannedPreCommitEffects = preCommitEffects
    , plannedPostCommitEffects = postCommitEffects
    }
 where
  PrReviewIndexedEvent _sourceLabel _targetLabel event =
    IndexedWorkflow.indexedPlannedEvent transition
  PrReviewIndexedEffectPlan preCommitEffects =
    IndexedWorkflow.indexedPlannedPreCommitEffects transition
  PrReviewIndexedEffectPlan postCommitEffects =
    IndexedWorkflow.indexedPlannedPostCommitEffects transition
