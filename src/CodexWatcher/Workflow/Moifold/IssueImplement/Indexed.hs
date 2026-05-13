{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}

module CodexWatcher.Workflow.Moifold.IssueImplement.Indexed
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
  , issueImplementIndexedTransitionToCompatibility
  , projectIssueImplementAttemptBranchAdvancedObservation
  , projectIssueImplementBlockedHandoffInitializedObservation
  , projectIssueImplementBlockedHandoffReadyObservation
  , projectIssueImplementBlockedImplementationReadyObservation
  , projectIssueImplementBlockedImplementingObservation
  , projectIssueImplementBlockedInPlanModeObservation
  , projectIssueImplementBlockedPlanReadyObservation
  , projectIssueImplementBlockedPostMergeReviewPendingReviewerObservation
  , projectIssueImplementBlockedPostMergeReviewReadyObservation
  , projectIssueImplementBlockedPostMergeReviewingObservation
  , projectIssueImplementBlockedReadyToPlanObservation
  , projectIssueImplementBlockedWaitingForIssueCloseObservation
  , projectIssueImplementBlockedWaitingForPrMergeObservation
  , projectIssueImplementIssueClosedObservation
  , projectIssueImplementPlanCompletedObservation
  , projectIssueImplementPlanTurnStartedObservation
  , projectIssueImplementPostMergeReviewStartedObservation
  , projectIssueImplementPostMergeReviewerOutcomeBlockedObservation
  , projectIssueImplementPostMergeReviewerOutcomeCleanObservation
  , projectIssueImplementPostMergeReviewerOutcomeIncompleteObservation
  , projectIssueImplementPostMergeReviewerOutcomeReworkObservation
  , projectIssueImplementPullRequestBodyUpdatedImplementationReadyObservation
  , projectIssueImplementPullRequestBodyUpdatedImplementingObservation
  , projectIssueImplementPullRequestBodyUpdatedPlanReadyObservation
  , projectIssueImplementPullRequestCreatedImplementationReadyObservation
  , projectIssueImplementPullRequestCreatedImplementingObservation
  , projectIssueImplementPullRequestMergedHandoffInitializedObservation
  , projectIssueImplementPullRequestMergedHandoffReadyObservation
  , projectIssueImplementPullRequestMergedImplementationReadyObservation
  , projectIssueImplementPullRequestMergedImplementingObservation
  , projectIssueImplementPullRequestMergedPostMergeReviewPendingReviewerObservation
  , projectIssueImplementPullRequestMergedPostMergeReviewReadyObservation
  , projectIssueImplementPullRequestMergedPostMergeReviewingObservation
  , projectIssueImplementPullRequestMergedWaitingForIssueCloseObservation
  , projectIssueImplementPullRequestMergedWaitingForPrMergeObservation
  , projectIssueImplementPullRequestReusedImplementationReadyObservation
  , projectIssueImplementPullRequestReusedImplementingObservation
  , projectIssueImplementReviewHandoffInitializedHandoffInitializedObservation
  , projectIssueImplementReviewHandoffInitializedHandoffReadyObservation
  , projectIssueImplementReviewHandoffInitializedWaitingForPrMergeObservation
  , projectIssueImplementReviewHandoffStartedHandoffInitializedObservation
  , projectIssueImplementReviewHandoffStartedWaitingForPrMergeObservation
  , projectIssueImplementReviewerThreadReadyHandoffInitializedObservation
  , projectIssueImplementReviewerThreadReadyHandoffReadyObservation
  , projectIssueImplementReviewerThreadReadyPostMergeReviewPendingReviewerObservation
  , projectIssueImplementReviewerThreadReadyPostMergeReviewReadyObservation
  , projectIssueImplementReviewerThreadReadyWaitingForPrMergeObservation
  , projectIssueImplementWorkerThreadRefreshedImplementationReadyObservation
  , projectIssueImplementWorkerThreadRefreshedPlanReadyObservation
  , projectIssueImplementWorkerThreadRefreshedReadyToPlanObservation
  , projectIssueImplementationBlockedImplementationReadyObservation
  , projectIssueImplementationBlockedImplementingObservation
  , projectIssueImplementationCompletedHandoffInitializedObservation
  , projectIssueImplementationCompletedHandoffReadyObservation
  , projectIssueImplementationCompletedImplementingObservation
  , projectIssueImplementationCompletedWaitingForPrMergeObservation
  , projectIssueImplementationIncompleteObservation
  , projectIssueImplementationTurnStartedObservation
  ) where

import CodexWatcher.Core.Reason (BlockedReason)
import CodexWatcher.Core.State (SomeWatcherState (..), WatcherState (..))
import CodexWatcher.Domain.IssueImplement.Watcher
  ( IssueFinalReviewOutcome (..)
  , IssueImplementObservation (..)
  )
import CodexWatcher.Domain.PrReview.Types (CleanReviewEvidence, ReviewEvidence)
import CodexWatcher.Effects (EffectPlan, SomeEffect)
import CodexWatcher.EventLog.Types (EventReplayResult (..), WatcherEvent)
import CodexWatcher.Workflow.Agent.Ids (ThreadId, TurnId)
import CodexWatcher.Workflow.GitHub.Ids (BranchName, CommitSha, PrNumber)
import CodexWatcher.Workflow.Indexed.Spec qualified as IndexedWorkflow
import CodexWatcher.Workflow.Observation (DaemonObservation, ObservedPolicyTick (..))
import CodexWatcher.Workflow.Observation qualified as WorkflowObservation
import CodexWatcher.Workflow.Types
  ( MoifoldSpec
  , PlannedTransition (..)
  , WorkflowSpec (..)
  , legacyObservedPlannedTransition
  , moifoldPlannedTransitionFromEffects
  )
import Data.Kind (Type)
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

projectIssueImplementPlanTurnStartedObservation
  :: SomeWatcherState -> TurnId -> Either Text IssueImplementIndexedProjection
projectIssueImplementPlanTurnStartedObservation state turnId =
  projectIssueImplementObservation indexedState indexedObservation
 where
  indexedState = IssueImplementIndexedState state :: IssueImplementIndexedState IssueImplementIndexedReadyToPlan
  indexedObservation =
    issueImplementIndexedObservation "IssueImplement/PlanMode" "IssueImplement/PlanMode" (ObservedPlanTurnStarted turnId)
      :: IssueImplementIndexedObservation IssueImplementIndexedReadyToPlan IssueImplementIndexedInPlanMode

projectIssueImplementPlanCompletedObservation
  :: SomeWatcherState -> Text -> Maybe TurnId -> Either Text IssueImplementIndexedProjection
projectIssueImplementPlanCompletedObservation state planMarkdown maybeImplementationTurnId =
  projectIssueImplementObservation indexedState indexedObservation
 where
  indexedState = IssueImplementIndexedState state :: IssueImplementIndexedState IssueImplementIndexedInPlanMode
  indexedObservation =
    issueImplementIndexedObservation "IssueImplement/PlanMode" "IssueImplement/Implementing" (ObservedPlanCompleted planMarkdown maybeImplementationTurnId)
      :: IssueImplementIndexedObservation IssueImplementIndexedInPlanMode IssueImplementIndexedPlanReady

projectIssueImplementAttemptBranchAdvancedObservation
  :: SomeWatcherState -> BranchName -> Either Text IssueImplementIndexedProjection
projectIssueImplementAttemptBranchAdvancedObservation state branch =
  case workflowObserve @MoifoldSpec state observation of
    Right observed ->
      case workflowStateLabel @MoifoldSpec observed.observedState of
        "IssueImplement/Blocked" ->
          projectIssueImplementObservation indexedState blockedObservation
        _ ->
          projectIssueImplementObservation indexedState readyObservation
    Left failure -> Left failure
 where
  indexedState = IssueImplementIndexedState state :: IssueImplementIndexedState IssueImplementIndexedImplementationReady
  observation = issueImplementObservation (ObservedIssueAttemptBranchAdvanced branch)
  readyObservation =
    IssueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Implementing" observation
      :: IssueImplementIndexedObservation IssueImplementIndexedImplementationReady IssueImplementIndexedImplementationReady
  blockedObservation =
    IssueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Blocked" observation
      :: IssueImplementIndexedObservation IssueImplementIndexedImplementationReady IssueImplementIndexedBlocked

projectIssueImplementWorkerThreadRefreshedReadyToPlanObservation
  :: SomeWatcherState -> ThreadId -> Either Text IssueImplementIndexedProjection
projectIssueImplementWorkerThreadRefreshedReadyToPlanObservation state threadId =
  projectIssueImplementObservation
    (IssueImplementIndexedState state :: IssueImplementIndexedState IssueImplementIndexedReadyToPlan)
    ( issueImplementIndexedObservation "IssueImplement/PlanMode" "IssueImplement/PlanMode" (ObservedIssueWorkerThreadRefreshed threadId)
        :: IssueImplementIndexedObservation IssueImplementIndexedReadyToPlan IssueImplementIndexedReadyToPlan
    )

projectIssueImplementWorkerThreadRefreshedPlanReadyObservation
  :: SomeWatcherState -> ThreadId -> Either Text IssueImplementIndexedProjection
projectIssueImplementWorkerThreadRefreshedPlanReadyObservation state threadId =
  projectIssueImplementObservation
    (IssueImplementIndexedState state :: IssueImplementIndexedState IssueImplementIndexedPlanReady)
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedIssueWorkerThreadRefreshed threadId)
        :: IssueImplementIndexedObservation IssueImplementIndexedPlanReady IssueImplementIndexedPlanReady
    )

projectIssueImplementWorkerThreadRefreshedImplementationReadyObservation
  :: SomeWatcherState -> ThreadId -> Either Text IssueImplementIndexedProjection
projectIssueImplementWorkerThreadRefreshedImplementationReadyObservation state threadId =
  projectIssueImplementObservation
    (IssueImplementIndexedState state :: IssueImplementIndexedState IssueImplementIndexedImplementationReady)
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedIssueWorkerThreadRefreshed threadId)
        :: IssueImplementIndexedObservation IssueImplementIndexedImplementationReady IssueImplementIndexedImplementationReady
    )

projectIssueImplementPullRequestCreatedImplementationReadyObservation
  :: SomeWatcherState -> PrNumber -> Either Text IssueImplementIndexedProjection
projectIssueImplementPullRequestCreatedImplementationReadyObservation state prNumber =
  projectIssueImplementObservation
    (IssueImplementIndexedState state :: IssueImplementIndexedState IssueImplementIndexedImplementationReady)
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/PlanMode" (ObservedPullRequestCreated prNumber)
        :: IssueImplementIndexedObservation IssueImplementIndexedImplementationReady IssueImplementIndexedReadyToPlan
    )

projectIssueImplementPullRequestCreatedImplementingObservation
  :: SomeWatcherState -> PrNumber -> Either Text IssueImplementIndexedProjection
projectIssueImplementPullRequestCreatedImplementingObservation state prNumber =
  projectIssueImplementObservation
    (IssueImplementIndexedState state :: IssueImplementIndexedState IssueImplementIndexedImplementing)
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedPullRequestCreated prNumber)
        :: IssueImplementIndexedObservation IssueImplementIndexedImplementing IssueImplementIndexedImplementing
    )

projectIssueImplementPullRequestReusedImplementationReadyObservation
  :: SomeWatcherState -> PrNumber -> Either Text IssueImplementIndexedProjection
projectIssueImplementPullRequestReusedImplementationReadyObservation state prNumber =
  projectIssueImplementObservation
    (IssueImplementIndexedState state :: IssueImplementIndexedState IssueImplementIndexedImplementationReady)
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/PlanMode" (ObservedPullRequestReused prNumber)
        :: IssueImplementIndexedObservation IssueImplementIndexedImplementationReady IssueImplementIndexedReadyToPlan
    )

projectIssueImplementPullRequestReusedImplementingObservation
  :: SomeWatcherState -> PrNumber -> Either Text IssueImplementIndexedProjection
projectIssueImplementPullRequestReusedImplementingObservation state prNumber =
  projectIssueImplementObservation
    (IssueImplementIndexedState state :: IssueImplementIndexedState IssueImplementIndexedImplementing)
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedPullRequestReused prNumber)
        :: IssueImplementIndexedObservation IssueImplementIndexedImplementing IssueImplementIndexedImplementing
    )

projectIssueImplementPullRequestBodyUpdatedPlanReadyObservation
  :: SomeWatcherState -> PrNumber -> Either Text IssueImplementIndexedProjection
projectIssueImplementPullRequestBodyUpdatedPlanReadyObservation state prNumber =
  projectIssueImplementBodyUpdated
    state
    prNumber
    (IssueImplementIndexedState state :: IssueImplementIndexedState IssueImplementIndexedPlanReady)
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedPullRequestBodyUpdated prNumber)
        :: IssueImplementIndexedObservation IssueImplementIndexedPlanReady IssueImplementIndexedImplementationReady
    )
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Blocked" (ObservedPullRequestBodyUpdated prNumber)
        :: IssueImplementIndexedObservation IssueImplementIndexedPlanReady IssueImplementIndexedBlocked
    )

projectIssueImplementPullRequestBodyUpdatedImplementationReadyObservation
  :: SomeWatcherState -> PrNumber -> Either Text IssueImplementIndexedProjection
projectIssueImplementPullRequestBodyUpdatedImplementationReadyObservation state prNumber =
  projectIssueImplementBodyUpdated
    state
    prNumber
    (IssueImplementIndexedState state :: IssueImplementIndexedState IssueImplementIndexedImplementationReady)
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedPullRequestBodyUpdated prNumber)
        :: IssueImplementIndexedObservation IssueImplementIndexedImplementationReady IssueImplementIndexedImplementationReady
    )
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Blocked" (ObservedPullRequestBodyUpdated prNumber)
        :: IssueImplementIndexedObservation IssueImplementIndexedImplementationReady IssueImplementIndexedBlocked
    )

projectIssueImplementPullRequestBodyUpdatedImplementingObservation
  :: SomeWatcherState -> PrNumber -> Either Text IssueImplementIndexedProjection
projectIssueImplementPullRequestBodyUpdatedImplementingObservation state prNumber =
  projectIssueImplementBodyUpdated
    state
    prNumber
    (IssueImplementIndexedState state :: IssueImplementIndexedState IssueImplementIndexedImplementing)
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedPullRequestBodyUpdated prNumber)
        :: IssueImplementIndexedObservation IssueImplementIndexedImplementing IssueImplementIndexedImplementing
    )
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Blocked" (ObservedPullRequestBodyUpdated prNumber)
        :: IssueImplementIndexedObservation IssueImplementIndexedImplementing IssueImplementIndexedBlocked
    )

projectIssueImplementBodyUpdated
  :: forall (source :: Type) (target :: Type).
     SomeWatcherState
  -> PrNumber
  -> IssueImplementIndexedState source
  -> IssueImplementIndexedObservation source target
  -> IssueImplementIndexedObservation source IssueImplementIndexedBlocked
  -> Either Text IssueImplementIndexedProjection
projectIssueImplementBodyUpdated state prNumber indexedState okObservation blockedObservation =
  case workflowObserve @MoifoldSpec state (issueImplementObservation (ObservedPullRequestBodyUpdated prNumber)) of
    Right observed
      | workflowStateLabel @MoifoldSpec observed.observedState == "IssueImplement/Blocked" ->
          projectIssueImplementObservation indexedState blockedObservation
      | otherwise ->
          projectIssueImplementObservation indexedState okObservation
    Left failure -> Left failure

projectIssueImplementationTurnStartedObservation
  :: SomeWatcherState -> TurnId -> Either Text IssueImplementIndexedProjection
projectIssueImplementationTurnStartedObservation state turnId =
  projectIssueImplementObservation
    (IssueImplementIndexedState state :: IssueImplementIndexedState IssueImplementIndexedImplementationReady)
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedImplementationTurnStarted turnId)
        :: IssueImplementIndexedObservation IssueImplementIndexedImplementationReady IssueImplementIndexedImplementing
    )

projectIssueImplementationIncompleteObservation
  :: SomeWatcherState -> Text -> Either Text IssueImplementIndexedProjection
projectIssueImplementationIncompleteObservation state reason =
  projectIssueImplementObservation
    (IssueImplementIndexedState state :: IssueImplementIndexedState IssueImplementIndexedImplementing)
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedImplementationIncomplete reason)
        :: IssueImplementIndexedObservation IssueImplementIndexedImplementing IssueImplementIndexedImplementationReady
    )

projectIssueImplementationBlockedImplementationReadyObservation
  :: SomeWatcherState -> BlockedReason -> Either Text IssueImplementIndexedProjection
projectIssueImplementationBlockedImplementationReadyObservation state reason =
  projectIssueImplementObservation
    (IssueImplementIndexedState state :: IssueImplementIndexedState IssueImplementIndexedImplementationReady)
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Blocked" (ObservedImplementationBlocked reason)
        :: IssueImplementIndexedObservation IssueImplementIndexedImplementationReady IssueImplementIndexedBlocked
    )

projectIssueImplementationBlockedImplementingObservation
  :: SomeWatcherState -> BlockedReason -> Either Text IssueImplementIndexedProjection
projectIssueImplementationBlockedImplementingObservation state reason =
  projectIssueImplementObservation
    (IssueImplementIndexedState state :: IssueImplementIndexedState IssueImplementIndexedImplementing)
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Blocked" (ObservedImplementationBlocked reason)
        :: IssueImplementIndexedObservation IssueImplementIndexedImplementing IssueImplementIndexedBlocked
    )

projectIssueImplementReviewHandoffInitializedHandoffReadyObservation
  :: SomeWatcherState -> PrNumber -> Either Text IssueImplementIndexedProjection
projectIssueImplementReviewHandoffInitializedHandoffReadyObservation state prNumber =
  projectIssueImplementPrSensitive
    state
    (ObservedReviewHandoffInitialized prNumber)
    (IssueImplementIndexedState state :: IssueImplementIndexedState IssueImplementIndexedHandoffReady)
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedReviewHandoffInitialized prNumber)
        :: IssueImplementIndexedObservation IssueImplementIndexedHandoffReady IssueImplementIndexedHandoffInitialized
    )
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Blocked" (ObservedReviewHandoffInitialized prNumber)
        :: IssueImplementIndexedObservation IssueImplementIndexedHandoffReady IssueImplementIndexedBlocked
    )

projectIssueImplementReviewHandoffInitializedHandoffInitializedObservation
  :: SomeWatcherState -> PrNumber -> Either Text IssueImplementIndexedProjection
projectIssueImplementReviewHandoffInitializedHandoffInitializedObservation state prNumber =
  projectIssueImplementPrSensitive
    state
    (ObservedReviewHandoffInitialized prNumber)
    (IssueImplementIndexedState state :: IssueImplementIndexedState IssueImplementIndexedHandoffInitialized)
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedReviewHandoffInitialized prNumber)
        :: IssueImplementIndexedObservation IssueImplementIndexedHandoffInitialized IssueImplementIndexedHandoffInitialized
    )
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Blocked" (ObservedReviewHandoffInitialized prNumber)
        :: IssueImplementIndexedObservation IssueImplementIndexedHandoffInitialized IssueImplementIndexedBlocked
    )

projectIssueImplementReviewHandoffInitializedWaitingForPrMergeObservation
  :: SomeWatcherState -> PrNumber -> Either Text IssueImplementIndexedProjection
projectIssueImplementReviewHandoffInitializedWaitingForPrMergeObservation state prNumber =
  projectIssueImplementObservation
    (IssueImplementIndexedState state :: IssueImplementIndexedState IssueImplementIndexedWaitingForPrMerge)
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedReviewHandoffInitialized prNumber)
        :: IssueImplementIndexedObservation IssueImplementIndexedWaitingForPrMerge IssueImplementIndexedWaitingForPrMerge
    )

projectIssueImplementReviewHandoffStartedHandoffInitializedObservation
  :: SomeWatcherState -> PrNumber -> Either Text IssueImplementIndexedProjection
projectIssueImplementReviewHandoffStartedHandoffInitializedObservation state prNumber =
  projectIssueImplementPrSensitive
    state
    (ObservedReviewHandoffStarted prNumber)
    (IssueImplementIndexedState state :: IssueImplementIndexedState IssueImplementIndexedHandoffInitialized)
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedReviewHandoffStarted prNumber)
        :: IssueImplementIndexedObservation IssueImplementIndexedHandoffInitialized IssueImplementIndexedWaitingForPrMerge
    )
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Blocked" (ObservedReviewHandoffStarted prNumber)
        :: IssueImplementIndexedObservation IssueImplementIndexedHandoffInitialized IssueImplementIndexedBlocked
    )

projectIssueImplementReviewHandoffStartedWaitingForPrMergeObservation
  :: SomeWatcherState -> PrNumber -> Either Text IssueImplementIndexedProjection
projectIssueImplementReviewHandoffStartedWaitingForPrMergeObservation state prNumber =
  projectIssueImplementObservation
    (IssueImplementIndexedState state :: IssueImplementIndexedState IssueImplementIndexedWaitingForPrMerge)
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedReviewHandoffStarted prNumber)
        :: IssueImplementIndexedObservation IssueImplementIndexedWaitingForPrMerge IssueImplementIndexedWaitingForPrMerge
    )

projectIssueImplementationCompletedImplementingObservation
  :: SomeWatcherState -> PrNumber -> Maybe ThreadId -> Either Text IssueImplementIndexedProjection
projectIssueImplementationCompletedImplementingObservation state prNumber maybeReviewerThreadId =
  projectIssueImplementPrSensitive
    state
    (ObservedImplementationCompleted prNumber maybeReviewerThreadId)
    (IssueImplementIndexedState state :: IssueImplementIndexedState IssueImplementIndexedImplementing)
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedImplementationCompleted prNumber maybeReviewerThreadId)
        :: IssueImplementIndexedObservation IssueImplementIndexedImplementing IssueImplementIndexedHandoffReady
    )
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Blocked" (ObservedImplementationCompleted prNumber maybeReviewerThreadId)
        :: IssueImplementIndexedObservation IssueImplementIndexedImplementing IssueImplementIndexedBlocked
    )

projectIssueImplementationCompletedHandoffReadyObservation
  :: SomeWatcherState -> PrNumber -> Maybe ThreadId -> Either Text IssueImplementIndexedProjection
projectIssueImplementationCompletedHandoffReadyObservation state prNumber maybeReviewerThreadId =
  projectIssueImplementPrSensitive
    state
    (ObservedImplementationCompleted prNumber maybeReviewerThreadId)
    (IssueImplementIndexedState state :: IssueImplementIndexedState IssueImplementIndexedHandoffReady)
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedImplementationCompleted prNumber maybeReviewerThreadId)
        :: IssueImplementIndexedObservation IssueImplementIndexedHandoffReady IssueImplementIndexedHandoffReady
    )
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Blocked" (ObservedImplementationCompleted prNumber maybeReviewerThreadId)
        :: IssueImplementIndexedObservation IssueImplementIndexedHandoffReady IssueImplementIndexedBlocked
    )

projectIssueImplementationCompletedHandoffInitializedObservation
  :: SomeWatcherState -> PrNumber -> Maybe ThreadId -> Either Text IssueImplementIndexedProjection
projectIssueImplementationCompletedHandoffInitializedObservation state prNumber maybeReviewerThreadId =
  projectIssueImplementPrSensitive
    state
    (ObservedImplementationCompleted prNumber maybeReviewerThreadId)
    (IssueImplementIndexedState state :: IssueImplementIndexedState IssueImplementIndexedHandoffInitialized)
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedImplementationCompleted prNumber maybeReviewerThreadId)
        :: IssueImplementIndexedObservation IssueImplementIndexedHandoffInitialized IssueImplementIndexedHandoffInitialized
    )
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Blocked" (ObservedImplementationCompleted prNumber maybeReviewerThreadId)
        :: IssueImplementIndexedObservation IssueImplementIndexedHandoffInitialized IssueImplementIndexedBlocked
    )

projectIssueImplementationCompletedWaitingForPrMergeObservation
  :: SomeWatcherState -> PrNumber -> Maybe ThreadId -> Either Text IssueImplementIndexedProjection
projectIssueImplementationCompletedWaitingForPrMergeObservation state prNumber maybeReviewerThreadId =
  projectIssueImplementPrSensitive
    state
    (ObservedImplementationCompleted prNumber maybeReviewerThreadId)
    (IssueImplementIndexedState state :: IssueImplementIndexedState IssueImplementIndexedWaitingForPrMerge)
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedImplementationCompleted prNumber maybeReviewerThreadId)
        :: IssueImplementIndexedObservation IssueImplementIndexedWaitingForPrMerge IssueImplementIndexedWaitingForPrMerge
    )
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Blocked" (ObservedImplementationCompleted prNumber maybeReviewerThreadId)
        :: IssueImplementIndexedObservation IssueImplementIndexedWaitingForPrMerge IssueImplementIndexedBlocked
    )

projectIssueImplementReviewerThreadReadyHandoffReadyObservation
  :: SomeWatcherState -> ThreadId -> Either Text IssueImplementIndexedProjection
projectIssueImplementReviewerThreadReadyHandoffReadyObservation state threadId =
  projectIssueImplementObservation
    (IssueImplementIndexedState state :: IssueImplementIndexedState IssueImplementIndexedHandoffReady)
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedIssueReviewerThreadReady threadId)
        :: IssueImplementIndexedObservation IssueImplementIndexedHandoffReady IssueImplementIndexedHandoffReady
    )

projectIssueImplementReviewerThreadReadyHandoffInitializedObservation
  :: SomeWatcherState -> ThreadId -> Either Text IssueImplementIndexedProjection
projectIssueImplementReviewerThreadReadyHandoffInitializedObservation state threadId =
  projectIssueImplementObservation
    (IssueImplementIndexedState state :: IssueImplementIndexedState IssueImplementIndexedHandoffInitialized)
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedIssueReviewerThreadReady threadId)
        :: IssueImplementIndexedObservation IssueImplementIndexedHandoffInitialized IssueImplementIndexedHandoffInitialized
    )

projectIssueImplementReviewerThreadReadyWaitingForPrMergeObservation
  :: SomeWatcherState -> ThreadId -> Either Text IssueImplementIndexedProjection
projectIssueImplementReviewerThreadReadyWaitingForPrMergeObservation state threadId =
  projectIssueImplementObservation
    (IssueImplementIndexedState state :: IssueImplementIndexedState IssueImplementIndexedWaitingForPrMerge)
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedIssueReviewerThreadReady threadId)
        :: IssueImplementIndexedObservation IssueImplementIndexedWaitingForPrMerge IssueImplementIndexedWaitingForPrMerge
    )

projectIssueImplementReviewerThreadReadyPostMergeReviewPendingReviewerObservation
  :: SomeWatcherState -> ThreadId -> Either Text IssueImplementIndexedProjection
projectIssueImplementReviewerThreadReadyPostMergeReviewPendingReviewerObservation state threadId =
  projectIssueImplementObservation
    (IssueImplementIndexedState state :: IssueImplementIndexedState IssueImplementIndexedPostMergeReviewPendingReviewer)
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedIssueReviewerThreadReady threadId)
        :: IssueImplementIndexedObservation IssueImplementIndexedPostMergeReviewPendingReviewer IssueImplementIndexedPostMergeReviewReady
    )

projectIssueImplementReviewerThreadReadyPostMergeReviewReadyObservation
  :: SomeWatcherState -> ThreadId -> Either Text IssueImplementIndexedProjection
projectIssueImplementReviewerThreadReadyPostMergeReviewReadyObservation state threadId =
  projectIssueImplementObservation
    (IssueImplementIndexedState state :: IssueImplementIndexedState IssueImplementIndexedPostMergeReviewReady)
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedIssueReviewerThreadReady threadId)
        :: IssueImplementIndexedObservation IssueImplementIndexedPostMergeReviewReady IssueImplementIndexedPostMergeReviewReady
    )

projectIssueImplementPullRequestMergedWaitingForPrMergeObservation
  :: SomeWatcherState -> PrNumber -> Either Text IssueImplementIndexedProjection
projectIssueImplementPullRequestMergedWaitingForPrMergeObservation state prNumber =
  case workflowObserve @MoifoldSpec state observation of
    Right observed ->
      case observed.observedState of
        SomeWatcherState BlockedState {} ->
          projectIssueImplementObservation indexedState blockedObservation
        SomeWatcherState IssuePostMergeReviewReady {} ->
          projectIssueImplementObservation indexedState readyObservation
        SomeWatcherState IssuePostMergeReviewPendingReviewer {} ->
          projectIssueImplementObservation indexedState pendingReviewerObservation
        _ ->
          projectIssueImplementObservation indexedState pendingReviewerObservation
    Left failure -> Left failure
 where
  indexedState = IssueImplementIndexedState state :: IssueImplementIndexedState IssueImplementIndexedWaitingForPrMerge
  observation = issueImplementObservation (ObservedPullRequestMerged prNumber)
  pendingReviewerObservation =
    IssueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Implementing" observation
      :: IssueImplementIndexedObservation IssueImplementIndexedWaitingForPrMerge IssueImplementIndexedPostMergeReviewPendingReviewer
  readyObservation =
    IssueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Implementing" observation
      :: IssueImplementIndexedObservation IssueImplementIndexedWaitingForPrMerge IssueImplementIndexedPostMergeReviewReady
  blockedObservation =
    IssueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Blocked" observation
      :: IssueImplementIndexedObservation IssueImplementIndexedWaitingForPrMerge IssueImplementIndexedBlocked

projectIssueImplementPullRequestMergedImplementationReadyObservation
  :: SomeWatcherState -> PrNumber -> Either Text IssueImplementIndexedProjection
projectIssueImplementPullRequestMergedImplementationReadyObservation state prNumber =
  projectIgnoredMergedPr state prNumber (IssueImplementIndexedState state :: IssueImplementIndexedState IssueImplementIndexedImplementationReady)
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedPullRequestMerged prNumber)
        :: IssueImplementIndexedObservation IssueImplementIndexedImplementationReady IssueImplementIndexedImplementationReady
    )

projectIssueImplementPullRequestMergedImplementingObservation
  :: SomeWatcherState -> PrNumber -> Either Text IssueImplementIndexedProjection
projectIssueImplementPullRequestMergedImplementingObservation state prNumber =
  projectIgnoredMergedPr state prNumber (IssueImplementIndexedState state :: IssueImplementIndexedState IssueImplementIndexedImplementing)
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedPullRequestMerged prNumber)
        :: IssueImplementIndexedObservation IssueImplementIndexedImplementing IssueImplementIndexedImplementing
    )

projectIssueImplementPullRequestMergedHandoffReadyObservation
  :: SomeWatcherState -> PrNumber -> Either Text IssueImplementIndexedProjection
projectIssueImplementPullRequestMergedHandoffReadyObservation state prNumber =
  projectIgnoredMergedPr state prNumber (IssueImplementIndexedState state :: IssueImplementIndexedState IssueImplementIndexedHandoffReady)
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedPullRequestMerged prNumber)
        :: IssueImplementIndexedObservation IssueImplementIndexedHandoffReady IssueImplementIndexedHandoffReady
    )

projectIssueImplementPullRequestMergedHandoffInitializedObservation
  :: SomeWatcherState -> PrNumber -> Either Text IssueImplementIndexedProjection
projectIssueImplementPullRequestMergedHandoffInitializedObservation state prNumber =
  projectIgnoredMergedPr state prNumber (IssueImplementIndexedState state :: IssueImplementIndexedState IssueImplementIndexedHandoffInitialized)
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedPullRequestMerged prNumber)
        :: IssueImplementIndexedObservation IssueImplementIndexedHandoffInitialized IssueImplementIndexedHandoffInitialized
    )

projectIssueImplementPullRequestMergedPostMergeReviewPendingReviewerObservation
  :: SomeWatcherState -> PrNumber -> Either Text IssueImplementIndexedProjection
projectIssueImplementPullRequestMergedPostMergeReviewPendingReviewerObservation state prNumber =
  projectIgnoredMergedPr state prNumber (IssueImplementIndexedState state :: IssueImplementIndexedState IssueImplementIndexedPostMergeReviewPendingReviewer)
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedPullRequestMerged prNumber)
        :: IssueImplementIndexedObservation IssueImplementIndexedPostMergeReviewPendingReviewer IssueImplementIndexedPostMergeReviewPendingReviewer
    )

projectIssueImplementPullRequestMergedPostMergeReviewReadyObservation
  :: SomeWatcherState -> PrNumber -> Either Text IssueImplementIndexedProjection
projectIssueImplementPullRequestMergedPostMergeReviewReadyObservation state prNumber =
  projectIgnoredMergedPr state prNumber (IssueImplementIndexedState state :: IssueImplementIndexedState IssueImplementIndexedPostMergeReviewReady)
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedPullRequestMerged prNumber)
        :: IssueImplementIndexedObservation IssueImplementIndexedPostMergeReviewReady IssueImplementIndexedPostMergeReviewReady
    )

projectIssueImplementPullRequestMergedPostMergeReviewingObservation
  :: SomeWatcherState -> PrNumber -> Either Text IssueImplementIndexedProjection
projectIssueImplementPullRequestMergedPostMergeReviewingObservation state prNumber =
  projectIgnoredMergedPr state prNumber (IssueImplementIndexedState state :: IssueImplementIndexedState IssueImplementIndexedPostMergeReviewing)
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedPullRequestMerged prNumber)
        :: IssueImplementIndexedObservation IssueImplementIndexedPostMergeReviewing IssueImplementIndexedPostMergeReviewing
    )

projectIssueImplementPullRequestMergedWaitingForIssueCloseObservation
  :: SomeWatcherState -> PrNumber -> Either Text IssueImplementIndexedProjection
projectIssueImplementPullRequestMergedWaitingForIssueCloseObservation state prNumber =
  projectIgnoredMergedPr state prNumber (IssueImplementIndexedState state :: IssueImplementIndexedState IssueImplementIndexedWaitingForIssueClose)
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedPullRequestMerged prNumber)
        :: IssueImplementIndexedObservation IssueImplementIndexedWaitingForIssueClose IssueImplementIndexedWaitingForIssueClose
    )

projectIssueImplementPostMergeReviewStartedObservation
  :: SomeWatcherState -> CommitSha -> TurnId -> Either Text IssueImplementIndexedProjection
projectIssueImplementPostMergeReviewStartedObservation state commit turnId =
  projectIssueImplementObservation
    (IssueImplementIndexedState state :: IssueImplementIndexedState IssueImplementIndexedPostMergeReviewReady)
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedPostMergeReviewStarted commit turnId)
        :: IssueImplementIndexedObservation IssueImplementIndexedPostMergeReviewReady IssueImplementIndexedPostMergeReviewing
    )

projectIssueImplementPostMergeReviewerOutcomeCleanObservation
  :: SomeWatcherState -> CleanReviewEvidence -> Either Text IssueImplementIndexedProjection
projectIssueImplementPostMergeReviewerOutcomeCleanObservation state evidence =
  projectIssueImplementObservation
    (IssueImplementIndexedState state :: IssueImplementIndexedState IssueImplementIndexedPostMergeReviewing)
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedPostMergeReviewerOutcome (IssueFinalReviewClean evidence))
        :: IssueImplementIndexedObservation IssueImplementIndexedPostMergeReviewing IssueImplementIndexedWaitingForIssueClose
    )

projectIssueImplementPostMergeReviewerOutcomeReworkObservation
  :: SomeWatcherState -> ReviewEvidence -> Either Text IssueImplementIndexedProjection
projectIssueImplementPostMergeReviewerOutcomeReworkObservation state evidence =
  projectIssueImplementObservation
    (IssueImplementIndexedState state :: IssueImplementIndexedState IssueImplementIndexedPostMergeReviewing)
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedPostMergeReviewerOutcome (IssueFinalReviewRework evidence))
        :: IssueImplementIndexedObservation IssueImplementIndexedPostMergeReviewing IssueImplementIndexedImplementationReady
    )

projectIssueImplementPostMergeReviewerOutcomeIncompleteObservation
  :: SomeWatcherState -> Text -> Either Text IssueImplementIndexedProjection
projectIssueImplementPostMergeReviewerOutcomeIncompleteObservation state reason =
  projectIssueImplementObservation
    (IssueImplementIndexedState state :: IssueImplementIndexedState IssueImplementIndexedPostMergeReviewing)
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Implementing" (ObservedPostMergeReviewerOutcome (IssueFinalReviewIncomplete reason))
        :: IssueImplementIndexedObservation IssueImplementIndexedPostMergeReviewing IssueImplementIndexedPostMergeReviewReady
    )

projectIssueImplementPostMergeReviewerOutcomeBlockedObservation
  :: SomeWatcherState -> BlockedReason -> Either Text IssueImplementIndexedProjection
projectIssueImplementPostMergeReviewerOutcomeBlockedObservation state reason =
  projectIssueImplementObservation
    (IssueImplementIndexedState state :: IssueImplementIndexedState IssueImplementIndexedPostMergeReviewing)
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Blocked" (ObservedPostMergeReviewerOutcome (IssueFinalReviewBlocked reason))
        :: IssueImplementIndexedObservation IssueImplementIndexedPostMergeReviewing IssueImplementIndexedBlocked
    )

projectIssueImplementIssueClosedObservation
  :: SomeWatcherState -> PrNumber -> Either Text IssueImplementIndexedProjection
projectIssueImplementIssueClosedObservation state prNumber =
  projectIssueImplementPrSensitive
    state
    (ObservedIssueClosed prNumber)
    (IssueImplementIndexedState state :: IssueImplementIndexedState IssueImplementIndexedWaitingForIssueClose)
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Complete" (ObservedIssueClosed prNumber)
        :: IssueImplementIndexedObservation IssueImplementIndexedWaitingForIssueClose IssueImplementIndexedComplete
    )
    ( issueImplementIndexedObservation "IssueImplement/Implementing" "IssueImplement/Blocked" (ObservedIssueClosed prNumber)
        :: IssueImplementIndexedObservation IssueImplementIndexedWaitingForIssueClose IssueImplementIndexedBlocked
    )

projectIssueImplementBlockedReadyToPlanObservation
  :: SomeWatcherState -> BlockedReason -> Either Text IssueImplementIndexedProjection
projectIssueImplementBlockedReadyToPlanObservation =
  projectBlockedObservation "IssueImplement/PlanMode" (IssueImplementIndexedState :: SomeWatcherState -> IssueImplementIndexedState IssueImplementIndexedReadyToPlan)

projectIssueImplementBlockedInPlanModeObservation
  :: SomeWatcherState -> BlockedReason -> Either Text IssueImplementIndexedProjection
projectIssueImplementBlockedInPlanModeObservation =
  projectBlockedObservation "IssueImplement/PlanMode" (IssueImplementIndexedState :: SomeWatcherState -> IssueImplementIndexedState IssueImplementIndexedInPlanMode)

projectIssueImplementBlockedPlanReadyObservation
  :: SomeWatcherState -> BlockedReason -> Either Text IssueImplementIndexedProjection
projectIssueImplementBlockedPlanReadyObservation =
  projectBlockedObservation "IssueImplement/Implementing" (IssueImplementIndexedState :: SomeWatcherState -> IssueImplementIndexedState IssueImplementIndexedPlanReady)

projectIssueImplementBlockedImplementationReadyObservation
  :: SomeWatcherState -> BlockedReason -> Either Text IssueImplementIndexedProjection
projectIssueImplementBlockedImplementationReadyObservation =
  projectBlockedObservation "IssueImplement/Implementing" (IssueImplementIndexedState :: SomeWatcherState -> IssueImplementIndexedState IssueImplementIndexedImplementationReady)

projectIssueImplementBlockedImplementingObservation
  :: SomeWatcherState -> BlockedReason -> Either Text IssueImplementIndexedProjection
projectIssueImplementBlockedImplementingObservation =
  projectBlockedObservation "IssueImplement/Implementing" (IssueImplementIndexedState :: SomeWatcherState -> IssueImplementIndexedState IssueImplementIndexedImplementing)

projectIssueImplementBlockedHandoffReadyObservation
  :: SomeWatcherState -> BlockedReason -> Either Text IssueImplementIndexedProjection
projectIssueImplementBlockedHandoffReadyObservation =
  projectBlockedObservation "IssueImplement/Implementing" (IssueImplementIndexedState :: SomeWatcherState -> IssueImplementIndexedState IssueImplementIndexedHandoffReady)

projectIssueImplementBlockedHandoffInitializedObservation
  :: SomeWatcherState -> BlockedReason -> Either Text IssueImplementIndexedProjection
projectIssueImplementBlockedHandoffInitializedObservation =
  projectBlockedObservation "IssueImplement/Implementing" (IssueImplementIndexedState :: SomeWatcherState -> IssueImplementIndexedState IssueImplementIndexedHandoffInitialized)

projectIssueImplementBlockedWaitingForPrMergeObservation
  :: SomeWatcherState -> BlockedReason -> Either Text IssueImplementIndexedProjection
projectIssueImplementBlockedWaitingForPrMergeObservation =
  projectBlockedObservation "IssueImplement/Implementing" (IssueImplementIndexedState :: SomeWatcherState -> IssueImplementIndexedState IssueImplementIndexedWaitingForPrMerge)

projectIssueImplementBlockedPostMergeReviewPendingReviewerObservation
  :: SomeWatcherState -> BlockedReason -> Either Text IssueImplementIndexedProjection
projectIssueImplementBlockedPostMergeReviewPendingReviewerObservation =
  projectBlockedObservation "IssueImplement/Implementing" (IssueImplementIndexedState :: SomeWatcherState -> IssueImplementIndexedState IssueImplementIndexedPostMergeReviewPendingReviewer)

projectIssueImplementBlockedPostMergeReviewReadyObservation
  :: SomeWatcherState -> BlockedReason -> Either Text IssueImplementIndexedProjection
projectIssueImplementBlockedPostMergeReviewReadyObservation =
  projectBlockedObservation "IssueImplement/Implementing" (IssueImplementIndexedState :: SomeWatcherState -> IssueImplementIndexedState IssueImplementIndexedPostMergeReviewReady)

projectIssueImplementBlockedPostMergeReviewingObservation
  :: SomeWatcherState -> BlockedReason -> Either Text IssueImplementIndexedProjection
projectIssueImplementBlockedPostMergeReviewingObservation =
  projectBlockedObservation "IssueImplement/Implementing" (IssueImplementIndexedState :: SomeWatcherState -> IssueImplementIndexedState IssueImplementIndexedPostMergeReviewing)

projectIssueImplementBlockedWaitingForIssueCloseObservation
  :: SomeWatcherState -> BlockedReason -> Either Text IssueImplementIndexedProjection
projectIssueImplementBlockedWaitingForIssueCloseObservation =
  projectBlockedObservation "IssueImplement/Implementing" (IssueImplementIndexedState :: SomeWatcherState -> IssueImplementIndexedState IssueImplementIndexedWaitingForIssueClose)

projectIssueImplementPrSensitive
  :: forall (source :: Type) (target :: Type).
     SomeWatcherState
  -> IssueImplementObservation
  -> IssueImplementIndexedState source
  -> IssueImplementIndexedObservation source target
  -> IssueImplementIndexedObservation source IssueImplementIndexedBlocked
  -> Either Text IssueImplementIndexedProjection
projectIssueImplementPrSensitive state observation indexedState okObservation blockedObservation =
  case workflowObserve @MoifoldSpec state (issueImplementObservation observation) of
    Right observed
      | workflowStateLabel @MoifoldSpec observed.observedState == "IssueImplement/Blocked" ->
          projectIssueImplementObservation indexedState blockedObservation
      | otherwise ->
          projectIssueImplementObservation indexedState okObservation
    Left failure -> Left failure

projectIgnoredMergedPr
  :: forall (source :: Type).
     SomeWatcherState
  -> PrNumber
  -> IssueImplementIndexedState source
  -> IssueImplementIndexedObservation source source
  -> Either Text IssueImplementIndexedProjection
projectIgnoredMergedPr _state _prNumber indexedState observation =
  projectIssueImplementObservation indexedState observation

projectBlockedObservation
  :: forall (source :: Type).
     Text
  -> (SomeWatcherState -> IssueImplementIndexedState source)
  -> SomeWatcherState
  -> BlockedReason
  -> Either Text IssueImplementIndexedProjection
projectBlockedObservation sourceLabel mkState state reason =
  projectIssueImplementObservation
    (mkState state)
    ( IssueImplementIndexedObservation sourceLabel "IssueImplement/Blocked" (issueImplementObservation (ObservedIssueImplementBlocked reason))
        :: IssueImplementIndexedObservation source IssueImplementIndexedBlocked
    )

issueImplementIndexedObservation
  :: Text
  -> Text
  -> IssueImplementObservation
  -> IssueImplementIndexedObservation source target
issueImplementIndexedObservation sourceLabel targetLabel =
  IssueImplementIndexedObservation sourceLabel targetLabel . issueImplementObservation

issueImplementObservation :: IssueImplementObservation -> DaemonObservation
issueImplementObservation =
  WorkflowObservation.DaemonIssueImplementObservation

projectIssueImplementObservation
  :: forall (source :: Type) (target :: Type).
     IssueImplementIndexedState source
  -> IssueImplementIndexedObservation source target
  -> Either Text IssueImplementIndexedProjection
projectIssueImplementObservation indexedState indexedObservation = do
  observed <-
    IndexedWorkflow.indexedWorkflowObserve
      @IssueImplementIndexedSpec
      indexedState
      indexedObservation
  planned <-
    IndexedWorkflow.indexedWorkflowPlanObservation
      @IssueImplementIndexedSpec
      indexedState
      indexedObservation
  let IssueImplementIndexedState finalState =
        IndexedWorkflow.indexedWorkflowObservedState @IssueImplementIndexedSpec observed
      projectedPlan = issueImplementIndexedTransitionToCompatibility planned
  pure
    IssueImplementIndexedProjection
      { issueImplementIndexedProjectionPlanned = projectedPlan
      , issueImplementIndexedProjectionFinalState = finalState
      , issueImplementIndexedProjectionSourceLabel =
          IndexedWorkflow.indexedWorkflowPlannedTransitionSourceLabel
            @IssueImplementIndexedSpec
            planned
      , issueImplementIndexedProjectionTargetLabel =
          IndexedWorkflow.indexedWorkflowPlannedTransitionTargetLabel
            @IssueImplementIndexedSpec
            planned
      , issueImplementIndexedProjectionEffectPlan =
          projectedPlan.plannedPreCommitEffects <> projectedPlan.plannedPostCommitEffects
      }

issueImplementIndexedTransitionToCompatibility
  :: IndexedWorkflow.IndexedPlannedTransition IssueImplementIndexedSpec source target
  -> PlannedTransition MoifoldSpec
issueImplementIndexedTransitionToCompatibility transition =
  PlannedTransition
    { plannedEvent = event
    , plannedPreCommitEffects = preCommitEffects
    , plannedPostCommitEffects = postCommitEffects
    }
 where
  IssueImplementIndexedEvent _sourceLabel _targetLabel event =
    IndexedWorkflow.indexedPlannedEvent transition
  IssueImplementIndexedEffectPlan preCommitEffects =
    IndexedWorkflow.indexedPlannedPreCommitEffects transition
  IssueImplementIndexedEffectPlan postCommitEffects =
    IndexedWorkflow.indexedPlannedPostCommitEffects transition
