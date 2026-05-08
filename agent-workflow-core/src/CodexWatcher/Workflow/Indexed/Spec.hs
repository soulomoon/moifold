{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilyDependencies #-}
{-# LANGUAGE TypeFamilies #-}

module CodexWatcher.Workflow.Indexed.Spec
  ( IndexedPlannedTransition (..)
  , IndexedWorkflowSpec (..)
  , SomeIndexedPlannedTransition (..)
  , SomeIndexedWorkflowEffect (..)
  , SomeIndexedWorkflowEffectPlan (..)
  , SomeIndexedWorkflowEvent (..)
  , SomeIndexedWorkflowObservation (..)
  , SomeIndexedWorkflowObservedTick (..)
  , SomeIndexedWorkflowReplayResult (..)
  , SomeIndexedWorkflowState (..)
  , WorkflowSpecIndexedBridge (..)
  , indexedWorkflowEffectPlanEffectLabels
  , indexedWorkflowPlanObservation
  , indexedWorkflowPlannedTransitionEventLabel
  , indexedWorkflowPlannedTransitionPostCommitEffectLabels
  , indexedWorkflowPlannedTransitionPreCommitEffectLabels
  , indexedWorkflowPlannedTransitionSourceLabel
  , indexedWorkflowPlannedTransitionTargetLabel
  , someIndexedWorkflowEffectLabel
  , someIndexedWorkflowEffectPlanEffectLabels
  , someIndexedWorkflowEventLabel
  , someIndexedWorkflowEventSourceLabel
  , someIndexedWorkflowEventTargetLabel
  , someIndexedWorkflowObservationLabel
  , someIndexedWorkflowObservationSourceLabel
  , someIndexedWorkflowObservationTargetLabel
  , someIndexedWorkflowObservedTickStateLabel
  , someIndexedWorkflowObservedTickTransitionLabel
  , someIndexedWorkflowReplayStateLabel
  , someIndexedWorkflowStateLabel
  , someIndexedWorkflowTransitionEventLabel
  , someIndexedWorkflowTransitionPostCommitEffectLabels
  , someIndexedWorkflowTransitionPreCommitEffectLabels
  , someIndexedWorkflowTransitionSourceLabel
  , someIndexedWorkflowTransitionTargetLabel
  , withSomeIndexedPlannedTransition
  , withSomeIndexedWorkflowEffect
  , withSomeIndexedWorkflowEffectPlan
  , withSomeIndexedWorkflowEvent
  , withSomeIndexedWorkflowObservation
  , withSomeIndexedWorkflowObservedTick
  , withSomeIndexedWorkflowReplayResult
  , withSomeIndexedWorkflowState
  , workflowSpecBridgeApplyEvent
  , workflowSpecBridgeEffectAllowed
  , workflowSpecBridgeEffectLabel
  , workflowSpecBridgeEffectPlanEffects
  , workflowSpecBridgeInitialEvent
  , workflowSpecBridgeIsTerminal
  , workflowSpecBridgeObservationLabel
  , workflowSpecBridgeObserve
  , workflowSpecBridgeObservedState
  , workflowSpecBridgeObservedTransition
  , workflowSpecBridgePlanTransition
  , workflowSpecBridgeReplayEvents
  , workflowSpecBridgeReplayState
  , workflowSpecBridgeStateLabel
  , workflowSpecBridgeEventLabel
  , workflowSpecBridgeValidateEffects
  , WorkflowIndex
  ) where

import CodexWatcher.Workflow.Spec (PlannedTransition (..), WorkflowSpec (..))
import Data.Kind (Type)
import Data.Text (Text)

type family WorkflowIndex spec :: Type

data IndexedPlannedTransition spec source target where
  IndexedPlannedTransition
    :: { indexedPlannedEvent :: IndexedWorkflowEvent spec source target
       , indexedPlannedPreCommitEffects :: IndexedWorkflowEffectPlan spec source target
       , indexedPlannedPostCommitEffects :: IndexedWorkflowEffectPlan spec source target
       }
    -> IndexedPlannedTransition spec source target

class IndexedWorkflowSpec spec where
  type IndexedWorkflowState spec state = stateValue | stateValue -> spec state
  type IndexedWorkflowEvent spec source target = eventValue | eventValue -> spec source target
  type IndexedWorkflowObservation spec source target = observationValue | observationValue -> spec source target
  type IndexedWorkflowObservedTick spec source target = observedTickValue | observedTickValue -> spec source target
  type IndexedWorkflowEffect spec source target = effectValue | effectValue -> spec source target
  type IndexedWorkflowEffectPlan spec source target = effectPlanValue | effectPlanValue -> spec source target
  type IndexedWorkflowReplayResult spec state = replayValue | replayValue -> spec state
  type IndexedWorkflowError spec

  indexedWorkflowInitialEvent
    :: forall source target.
       IndexedWorkflowEvent spec source target
    -> Either (IndexedWorkflowError spec) (IndexedWorkflowState spec target, IndexedWorkflowEffectPlan spec source target)

  indexedWorkflowApplyEvent
    :: forall source target.
       IndexedWorkflowState spec source
    -> IndexedWorkflowEvent spec source target
    -> Either (IndexedWorkflowError spec) (IndexedWorkflowState spec target, IndexedWorkflowEffectPlan spec source target)

  indexedWorkflowObserve
    :: forall source target.
       IndexedWorkflowState spec source
    -> IndexedWorkflowObservation spec source target
    -> Either (IndexedWorkflowError spec) (IndexedWorkflowObservedTick spec source target)

  indexedWorkflowObservedTransition
    :: forall source target.
       IndexedWorkflowObservedTick spec source target
    -> IndexedPlannedTransition spec source target

  indexedWorkflowObservedState
    :: forall source target.
       IndexedWorkflowObservedTick spec source target
    -> IndexedWorkflowState spec target

  indexedWorkflowPlanTransition
    :: forall source target.
       IndexedWorkflowEvent spec source target
    -> IndexedWorkflowEffectPlan spec source target
    -> IndexedPlannedTransition spec source target

  indexedWorkflowReplayEvents
    :: [SomeIndexedWorkflowEvent spec]
    -> Either (IndexedWorkflowError spec) (SomeIndexedWorkflowReplayResult spec)

  indexedWorkflowReplayState
    :: forall state.
       IndexedWorkflowReplayResult spec state
    -> IndexedWorkflowState spec state

  indexedWorkflowValidateEffects
    :: forall source target.
       IndexedWorkflowState spec source
    -> IndexedWorkflowEffectPlan spec source target
    -> Either (IndexedWorkflowError spec) ()

  indexedWorkflowEffectPlanEffects
    :: forall source target.
       IndexedWorkflowEffectPlan spec source target
    -> [IndexedWorkflowEffect spec source target]

  indexedWorkflowEffectAllowed
    :: forall source target.
       IndexedWorkflowState spec source
    -> IndexedWorkflowEffect spec source target
    -> Either Text ()

  indexedWorkflowIsTerminal
    :: forall state.
       IndexedWorkflowState spec state
    -> Bool

  indexedWorkflowStateLabel
    :: forall state.
       IndexedWorkflowState spec state
    -> Text

  indexedWorkflowEventLabel
    :: forall source target.
       IndexedWorkflowEvent spec source target
    -> Text

  indexedWorkflowEventSourceLabel
    :: forall source target.
       IndexedWorkflowEvent spec source target
    -> Text

  indexedWorkflowEventTargetLabel
    :: forall source target.
       IndexedWorkflowEvent spec source target
    -> Text

  indexedWorkflowObservationLabel
    :: forall source target.
       IndexedWorkflowObservation spec source target
    -> Text

  indexedWorkflowObservationSourceLabel
    :: forall source target.
       IndexedWorkflowObservation spec source target
    -> Text

  indexedWorkflowObservationTargetLabel
    :: forall source target.
       IndexedWorkflowObservation spec source target
    -> Text

  indexedWorkflowEffectLabel
    :: forall source target.
       IndexedWorkflowEffect spec source target
    -> Text

data SomeIndexedWorkflowState spec where
  SomeIndexedWorkflowState :: IndexedWorkflowState spec state -> SomeIndexedWorkflowState spec

data SomeIndexedWorkflowEvent spec where
  SomeIndexedWorkflowEvent :: IndexedWorkflowEvent spec source target -> SomeIndexedWorkflowEvent spec

data SomeIndexedWorkflowObservation spec where
  SomeIndexedWorkflowObservation :: IndexedWorkflowObservation spec source target -> SomeIndexedWorkflowObservation spec

data SomeIndexedWorkflowEffect spec where
  SomeIndexedWorkflowEffect :: IndexedWorkflowEffect spec source target -> SomeIndexedWorkflowEffect spec

data SomeIndexedWorkflowEffectPlan spec where
  SomeIndexedWorkflowEffectPlan :: IndexedWorkflowEffectPlan spec source target -> SomeIndexedWorkflowEffectPlan spec

data SomeIndexedPlannedTransition spec where
  SomeIndexedPlannedTransition :: IndexedPlannedTransition spec source target -> SomeIndexedPlannedTransition spec

data SomeIndexedWorkflowObservedTick spec where
  SomeIndexedWorkflowObservedTick :: IndexedWorkflowObservedTick spec source target -> SomeIndexedWorkflowObservedTick spec

data SomeIndexedWorkflowReplayResult spec where
  SomeIndexedWorkflowReplayResult :: IndexedWorkflowReplayResult spec state -> SomeIndexedWorkflowReplayResult spec

data WorkflowSpecIndexedBridge workflow indexed where
  WorkflowSpecIndexedBridge
    :: ( WorkflowSpec workflow
       , IndexedWorkflowSpec indexed
       , IndexedWorkflowError indexed ~ WorkflowError workflow
       )
    => { workflowSpecBridgeWrapState :: forall state. WorkflowState workflow -> IndexedWorkflowState indexed state
       , workflowSpecBridgeUnwrapState :: forall state. IndexedWorkflowState indexed state -> WorkflowState workflow
       , workflowSpecBridgeWrapEvent :: forall source target. Text -> Text -> WorkflowEvent workflow -> IndexedWorkflowEvent indexed source target
       , workflowSpecBridgeUnwrapEvent :: forall source target. IndexedWorkflowEvent indexed source target -> WorkflowEvent workflow
       , workflowSpecBridgeWrapObservation :: forall source target. Text -> Text -> WorkflowObservation workflow -> IndexedWorkflowObservation indexed source target
       , workflowSpecBridgeUnwrapObservation :: forall source target. IndexedWorkflowObservation indexed source target -> WorkflowObservation workflow
       , workflowSpecBridgeWrapObservedTick :: forall source target. Text -> Text -> WorkflowObservedTick workflow -> IndexedWorkflowObservedTick indexed source target
       , workflowSpecBridgeUnwrapObservedTick :: forall source target. IndexedWorkflowObservedTick indexed source target -> WorkflowObservedTick workflow
       , workflowSpecBridgeWrapEffect :: forall source target. WorkflowEffect workflow -> IndexedWorkflowEffect indexed source target
       , workflowSpecBridgeUnwrapEffect :: forall source target. IndexedWorkflowEffect indexed source target -> WorkflowEffect workflow
       , workflowSpecBridgeWrapEffectPlan :: forall source target. WorkflowEffectPlan workflow -> IndexedWorkflowEffectPlan indexed source target
       , workflowSpecBridgeUnwrapEffectPlan :: forall source target. IndexedWorkflowEffectPlan indexed source target -> WorkflowEffectPlan workflow
       , workflowSpecBridgeWrapReplayResult :: WorkflowReplayResult workflow -> SomeIndexedWorkflowReplayResult indexed
       , workflowSpecBridgeUnwrapReplayResult :: forall state. IndexedWorkflowReplayResult indexed state -> WorkflowReplayResult workflow
       , workflowSpecBridgeEventSourceLabel :: forall source target. IndexedWorkflowEvent indexed source target -> Text
       , workflowSpecBridgeEventTargetLabel :: forall source target. IndexedWorkflowEvent indexed source target -> Text
       , workflowSpecBridgeObservationSourceLabel :: forall source target. IndexedWorkflowObservation indexed source target -> Text
       , workflowSpecBridgeObservationTargetLabel :: forall source target. IndexedWorkflowObservation indexed source target -> Text
       , workflowSpecBridgeObservedTickSourceLabel :: forall source target. IndexedWorkflowObservedTick indexed source target -> Text
       , workflowSpecBridgeObservedTickTargetLabel :: forall source target. IndexedWorkflowObservedTick indexed source target -> Text
       }
    -> WorkflowSpecIndexedBridge workflow indexed

workflowSpecBridgeInitialEvent
  :: forall workflow indexed source target.
     WorkflowSpecIndexedBridge workflow indexed
  -> IndexedWorkflowEvent indexed source target
  -> Either (IndexedWorkflowError indexed) (IndexedWorkflowState indexed target, IndexedWorkflowEffectPlan indexed source target)
workflowSpecBridgeInitialEvent bridge@WorkflowSpecIndexedBridge {} event =
  case workflowInitialEvent @workflow (workflowSpecBridgeUnwrapEvent bridge event) of
    Right (state, effects) ->
      Right (workflowSpecBridgeWrapState bridge state, workflowSpecBridgeWrapEffectPlan bridge effects)
    Left failure -> Left failure

workflowSpecBridgeApplyEvent
  :: forall workflow indexed source target.
     WorkflowSpecIndexedBridge workflow indexed
  -> IndexedWorkflowState indexed source
  -> IndexedWorkflowEvent indexed source target
  -> Either (IndexedWorkflowError indexed) (IndexedWorkflowState indexed target, IndexedWorkflowEffectPlan indexed source target)
workflowSpecBridgeApplyEvent bridge@WorkflowSpecIndexedBridge {} state event =
  case workflowApplyEvent @workflow (workflowSpecBridgeUnwrapState bridge state) (workflowSpecBridgeUnwrapEvent bridge event) of
    Right (nextState, effects) ->
      Right (workflowSpecBridgeWrapState bridge nextState, workflowSpecBridgeWrapEffectPlan bridge effects)
    Left failure -> Left failure

workflowSpecBridgeObserve
  :: forall workflow indexed source target.
     WorkflowSpecIndexedBridge workflow indexed
  -> IndexedWorkflowState indexed source
  -> IndexedWorkflowObservation indexed source target
  -> Either (IndexedWorkflowError indexed) (IndexedWorkflowObservedTick indexed source target)
workflowSpecBridgeObserve bridge@WorkflowSpecIndexedBridge {} state observation =
  case workflowObserve @workflow (workflowSpecBridgeUnwrapState bridge state) (workflowSpecBridgeUnwrapObservation bridge observation) of
    Right observed ->
      Right
        ( workflowSpecBridgeWrapObservedTick
            bridge
            (workflowSpecBridgeObservationSourceLabel bridge observation)
            (workflowSpecBridgeObservationTargetLabel bridge observation)
            observed
        )
    Left failure -> Left failure

workflowSpecBridgeObservedTransition
  :: forall workflow indexed source target.
     WorkflowSpecIndexedBridge workflow indexed
  -> IndexedWorkflowObservedTick indexed source target
  -> IndexedPlannedTransition indexed source target
workflowSpecBridgeObservedTransition bridge@WorkflowSpecIndexedBridge {} observed =
  workflowSpecBridgePlannedTransition
    bridge
    (workflowSpecBridgeObservedTickSourceLabel bridge observed)
    (workflowSpecBridgeObservedTickTargetLabel bridge observed)
    (workflowObservedTransition @workflow (workflowSpecBridgeUnwrapObservedTick bridge observed))

workflowSpecBridgeObservedState
  :: forall workflow indexed source target.
     WorkflowSpecIndexedBridge workflow indexed
  -> IndexedWorkflowObservedTick indexed source target
  -> IndexedWorkflowState indexed target
workflowSpecBridgeObservedState bridge@WorkflowSpecIndexedBridge {} observed =
  workflowSpecBridgeWrapState bridge (workflowObservedState @workflow (workflowSpecBridgeUnwrapObservedTick bridge observed))

workflowSpecBridgePlanTransition
  :: forall workflow indexed source target.
     WorkflowSpecIndexedBridge workflow indexed
  -> IndexedWorkflowEvent indexed source target
  -> IndexedWorkflowEffectPlan indexed source target
  -> IndexedPlannedTransition indexed source target
workflowSpecBridgePlanTransition bridge@WorkflowSpecIndexedBridge {} event effects =
  workflowSpecBridgePlannedTransition
    bridge
    (workflowSpecBridgeEventSourceLabel bridge event)
    (workflowSpecBridgeEventTargetLabel bridge event)
    (workflowPlanTransition @workflow (workflowSpecBridgeUnwrapEvent bridge event) (workflowSpecBridgeUnwrapEffectPlan bridge effects))

workflowSpecBridgeReplayEvents
  :: forall workflow indexed.
     WorkflowSpecIndexedBridge workflow indexed
  -> [SomeIndexedWorkflowEvent indexed]
  -> Either (IndexedWorkflowError indexed) (SomeIndexedWorkflowReplayResult indexed)
workflowSpecBridgeReplayEvents bridge@WorkflowSpecIndexedBridge {} events =
  case workflowReplayEvents @workflow (workflowSpecBridgeSomeEvents bridge events) of
    Right replay -> Right (workflowSpecBridgeWrapReplayResult bridge replay)
    Left failure -> Left failure

workflowSpecBridgeReplayState
  :: forall workflow indexed state.
     WorkflowSpecIndexedBridge workflow indexed
  -> IndexedWorkflowReplayResult indexed state
  -> IndexedWorkflowState indexed state
workflowSpecBridgeReplayState bridge@WorkflowSpecIndexedBridge {} replay =
  workflowSpecBridgeWrapState bridge (workflowReplayState @workflow (workflowSpecBridgeUnwrapReplayResult bridge replay))

workflowSpecBridgeValidateEffects
  :: forall workflow indexed source target.
     WorkflowSpecIndexedBridge workflow indexed
  -> IndexedWorkflowState indexed source
  -> IndexedWorkflowEffectPlan indexed source target
  -> Either (IndexedWorkflowError indexed) ()
workflowSpecBridgeValidateEffects bridge@WorkflowSpecIndexedBridge {} state effects =
  workflowValidateEffects @workflow (workflowSpecBridgeUnwrapState bridge state) (workflowSpecBridgeUnwrapEffectPlan bridge effects)

workflowSpecBridgeEffectPlanEffects
  :: forall workflow indexed source target.
     WorkflowSpecIndexedBridge workflow indexed
  -> IndexedWorkflowEffectPlan indexed source target
  -> [IndexedWorkflowEffect indexed source target]
workflowSpecBridgeEffectPlanEffects bridge@WorkflowSpecIndexedBridge {} effects =
  workflowSpecBridgeWrapEffect bridge <$> workflowEffectPlanEffects @workflow (workflowSpecBridgeUnwrapEffectPlan bridge effects)

workflowSpecBridgeEffectAllowed
  :: forall workflow indexed source target.
     WorkflowSpecIndexedBridge workflow indexed
  -> IndexedWorkflowState indexed source
  -> IndexedWorkflowEffect indexed source target
  -> Either Text ()
workflowSpecBridgeEffectAllowed bridge@WorkflowSpecIndexedBridge {} state effect =
  workflowEffectAllowed @workflow (workflowSpecBridgeUnwrapState bridge state) (workflowSpecBridgeUnwrapEffect bridge effect)

workflowSpecBridgeIsTerminal
  :: forall workflow indexed state.
     WorkflowSpecIndexedBridge workflow indexed
  -> IndexedWorkflowState indexed state
  -> Bool
workflowSpecBridgeIsTerminal bridge@WorkflowSpecIndexedBridge {} state =
  workflowIsTerminal @workflow (workflowSpecBridgeUnwrapState bridge state)

workflowSpecBridgeStateLabel
  :: forall workflow indexed state.
     WorkflowSpecIndexedBridge workflow indexed
  -> IndexedWorkflowState indexed state
  -> Text
workflowSpecBridgeStateLabel bridge@WorkflowSpecIndexedBridge {} state =
  workflowStateLabel @workflow (workflowSpecBridgeUnwrapState bridge state)

workflowSpecBridgeEventLabel
  :: forall workflow indexed source target.
     WorkflowSpecIndexedBridge workflow indexed
  -> IndexedWorkflowEvent indexed source target
  -> Text
workflowSpecBridgeEventLabel bridge@WorkflowSpecIndexedBridge {} event =
  workflowEventLabel @workflow (workflowSpecBridgeUnwrapEvent bridge event)

workflowSpecBridgeObservationLabel
  :: forall workflow indexed source target.
     WorkflowSpecIndexedBridge workflow indexed
  -> IndexedWorkflowObservation indexed source target
  -> Text
workflowSpecBridgeObservationLabel bridge@WorkflowSpecIndexedBridge {} observation =
  workflowObservationLabel @workflow (workflowSpecBridgeUnwrapObservation bridge observation)

workflowSpecBridgeEffectLabel
  :: forall workflow indexed source target.
     WorkflowSpecIndexedBridge workflow indexed
  -> IndexedWorkflowEffect indexed source target
  -> Text
workflowSpecBridgeEffectLabel bridge@WorkflowSpecIndexedBridge {} effect =
  workflowEffectLabel @workflow (workflowSpecBridgeUnwrapEffect bridge effect)

workflowSpecBridgePlannedTransition
  :: forall workflow indexed source target.
     WorkflowSpecIndexedBridge workflow indexed
  -> Text
  -> Text
  -> PlannedTransition workflow
  -> IndexedPlannedTransition indexed source target
workflowSpecBridgePlannedTransition bridge@WorkflowSpecIndexedBridge {} sourceLabel targetLabel planned =
  IndexedPlannedTransition
    { indexedPlannedEvent = workflowSpecBridgeWrapEvent bridge sourceLabel targetLabel (plannedEvent planned)
    , indexedPlannedPreCommitEffects = workflowSpecBridgeWrapEffectPlan bridge (plannedPreCommitEffects planned)
    , indexedPlannedPostCommitEffects = workflowSpecBridgeWrapEffectPlan bridge (plannedPostCommitEffects planned)
    }

workflowSpecBridgeSomeEvents
  :: forall workflow indexed.
     WorkflowSpecIndexedBridge workflow indexed
  -> [SomeIndexedWorkflowEvent indexed]
  -> [WorkflowEvent workflow]
workflowSpecBridgeSomeEvents bridge@WorkflowSpecIndexedBridge {} =
  fmap $ \(SomeIndexedWorkflowEvent event) -> workflowSpecBridgeUnwrapEvent bridge event

indexedWorkflowPlanObservation
  :: forall spec source target. IndexedWorkflowSpec spec
  => IndexedWorkflowState spec source
  -> IndexedWorkflowObservation spec source target
  -> Either (IndexedWorkflowError spec) (IndexedPlannedTransition spec source target)
indexedWorkflowPlanObservation state observation =
  indexedWorkflowObservedTransition @spec <$> indexedWorkflowObserve @spec state observation

indexedWorkflowEffectPlanEffectLabels
  :: forall spec source target. IndexedWorkflowSpec spec
  => IndexedWorkflowEffectPlan spec source target
  -> [Text]
indexedWorkflowEffectPlanEffectLabels plan =
  indexedWorkflowEffectLabel @spec <$> indexedWorkflowEffectPlanEffects @spec plan

indexedWorkflowPlannedTransitionEventLabel
  :: forall spec source target. IndexedWorkflowSpec spec
  => IndexedPlannedTransition spec source target
  -> Text
indexedWorkflowPlannedTransitionEventLabel transition =
  indexedWorkflowEventLabel @spec (indexedPlannedEvent transition)

indexedWorkflowPlannedTransitionSourceLabel
  :: forall spec source target. IndexedWorkflowSpec spec
  => IndexedPlannedTransition spec source target
  -> Text
indexedWorkflowPlannedTransitionSourceLabel transition =
  indexedWorkflowEventSourceLabel @spec (indexedPlannedEvent transition)

indexedWorkflowPlannedTransitionTargetLabel
  :: forall spec source target. IndexedWorkflowSpec spec
  => IndexedPlannedTransition spec source target
  -> Text
indexedWorkflowPlannedTransitionTargetLabel transition =
  indexedWorkflowEventTargetLabel @spec (indexedPlannedEvent transition)

indexedWorkflowPlannedTransitionPreCommitEffectLabels
  :: forall spec source target. IndexedWorkflowSpec spec
  => IndexedPlannedTransition spec source target
  -> [Text]
indexedWorkflowPlannedTransitionPreCommitEffectLabels transition =
  indexedWorkflowEffectPlanEffectLabels @spec (indexedPlannedPreCommitEffects transition)

indexedWorkflowPlannedTransitionPostCommitEffectLabels
  :: forall spec source target. IndexedWorkflowSpec spec
  => IndexedPlannedTransition spec source target
  -> [Text]
indexedWorkflowPlannedTransitionPostCommitEffectLabels transition =
  indexedWorkflowEffectPlanEffectLabels @spec (indexedPlannedPostCommitEffects transition)

someIndexedWorkflowStateLabel :: forall spec. IndexedWorkflowSpec spec => SomeIndexedWorkflowState spec -> Text
someIndexedWorkflowStateLabel (SomeIndexedWorkflowState state) =
  indexedWorkflowStateLabel @spec state

someIndexedWorkflowEventLabel :: forall spec. IndexedWorkflowSpec spec => SomeIndexedWorkflowEvent spec -> Text
someIndexedWorkflowEventLabel (SomeIndexedWorkflowEvent event) =
  indexedWorkflowEventLabel @spec event

someIndexedWorkflowEventSourceLabel :: forall spec. IndexedWorkflowSpec spec => SomeIndexedWorkflowEvent spec -> Text
someIndexedWorkflowEventSourceLabel (SomeIndexedWorkflowEvent event) =
  indexedWorkflowEventSourceLabel @spec event

someIndexedWorkflowEventTargetLabel :: forall spec. IndexedWorkflowSpec spec => SomeIndexedWorkflowEvent spec -> Text
someIndexedWorkflowEventTargetLabel (SomeIndexedWorkflowEvent event) =
  indexedWorkflowEventTargetLabel @spec event

someIndexedWorkflowObservationLabel :: forall spec. IndexedWorkflowSpec spec => SomeIndexedWorkflowObservation spec -> Text
someIndexedWorkflowObservationLabel (SomeIndexedWorkflowObservation observation) =
  indexedWorkflowObservationLabel @spec observation

someIndexedWorkflowObservationSourceLabel :: forall spec. IndexedWorkflowSpec spec => SomeIndexedWorkflowObservation spec -> Text
someIndexedWorkflowObservationSourceLabel (SomeIndexedWorkflowObservation observation) =
  indexedWorkflowObservationSourceLabel @spec observation

someIndexedWorkflowObservationTargetLabel :: forall spec. IndexedWorkflowSpec spec => SomeIndexedWorkflowObservation spec -> Text
someIndexedWorkflowObservationTargetLabel (SomeIndexedWorkflowObservation observation) =
  indexedWorkflowObservationTargetLabel @spec observation

someIndexedWorkflowEffectLabel :: forall spec. IndexedWorkflowSpec spec => SomeIndexedWorkflowEffect spec -> Text
someIndexedWorkflowEffectLabel (SomeIndexedWorkflowEffect effect) =
  indexedWorkflowEffectLabel @spec effect

someIndexedWorkflowEffectPlanEffectLabels :: forall spec. IndexedWorkflowSpec spec => SomeIndexedWorkflowEffectPlan spec -> [Text]
someIndexedWorkflowEffectPlanEffectLabels (SomeIndexedWorkflowEffectPlan plan) =
  indexedWorkflowEffectPlanEffectLabels @spec plan

someIndexedWorkflowTransitionEventLabel :: forall spec. IndexedWorkflowSpec spec => SomeIndexedPlannedTransition spec -> Text
someIndexedWorkflowTransitionEventLabel (SomeIndexedPlannedTransition transition) =
  indexedWorkflowPlannedTransitionEventLabel @spec transition

someIndexedWorkflowTransitionSourceLabel :: forall spec. IndexedWorkflowSpec spec => SomeIndexedPlannedTransition spec -> Text
someIndexedWorkflowTransitionSourceLabel (SomeIndexedPlannedTransition transition) =
  indexedWorkflowPlannedTransitionSourceLabel @spec transition

someIndexedWorkflowTransitionTargetLabel :: forall spec. IndexedWorkflowSpec spec => SomeIndexedPlannedTransition spec -> Text
someIndexedWorkflowTransitionTargetLabel (SomeIndexedPlannedTransition transition) =
  indexedWorkflowPlannedTransitionTargetLabel @spec transition

someIndexedWorkflowTransitionPreCommitEffectLabels :: forall spec. IndexedWorkflowSpec spec => SomeIndexedPlannedTransition spec -> [Text]
someIndexedWorkflowTransitionPreCommitEffectLabels (SomeIndexedPlannedTransition transition) =
  indexedWorkflowPlannedTransitionPreCommitEffectLabels @spec transition

someIndexedWorkflowTransitionPostCommitEffectLabels :: forall spec. IndexedWorkflowSpec spec => SomeIndexedPlannedTransition spec -> [Text]
someIndexedWorkflowTransitionPostCommitEffectLabels (SomeIndexedPlannedTransition transition) =
  indexedWorkflowPlannedTransitionPostCommitEffectLabels @spec transition

someIndexedWorkflowObservedTickStateLabel :: forall spec. IndexedWorkflowSpec spec => SomeIndexedWorkflowObservedTick spec -> Text
someIndexedWorkflowObservedTickStateLabel (SomeIndexedWorkflowObservedTick observedTick) =
  indexedWorkflowStateLabel @spec (indexedWorkflowObservedState @spec observedTick)

someIndexedWorkflowObservedTickTransitionLabel :: forall spec. IndexedWorkflowSpec spec => SomeIndexedWorkflowObservedTick spec -> Text
someIndexedWorkflowObservedTickTransitionLabel (SomeIndexedWorkflowObservedTick observedTick) =
  indexedWorkflowPlannedTransitionEventLabel @spec (indexedWorkflowObservedTransition @spec observedTick)

someIndexedWorkflowReplayStateLabel :: forall spec. IndexedWorkflowSpec spec => SomeIndexedWorkflowReplayResult spec -> Text
someIndexedWorkflowReplayStateLabel (SomeIndexedWorkflowReplayResult replayResult) =
  indexedWorkflowStateLabel @spec (indexedWorkflowReplayState @spec replayResult)

withSomeIndexedWorkflowState
  :: SomeIndexedWorkflowState spec
  -> (forall state. IndexedWorkflowState spec state -> result)
  -> result
withSomeIndexedWorkflowState (SomeIndexedWorkflowState state) consume =
  consume state

withSomeIndexedWorkflowEvent
  :: SomeIndexedWorkflowEvent spec
  -> (forall source target. IndexedWorkflowEvent spec source target -> result)
  -> result
withSomeIndexedWorkflowEvent (SomeIndexedWorkflowEvent event) consume =
  consume event

withSomeIndexedWorkflowObservation
  :: SomeIndexedWorkflowObservation spec
  -> (forall source target. IndexedWorkflowObservation spec source target -> result)
  -> result
withSomeIndexedWorkflowObservation (SomeIndexedWorkflowObservation observation) consume =
  consume observation

withSomeIndexedWorkflowEffect
  :: SomeIndexedWorkflowEffect spec
  -> (forall source target. IndexedWorkflowEffect spec source target -> result)
  -> result
withSomeIndexedWorkflowEffect (SomeIndexedWorkflowEffect effect) consume =
  consume effect

withSomeIndexedWorkflowEffectPlan
  :: SomeIndexedWorkflowEffectPlan spec
  -> (forall source target. IndexedWorkflowEffectPlan spec source target -> result)
  -> result
withSomeIndexedWorkflowEffectPlan (SomeIndexedWorkflowEffectPlan plan) consume =
  consume plan

withSomeIndexedPlannedTransition
  :: SomeIndexedPlannedTransition spec
  -> (forall source target. IndexedPlannedTransition spec source target -> result)
  -> result
withSomeIndexedPlannedTransition (SomeIndexedPlannedTransition transition) consume =
  consume transition

withSomeIndexedWorkflowObservedTick
  :: SomeIndexedWorkflowObservedTick spec
  -> (forall source target. IndexedWorkflowObservedTick spec source target -> result)
  -> result
withSomeIndexedWorkflowObservedTick (SomeIndexedWorkflowObservedTick observedTick) consume =
  consume observedTick

withSomeIndexedWorkflowReplayResult
  :: SomeIndexedWorkflowReplayResult spec
  -> (forall state. IndexedWorkflowReplayResult spec state -> result)
  -> result
withSomeIndexedWorkflowReplayResult (SomeIndexedWorkflowReplayResult replayResult) consume =
  consume replayResult
