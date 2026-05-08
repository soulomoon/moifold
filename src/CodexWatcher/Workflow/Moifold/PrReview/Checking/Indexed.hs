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

  indexedWorkflowInitialEvent =
    IndexedWorkflow.workflowSpecBridgeInitialEvent prReviewCheckingIndexedBridge
  indexedWorkflowApplyEvent =
    IndexedWorkflow.workflowSpecBridgeApplyEvent prReviewCheckingIndexedBridge
  indexedWorkflowObserve =
    IndexedWorkflow.workflowSpecBridgeObserve prReviewCheckingIndexedBridge
  indexedWorkflowObservedTransition =
    IndexedWorkflow.workflowSpecBridgeObservedTransition prReviewCheckingIndexedBridge
  indexedWorkflowObservedState =
    IndexedWorkflow.workflowSpecBridgeObservedState prReviewCheckingIndexedBridge
  indexedWorkflowPlanTransition =
    IndexedWorkflow.workflowSpecBridgePlanTransition prReviewCheckingIndexedBridge
  indexedWorkflowReplayEvents =
    IndexedWorkflow.workflowSpecBridgeReplayEvents prReviewCheckingIndexedBridge
  indexedWorkflowReplayState =
    IndexedWorkflow.workflowSpecBridgeReplayState prReviewCheckingIndexedBridge
  indexedWorkflowValidateEffects =
    IndexedWorkflow.workflowSpecBridgeValidateEffects prReviewCheckingIndexedBridge
  indexedWorkflowEffectPlanEffects =
    IndexedWorkflow.workflowSpecBridgeEffectPlanEffects prReviewCheckingIndexedBridge
  indexedWorkflowEffectAllowed =
    IndexedWorkflow.workflowSpecBridgeEffectAllowed prReviewCheckingIndexedBridge
  indexedWorkflowIsTerminal =
    IndexedWorkflow.workflowSpecBridgeIsTerminal prReviewCheckingIndexedBridge
  indexedWorkflowStateLabel =
    IndexedWorkflow.workflowSpecBridgeStateLabel prReviewCheckingIndexedBridge
  indexedWorkflowEventLabel =
    IndexedWorkflow.workflowSpecBridgeEventLabel prReviewCheckingIndexedBridge
  indexedWorkflowEventSourceLabel =
    IndexedWorkflow.workflowSpecBridgeEventSourceLabel prReviewCheckingIndexedBridge
  indexedWorkflowEventTargetLabel =
    IndexedWorkflow.workflowSpecBridgeEventTargetLabel prReviewCheckingIndexedBridge
  indexedWorkflowObservationLabel =
    IndexedWorkflow.workflowSpecBridgeObservationLabel prReviewCheckingIndexedBridge
  indexedWorkflowObservationSourceLabel =
    IndexedWorkflow.workflowSpecBridgeObservationSourceLabel prReviewCheckingIndexedBridge
  indexedWorkflowObservationTargetLabel =
    IndexedWorkflow.workflowSpecBridgeObservationTargetLabel prReviewCheckingIndexedBridge
  indexedWorkflowEffectLabel =
    IndexedWorkflow.workflowSpecBridgeEffectLabel prReviewCheckingIndexedBridge

prReviewCheckingIndexedBridge :: IndexedWorkflow.WorkflowSpecIndexedBridge MoifoldSpec PrReviewCheckingIndexedSpec
prReviewCheckingIndexedBridge =
  IndexedWorkflow.WorkflowSpecIndexedBridge
    { IndexedWorkflow.workflowSpecBridgeWrapState = PrReviewCheckingIndexedState
    , IndexedWorkflow.workflowSpecBridgeUnwrapState = \(PrReviewCheckingIndexedState state) -> state
    , IndexedWorkflow.workflowSpecBridgeWrapEvent = PrReviewCheckingIndexedEvent
    , IndexedWorkflow.workflowSpecBridgeUnwrapEvent = \(PrReviewCheckingIndexedEvent _sourceLabel _targetLabel event) -> event
    , IndexedWorkflow.workflowSpecBridgeWrapObservation = PrReviewCheckingIndexedObservation
    , IndexedWorkflow.workflowSpecBridgeUnwrapObservation = \(PrReviewCheckingIndexedObservation _sourceLabel _targetLabel observation) -> observation
    , IndexedWorkflow.workflowSpecBridgeWrapObservedTick = PrReviewCheckingIndexedTick
    , IndexedWorkflow.workflowSpecBridgeUnwrapObservedTick = \(PrReviewCheckingIndexedTick _sourceLabel _targetLabel tick) -> tick
    , IndexedWorkflow.workflowSpecBridgeWrapEffect = PrReviewCheckingIndexedEffect
    , IndexedWorkflow.workflowSpecBridgeUnwrapEffect = \(PrReviewCheckingIndexedEffect effect) -> effect
    , IndexedWorkflow.workflowSpecBridgeWrapEffectPlan = PrReviewCheckingIndexedEffectPlan
    , IndexedWorkflow.workflowSpecBridgeUnwrapEffectPlan = \(PrReviewCheckingIndexedEffectPlan effects) -> effects
    , IndexedWorkflow.workflowSpecBridgeWrapReplayResult =
        IndexedWorkflow.SomeIndexedWorkflowReplayResult . PrReviewCheckingIndexedReplayResult
    , IndexedWorkflow.workflowSpecBridgeUnwrapReplayResult = \(PrReviewCheckingIndexedReplayResult replay) -> replay
    , IndexedWorkflow.workflowSpecBridgeEventSourceLabel = \(PrReviewCheckingIndexedEvent sourceLabel _targetLabel _event) -> sourceLabel
    , IndexedWorkflow.workflowSpecBridgeEventTargetLabel = \(PrReviewCheckingIndexedEvent _sourceLabel targetLabel _event) -> targetLabel
    , IndexedWorkflow.workflowSpecBridgeObservationSourceLabel = \(PrReviewCheckingIndexedObservation sourceLabel _targetLabel _observation) -> sourceLabel
    , IndexedWorkflow.workflowSpecBridgeObservationTargetLabel = \(PrReviewCheckingIndexedObservation _sourceLabel targetLabel _observation) -> targetLabel
    , IndexedWorkflow.workflowSpecBridgeObservedTickSourceLabel = \(PrReviewCheckingIndexedTick sourceLabel _targetLabel _tick) -> sourceLabel
    , IndexedWorkflow.workflowSpecBridgeObservedTickTargetLabel = \(PrReviewCheckingIndexedTick _sourceLabel targetLabel _tick) -> targetLabel
    }
