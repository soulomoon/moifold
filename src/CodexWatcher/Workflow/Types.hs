{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeFamilies #-}

module CodexWatcher.Workflow.Types
  ( MoifoldSpec
  , PlannedTransition (..)
  , WorkflowSpec (..)
  , legacyObservedPlannedTransition
  , moifoldEventLabel
  , moifoldStateLabel
  ) where

import CodexWatcher.Effects (EffectPlan, SomeEffect)
import CodexWatcher.EventLog.Replay (applyEvent, initializeFromEvent, replayEventLog)
import CodexWatcher.EventLog.Types (EventReplayResult, ReplayFailure (..), WatcherEvent, eventName)
import CodexWatcher.Core.State (SomeWatcherState, isTerminalState, someDomain, somePhase)
import CodexWatcher.StateMachine (formatPhaseActionValidationError, validatePhaseActionPlan)
import CodexWatcher.Workflow.Observation (DaemonObservation, ObservedPolicyTick (..), observeDaemonState)
import Data.Text (Text)
import Data.Text qualified as Text

data MoifoldSpec

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

  workflowReplayEvents
    :: [WorkflowEvent spec]
    -> Either (WorkflowError spec) (WorkflowReplayResult spec)

  workflowValidateEffects
    :: WorkflowState spec
    -> WorkflowEffectPlan spec
    -> Either (WorkflowError spec) ()

  workflowIsTerminal
    :: WorkflowState spec
    -> Bool

  workflowStateLabel
    :: WorkflowState spec
    -> Text

  workflowEventLabel
    :: WorkflowEvent spec
    -> Text

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
  workflowReplayEvents events =
    case replayEventLog events of
      Left failure -> Left (formatReplayFailure failure)
      Right result -> Right result
  workflowValidateEffects state effects =
    case validatePhaseActionPlan state effects of
      Left failure -> Left (formatPhaseActionValidationError failure)
      Right () -> Right ()
  workflowIsTerminal = isTerminalState
  workflowStateLabel = moifoldStateLabel
  workflowEventLabel = moifoldEventLabel

legacyObservedPlannedTransition :: ObservedPolicyTick -> PlannedTransition MoifoldSpec
legacyObservedPlannedTransition observed =
  PlannedTransition
    { plannedEvent = observed.observedEvent
    , plannedPreCommitEffects = observed.observedEffects
    , plannedPostCommitEffects = []
    }

moifoldStateLabel :: SomeWatcherState -> Text
moifoldStateLabel state =
  Text.pack (show (someDomain state)) <> "/" <> Text.pack (show (somePhase state))

moifoldEventLabel :: WatcherEvent -> Text
moifoldEventLabel =
  eventName

formatReplayFailure :: ReplayFailure -> Text
formatReplayFailure failure =
  "event "
    <> Text.pack (show failure.eventIndex)
    <> " ("
    <> eventName failure.event
    <> "): "
    <> failure.reason
