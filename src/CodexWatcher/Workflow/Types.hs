{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeFamilies #-}

module CodexWatcher.Workflow.Types
  ( MoifoldSpec
  , legacyObservedPlannedTransition
  , moifoldEventLabel
  , moifoldObservationLabel
  , moifoldEffectLabel
  , moifoldPlannedTransitionFromEffects
  , moifoldStateLabel
  , module CodexWatcher.Workflow.Spec
  ) where

import CodexWatcher.Effects (EffectPlan, SomeEffect, SomeEffectAction (..), actionKindText, someEffectAction)
import CodexWatcher.EventLog.Replay (applyEvent, initializeFromEvent, replayEventLog)
import CodexWatcher.EventLog.Types (EventReplayResult (..), ReplayFailure (..), WatcherEvent, eventName)
import CodexWatcher.Core.State (SomeWatcherState, isTerminalState, someDomain, somePhase)
import CodexWatcher.StateMachine (formatPhaseActionValidationError, validatePhaseActionPlan)
import CodexWatcher.Workflow.Execution (partitionWorkflowEffectPlan)
import CodexWatcher.Workflow.Observation (DaemonObservation, ObservedPolicyTick (..), observeDaemonState)
import CodexWatcher.Workflow.Spec
import Data.Text (Text)
import Data.Text qualified as Text

data MoifoldSpec

instance WorkflowSpec MoifoldSpec where
  type WorkflowState MoifoldSpec = SomeWatcherState
  type WorkflowEvent MoifoldSpec = WatcherEvent
  type WorkflowObservation MoifoldSpec = DaemonObservation
  type WorkflowObservedTick MoifoldSpec = ObservedPolicyTick
  type WorkflowEffect MoifoldSpec = SomeEffect
  type WorkflowEffectPlan MoifoldSpec = EffectPlan
  type WorkflowReplayResult MoifoldSpec = EventReplayResult
  type WorkflowError MoifoldSpec = Text

  workflowInitialEvent = initializeFromEvent
  workflowApplyEvent = applyEvent
  workflowObserve = observeDaemonState
  workflowObservedTransition = legacyObservedPlannedTransition
  workflowObservedState = observedState
  workflowPlanTransition = moifoldPlannedTransitionFromEffects
  workflowReplayEvents events =
    case replayEventLog events of
      Left failure -> Left (formatReplayFailure failure)
      Right result -> Right result
  workflowReplayState = replayState
  workflowValidateEffects state effects =
    case validatePhaseActionPlan state effects of
      Left failure -> Left (formatPhaseActionValidationError failure)
      Right () -> Right ()
  workflowEffectPlanEffects = id
  workflowEffectAllowed state effect =
    case validatePhaseActionPlan state [effect] of
      Left failure -> Left (formatPhaseActionValidationError failure)
      Right () -> Right ()
  workflowIsTerminal = isTerminalState
  workflowStateLabel = moifoldStateLabel
  workflowEventLabel = moifoldEventLabel
  workflowObservationLabel = moifoldObservationLabel
  workflowEffectLabel = moifoldEffectLabel

legacyObservedPlannedTransition :: ObservedPolicyTick -> PlannedTransition MoifoldSpec
legacyObservedPlannedTransition observed =
  moifoldPlannedTransitionFromEffects observed.observedEvent observed.observedEffects

moifoldPlannedTransitionFromEffects :: WatcherEvent -> EffectPlan -> PlannedTransition MoifoldSpec
moifoldPlannedTransitionFromEffects event effects =
  let (preCommitEffects, postCommitEffects) = partitionWorkflowEffectPlan effects
   in PlannedTransition
        { plannedEvent = event
        , plannedPreCommitEffects = preCommitEffects
        , plannedPostCommitEffects = postCommitEffects
        }

moifoldStateLabel :: SomeWatcherState -> Text
moifoldStateLabel state =
  Text.pack (show (someDomain state)) <> "/" <> Text.pack (show (somePhase state))

moifoldEventLabel :: WatcherEvent -> Text
moifoldEventLabel =
  eventName

moifoldObservationLabel :: DaemonObservation -> Text
moifoldObservationLabel =
  Text.pack . show

moifoldEffectLabel :: SomeEffect -> Text
moifoldEffectLabel effect =
  case someEffectAction effect of
    SomeEffectAction action -> actionKindText action

formatReplayFailure :: ReplayFailure -> Text
formatReplayFailure failure =
  "event "
    <> Text.pack (show failure.eventIndex)
    <> " ("
    <> eventName failure.event
    <> "): "
    <> failure.reason
