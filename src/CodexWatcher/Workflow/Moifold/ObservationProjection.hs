{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Workflow.Moifold.ObservationProjection
  ( MoifoldObservedProjection (..)
  , projectMoifoldObservation
  ) where

import CodexWatcher.Core.State (SomeWatcherState (..), WatcherState (..))
import CodexWatcher.Domain.IssueImplement.Watcher (IssueFinalReviewOutcome (..), IssueImplementObservation (..))
import CodexWatcher.Domain.IssuePlanning.Watcher (IssuePlanningObservation (..))
import CodexWatcher.Domain.PrReview.Watcher (PrReviewObservation (..))
import CodexWatcher.Workflow.Moifold.IssueImplement.Indexed qualified as WorkflowIssueImplementIndexed
import CodexWatcher.Workflow.Moifold.IssuePlanning.Indexed qualified as WorkflowIssuePlanningIndexed
import CodexWatcher.Workflow.Moifold.PrReview.Mergeability.Indexed qualified as WorkflowPrReviewMergeabilityIndexed
import CodexWatcher.Workflow.Observation (DaemonObservation (..), ObservedPolicyTick (..), observeDaemonState)
import CodexWatcher.Workflow.Spec (PlannedTransition)
import CodexWatcher.Workflow.Types (MoifoldSpec, legacyObservedPlannedTransition)
import Data.Text (Text)

data MoifoldObservedProjection = MoifoldObservedProjection
  { moifoldObservedProjectionPlanned :: PlannedTransition MoifoldSpec
  , moifoldObservedProjectionFinalState :: SomeWatcherState
  }

projectMoifoldObservation
  :: SomeWatcherState
  -> DaemonObservation
  -> Either Text MoifoldObservedProjection
projectMoifoldObservation state observation =
  case (state, observation) of
    (SomeWatcherState PlanningReady {}, DaemonIssuePlanningObservation (ObservedPlanningTurnStarted threadId turnId)) -> do
      projected <-
        WorkflowIssuePlanningIndexed.projectIssuePlanningTurnStartedObservation
          state
          threadId
          turnId
      pure (fromIssuePlanningProjection projected)
    (SomeWatcherState PlanningTurnActive {}, DaemonIssuePlanningObservation (ObservedPlanningIssuesRequested requests)) -> do
      projected <-
        WorkflowIssuePlanningIndexed.projectIssuePlanningIssuesRequestedObservation
          state
          requests
      pure (fromIssuePlanningProjection projected)
    (SomeWatcherState PlanningTurnActive {}, DaemonIssuePlanningObservation (ObservedPlanningGraphUpdated graph)) -> do
      projected <-
        WorkflowIssuePlanningIndexed.projectIssuePlanningGraphUpdatedObservation
          state
          graph
      pure (fromIssuePlanningProjection projected)
    (SomeWatcherState PlanningWaitingForReadyIssues {}, DaemonIssuePlanningObservation ObservedPlanningReadyIssuesFixed) -> do
      projected <-
        WorkflowIssuePlanningIndexed.projectIssuePlanningReadyIssuesFixedObservation
          state
      pure (fromIssuePlanningProjection projected)
    (SomeWatcherState PlanningReady {}, DaemonIssuePlanningObservation ObservedPlanningScopeCompleted) -> do
      projected <-
        WorkflowIssuePlanningIndexed.projectIssuePlanningScopeCompletedObservation
          state
      pure (fromIssuePlanningProjection projected)
    (SomeWatcherState PlanningTurnActive {}, DaemonIssuePlanningObservation (ObservedPlanningTurnRetryRequested reason)) -> do
      projected <-
        WorkflowIssuePlanningIndexed.projectIssuePlanningTurnRetryObservation
          state
          reason
      pure (fromIssuePlanningProjection projected)
    (SomeWatcherState PlanningTurnActive {}, DaemonIssuePlanningObservation ObservedPlanningTurnCompleted) -> do
      projected <-
        WorkflowIssuePlanningIndexed.projectIssuePlanningTurnCompletedObservation
          state
      pure (fromIssuePlanningProjection projected)
    (SomeWatcherState PlanningReady {}, DaemonIssuePlanningObservation (ObservedPlanningBlocked reason)) -> do
      projected <-
        WorkflowIssuePlanningIndexed.projectIssuePlanningBlockedInitializedObservation
          state
          reason
      pure (fromIssuePlanningProjection projected)
    (SomeWatcherState PlanningTurnActive {}, DaemonIssuePlanningObservation (ObservedPlanningBlocked reason)) -> do
      projected <-
        WorkflowIssuePlanningIndexed.projectIssuePlanningBlockedActiveTurnObservation
          state
          reason
      pure (fromIssuePlanningProjection projected)
    (SomeWatcherState PlanningWaitingForReadyIssues {}, DaemonIssuePlanningObservation (ObservedPlanningBlocked reason)) -> do
      projected <-
        WorkflowIssuePlanningIndexed.projectIssuePlanningBlockedWaitingReadyIssuesObservation
          state
          reason
      pure (fromIssuePlanningProjection projected)
    (SomeWatcherState IssueReadyToPlan {}, DaemonIssueImplementObservation (ObservedPlanTurnStarted turnId)) -> do
      projected <-
        WorkflowIssueImplementIndexed.projectIssueImplementPlanTurnStartedObservation
          state
          turnId
      pure (fromIssueImplementProjection projected)
    (SomeWatcherState IssueInPlanMode {}, DaemonIssueImplementObservation (ObservedPlanCompleted planMarkdown maybeImplementationTurnId)) -> do
      projected <-
        WorkflowIssueImplementIndexed.projectIssueImplementPlanCompletedObservation
          state
          planMarkdown
          maybeImplementationTurnId
      pure (fromIssueImplementProjection projected)
    (SomeWatcherState IssueReadyToPlan {}, DaemonIssueImplementObservation (ObservedIssueWorkerThreadRefreshed threadId)) -> do
      projected <-
        WorkflowIssueImplementIndexed.projectIssueImplementWorkerThreadRefreshedReadyToPlanObservation
          state
          threadId
      pure (fromIssueImplementProjection projected)
    (SomeWatcherState IssueImplementationReady {}, DaemonIssueImplementObservation (ObservedIssueAttemptBranchAdvanced branch)) -> do
      projected <-
        WorkflowIssueImplementIndexed.projectIssueImplementAttemptBranchAdvancedObservation
          state
          branch
      pure (fromIssueImplementProjection projected)
    (SomeWatcherState IssueImplementationReady {}, DaemonIssueImplementObservation (ObservedPullRequestCreated prNumber)) -> do
      projected <-
        WorkflowIssueImplementIndexed.projectIssueImplementPullRequestCreatedImplementationReadyObservation
          state
          prNumber
      pure (fromIssueImplementProjection projected)
    (SomeWatcherState IssueImplementationReady {}, DaemonIssueImplementObservation (ObservedPullRequestReused prNumber)) -> do
      projected <-
        WorkflowIssueImplementIndexed.projectIssueImplementPullRequestReusedImplementationReadyObservation
          state
          prNumber
      pure (fromIssueImplementProjection projected)
    (SomeWatcherState IssuePlanReady {}, DaemonIssueImplementObservation (ObservedPullRequestBodyUpdated prNumber)) -> do
      projected <-
        WorkflowIssueImplementIndexed.projectIssueImplementPullRequestBodyUpdatedPlanReadyObservation
          state
          prNumber
      pure (fromIssueImplementProjection projected)
    (SomeWatcherState IssueImplementationReady {}, DaemonIssueImplementObservation (ObservedIssueWorkerThreadRefreshed threadId)) -> do
      projected <-
        WorkflowIssueImplementIndexed.projectIssueImplementWorkerThreadRefreshedImplementationReadyObservation
          state
          threadId
      pure (fromIssueImplementProjection projected)
    (SomeWatcherState IssueImplementationReady {}, DaemonIssueImplementObservation (ObservedImplementationTurnStarted turnId)) -> do
      projected <-
        WorkflowIssueImplementIndexed.projectIssueImplementationTurnStartedObservation
          state
          turnId
      pure (fromIssueImplementProjection projected)
    (SomeWatcherState IssueImplementationReady {}, DaemonIssueImplementObservation (ObservedImplementationBlocked reason)) -> do
      projected <-
        WorkflowIssueImplementIndexed.projectIssueImplementationBlockedImplementationReadyObservation
          state
          reason
      pure (fromIssueImplementProjection projected)
    (SomeWatcherState IssueImplementing {}, DaemonIssueImplementObservation (ObservedImplementationIncomplete reason)) -> do
      projected <-
        WorkflowIssueImplementIndexed.projectIssueImplementationIncompleteObservation
          state
          reason
      pure (fromIssueImplementProjection projected)
    (SomeWatcherState IssueImplementing {}, DaemonIssueImplementObservation (ObservedImplementationBlocked reason)) -> do
      projected <-
        WorkflowIssueImplementIndexed.projectIssueImplementationBlockedImplementingObservation
          state
          reason
      pure (fromIssueImplementProjection projected)
    (SomeWatcherState IssueImplementing {}, DaemonIssueImplementObservation (ObservedImplementationCompleted prNumber maybeReviewerThreadId)) -> do
      projected <-
        WorkflowIssueImplementIndexed.projectIssueImplementationCompletedImplementingObservation
          state
          prNumber
          maybeReviewerThreadId
      pure (fromIssueImplementProjection projected)
    (SomeWatcherState IssueHandoffReady {}, DaemonIssueImplementObservation (ObservedReviewHandoffInitialized prNumber)) -> do
      projected <-
        WorkflowIssueImplementIndexed.projectIssueImplementReviewHandoffInitializedHandoffReadyObservation
          state
          prNumber
      pure (fromIssueImplementProjection projected)
    (SomeWatcherState IssueHandoffInitialized {}, DaemonIssueImplementObservation (ObservedReviewHandoffInitialized prNumber)) -> do
      projected <-
        WorkflowIssueImplementIndexed.projectIssueImplementReviewHandoffInitializedHandoffInitializedObservation
          state
          prNumber
      pure (fromIssueImplementProjection projected)
    (SomeWatcherState IssueWaitingForPrMerge {}, DaemonIssueImplementObservation (ObservedReviewHandoffInitialized prNumber)) -> do
      projected <-
        WorkflowIssueImplementIndexed.projectIssueImplementReviewHandoffInitializedWaitingForPrMergeObservation
          state
          prNumber
      pure (fromIssueImplementProjection projected)
    (SomeWatcherState IssueHandoffInitialized {}, DaemonIssueImplementObservation (ObservedReviewHandoffStarted prNumber)) -> do
      projected <-
        WorkflowIssueImplementIndexed.projectIssueImplementReviewHandoffStartedHandoffInitializedObservation
          state
          prNumber
      pure (fromIssueImplementProjection projected)
    (SomeWatcherState IssueWaitingForPrMerge {}, DaemonIssueImplementObservation (ObservedReviewHandoffStarted prNumber)) -> do
      projected <-
        WorkflowIssueImplementIndexed.projectIssueImplementReviewHandoffStartedWaitingForPrMergeObservation
          state
          prNumber
      pure (fromIssueImplementProjection projected)
    (SomeWatcherState IssueHandoffReady {}, DaemonIssueImplementObservation (ObservedImplementationCompleted prNumber maybeReviewerThreadId)) -> do
      projected <-
        WorkflowIssueImplementIndexed.projectIssueImplementationCompletedHandoffReadyObservation
          state
          prNumber
          maybeReviewerThreadId
      pure (fromIssueImplementProjection projected)
    (SomeWatcherState IssueHandoffInitialized {}, DaemonIssueImplementObservation (ObservedImplementationCompleted prNumber maybeReviewerThreadId)) -> do
      projected <-
        WorkflowIssueImplementIndexed.projectIssueImplementationCompletedHandoffInitializedObservation
          state
          prNumber
          maybeReviewerThreadId
      pure (fromIssueImplementProjection projected)
    (SomeWatcherState IssueWaitingForPrMerge {}, DaemonIssueImplementObservation (ObservedImplementationCompleted prNumber maybeReviewerThreadId)) -> do
      projected <-
        WorkflowIssueImplementIndexed.projectIssueImplementationCompletedWaitingForPrMergeObservation
          state
          prNumber
          maybeReviewerThreadId
      pure (fromIssueImplementProjection projected)
    (SomeWatcherState IssueHandoffReady {}, DaemonIssueImplementObservation (ObservedIssueReviewerThreadReady threadId)) -> do
      projected <-
        WorkflowIssueImplementIndexed.projectIssueImplementReviewerThreadReadyHandoffReadyObservation
          state
          threadId
      pure (fromIssueImplementProjection projected)
    (SomeWatcherState IssueHandoffInitialized {}, DaemonIssueImplementObservation (ObservedIssueReviewerThreadReady threadId)) -> do
      projected <-
        WorkflowIssueImplementIndexed.projectIssueImplementReviewerThreadReadyHandoffInitializedObservation
          state
          threadId
      pure (fromIssueImplementProjection projected)
    (SomeWatcherState IssueWaitingForPrMerge {}, DaemonIssueImplementObservation (ObservedIssueReviewerThreadReady threadId)) -> do
      projected <-
        WorkflowIssueImplementIndexed.projectIssueImplementReviewerThreadReadyWaitingForPrMergeObservation
          state
          threadId
      pure (fromIssueImplementProjection projected)
    (SomeWatcherState IssuePostMergeReviewPendingReviewer {}, DaemonIssueImplementObservation (ObservedIssueReviewerThreadReady threadId)) -> do
      projected <-
        WorkflowIssueImplementIndexed.projectIssueImplementReviewerThreadReadyPostMergeReviewPendingReviewerObservation
          state
          threadId
      pure (fromIssueImplementProjection projected)
    (SomeWatcherState IssuePostMergeReviewReady {}, DaemonIssueImplementObservation (ObservedIssueReviewerThreadReady threadId)) -> do
      projected <-
        WorkflowIssueImplementIndexed.projectIssueImplementReviewerThreadReadyPostMergeReviewReadyObservation
          state
          threadId
      pure (fromIssueImplementProjection projected)
    (SomeWatcherState IssueWaitingForPrMerge {}, DaemonIssueImplementObservation (ObservedPullRequestMerged prNumber)) -> do
      projected <-
        WorkflowIssueImplementIndexed.projectIssueImplementPullRequestMergedWaitingForPrMergeObservation
          state
          prNumber
      pure (fromIssueImplementProjection projected)
    (SomeWatcherState IssuePostMergeReviewReady {}, DaemonIssueImplementObservation (ObservedPostMergeReviewStarted commit turnId)) -> do
      projected <-
        WorkflowIssueImplementIndexed.projectIssueImplementPostMergeReviewStartedObservation
          state
          commit
          turnId
      pure (fromIssueImplementProjection projected)
    (SomeWatcherState IssuePostMergeReviewing {}, DaemonIssueImplementObservation (ObservedPostMergeReviewerOutcome (IssueFinalReviewClean evidence))) -> do
      projected <-
        WorkflowIssueImplementIndexed.projectIssueImplementPostMergeReviewerOutcomeCleanObservation
          state
          evidence
      pure (fromIssueImplementProjection projected)
    (SomeWatcherState IssuePostMergeReviewing {}, DaemonIssueImplementObservation (ObservedPostMergeReviewerOutcome (IssueFinalReviewRework evidence))) -> do
      projected <-
        WorkflowIssueImplementIndexed.projectIssueImplementPostMergeReviewerOutcomeReworkObservation
          state
          evidence
      pure (fromIssueImplementProjection projected)
    (SomeWatcherState IssuePostMergeReviewing {}, DaemonIssueImplementObservation (ObservedPostMergeReviewerOutcome (IssueFinalReviewIncomplete reason))) -> do
      projected <-
        WorkflowIssueImplementIndexed.projectIssueImplementPostMergeReviewerOutcomeIncompleteObservation
          state
          reason
      pure (fromIssueImplementProjection projected)
    (SomeWatcherState IssuePostMergeReviewing {}, DaemonIssueImplementObservation (ObservedPostMergeReviewerOutcome (IssueFinalReviewBlocked reason))) -> do
      projected <-
        WorkflowIssueImplementIndexed.projectIssueImplementPostMergeReviewerOutcomeBlockedObservation
          state
          reason
      pure (fromIssueImplementProjection projected)
    (SomeWatcherState IssueWaitingForIssueClose {}, DaemonIssueImplementObservation (ObservedIssueClosed prNumber)) -> do
      projected <-
        WorkflowIssueImplementIndexed.projectIssueImplementIssueClosedObservation
          state
          prNumber
      pure (fromIssueImplementProjection projected)
    (SomeWatcherState PrWaitingForMergeability {}, DaemonPrReviewObservation (ObservedMergeabilityClean commit)) -> do
      projected <-
        WorkflowPrReviewMergeabilityIndexed.projectPrReviewMergeabilityCleanObservation
          state
          commit
      pure
        MoifoldObservedProjection
          { moifoldObservedProjectionPlanned =
              projected.prReviewMergeabilityIndexedProjectionPlanned
          , moifoldObservedProjectionFinalState =
              projected.prReviewMergeabilityIndexedProjectionFinalState
          }
    _ -> do
      observed <- observeDaemonState state observation
      pure
        MoifoldObservedProjection
          { moifoldObservedProjectionPlanned =
              legacyObservedPlannedTransition observed
          , moifoldObservedProjectionFinalState = observed.observedState
          }

fromIssuePlanningProjection
  :: WorkflowIssuePlanningIndexed.IssuePlanningIndexedProjection
  -> MoifoldObservedProjection
fromIssuePlanningProjection projected =
  MoifoldObservedProjection
    { moifoldObservedProjectionPlanned =
        projected.issuePlanningIndexedProjectionPlanned
    , moifoldObservedProjectionFinalState =
        projected.issuePlanningIndexedProjectionFinalState
    }

fromIssueImplementProjection
  :: WorkflowIssueImplementIndexed.IssueImplementIndexedProjection
  -> MoifoldObservedProjection
fromIssueImplementProjection projected =
  MoifoldObservedProjection
    { moifoldObservedProjectionPlanned =
        projected.issueImplementIndexedProjectionPlanned
    , moifoldObservedProjectionFinalState =
        projected.issueImplementIndexedProjectionFinalState
    }
