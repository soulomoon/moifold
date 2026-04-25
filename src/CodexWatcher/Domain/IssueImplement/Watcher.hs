{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Domain.IssueImplement.Watcher
  ( IssueFinalReviewOutcome (..)
  , IssueImplementObservation (..)
  , IssueImplementTick (..)
  , issueImplementObserve
  ) where

import CodexWatcher.Effects
import CodexWatcher.EventLog.Types
import CodexWatcher.Observation
import CodexWatcher.StateMachine
import CodexWatcher.Core.Ids (BranchName, CommitSha, PrNumber, ThreadId, TurnId)
import CodexWatcher.Core.Kinds (Domain (..), ThreadActivity (..))
import CodexWatcher.Core.Reason (BlockedReason)
import CodexWatcher.Core.State (SomeWatcherState (..), WatcherState (..))
import CodexWatcher.Core.Thread (ActiveTurn (..), ReviewerThread (..), WorkerThread (..))
import CodexWatcher.Domain.PrReview.Types (CleanReviewEvidence, ReviewEvidence)
import Data.Text (Text)

data IssueFinalReviewOutcome
  = IssueFinalReviewClean CleanReviewEvidence
  | IssueFinalReviewRework ReviewEvidence
  | IssueFinalReviewIncomplete Text
  | IssueFinalReviewBlocked BlockedReason
  deriving stock (Eq, Show)

data IssueImplementObservation
  = ObservedPlanTurnStarted TurnId
  | ObservedPlanCompleted Text (Maybe TurnId)
  | ObservedIssueAttemptBranchAdvanced BranchName
  | ObservedPullRequestCreated PrNumber
  | ObservedPullRequestReused PrNumber
  | ObservedPullRequestBodyUpdated PrNumber
  | ObservedImplementationTurnStarted TurnId
  | ObservedImplementationIncomplete Text
  | ObservedImplementationBlocked BlockedReason
  | ObservedReviewHandoffInitialized PrNumber
  | ObservedReviewHandoffStarted PrNumber
  | ObservedImplementationCompleted PrNumber (Maybe ThreadId)
  | ObservedIssueReviewerThreadReady ThreadId
  | ObservedPullRequestMerged PrNumber
  | ObservedPostMergeReviewStarted CommitSha TurnId
  | ObservedPostMergeReviewerOutcome IssueFinalReviewOutcome
  | ObservedIssueClosed PrNumber
  | ObservedIssueImplementBlocked BlockedReason
  deriving stock (Eq, Show)

data IssueImplementTick = IssueImplementTick
  { issueImplementTickEvent :: WatcherEvent
  , issueImplementTickState :: SomeWatcherState
  , issueImplementTickEffects :: EffectPlan
  }
  deriving stock (Show)

issueImplementObserve :: SomeWatcherState -> IssueImplementObservation -> Either Text IssueImplementTick
issueImplementObserve (SomeWatcherState state@(IssueReadyToPlan _config _prNumber (WorkerIdle threadId))) (ObservedPlanTurnStarted turnId) =
  Right (tick (IssuePlanTurnStartedEvent turnId) (step state (StartReadyIssuePlanTurn (ActiveTurn threadId turnId))))
issueImplementObserve (SomeWatcherState state@(IssueInPlanMode _config _prNumber (WorkerActive activeTurn))) (ObservedPlanCompleted planMarkdown maybeImplementationTurnId) =
  let nextTurn = ActiveTurn (activeThreadId activeTurn) <$> maybeImplementationTurnId
   in Right (tick (IssuePlanCompletedEvent planMarkdown maybeImplementationTurnId) (step state (IssuePlanCompleted planMarkdown nextTurn)))
issueImplementObserve (SomeWatcherState state@IssueImplementationReady {}) (ObservedIssueAttemptBranchAdvanced branch) =
  Right (tick (IssueAttemptBranchAdvancedEvent branch) (step state (IssueAttemptBranchAdvanced branch)))
issueImplementObserve (SomeWatcherState state@IssueImplementationReady {}) (ObservedPullRequestCreated prNumber) =
  Right (tick (IssuePullRequestCreatedEvent prNumber) (step state (IssuePullRequestReady prNumber)))
issueImplementObserve (SomeWatcherState state@IssueImplementationReady {}) (ObservedPullRequestReused prNumber) =
  Right (tick (IssuePullRequestReusedEvent prNumber) (step state (IssuePullRequestReady prNumber)))
issueImplementObserve (SomeWatcherState state@IssueImplementing {}) (ObservedPullRequestCreated prNumber) =
  Right (tick (IssuePullRequestCreatedEvent prNumber) (step state (IssuePullRequestReady prNumber)))
issueImplementObserve (SomeWatcherState state@IssueImplementing {}) (ObservedPullRequestReused prNumber) =
  Right (tick (IssuePullRequestReusedEvent prNumber) (step state (IssuePullRequestReady prNumber)))
issueImplementObserve (SomeWatcherState state@IssueImplementationReady {}) (ObservedPullRequestBodyUpdated prNumber) =
  Right (tick (IssuePullRequestBodyUpdatedEvent prNumber) (step state (IssuePullRequestBodyUpdated prNumber)))
issueImplementObserve (SomeWatcherState state@IssuePlanReady {}) (ObservedPullRequestBodyUpdated prNumber) =
  Right (tick (IssuePullRequestBodyUpdatedEvent prNumber) (step state (IssuePullRequestBodyUpdated prNumber)))
issueImplementObserve (SomeWatcherState state@IssueImplementing {}) (ObservedPullRequestBodyUpdated prNumber) =
  Right (tick (IssuePullRequestBodyUpdatedEvent prNumber) (step state (IssuePullRequestBodyUpdated prNumber)))
issueImplementObserve (SomeWatcherState state@(IssueImplementationReady _config _maybePr (WorkerIdle threadId))) (ObservedImplementationTurnStarted turnId) =
  Right (tick (IssueImplementationTurnStartedEvent turnId) (step state (StartIssueImplementationTurn (ActiveTurn threadId turnId))))
issueImplementObserve (SomeWatcherState state@IssueImplementing {}) (ObservedImplementationIncomplete reason) =
  Right (tick (IssueImplementationIncompleteEvent reason) (step state IssueImplementationIncomplete))
issueImplementObserve (SomeWatcherState state@IssueImplementationReady {}) (ObservedImplementationBlocked reason) =
  Right (tick (IssueImplementationBlockedEvent reason) (step state (MarkBlocked reason)))
issueImplementObserve (SomeWatcherState state@IssueImplementing {}) (ObservedImplementationBlocked reason) =
  Right (tick (IssueImplementationBlockedEvent reason) (step state (MarkBlocked reason)))
issueImplementObserve (SomeWatcherState state@IssueHandoffReady {}) (ObservedReviewHandoffInitialized prNumber) =
  Right (tick (IssueReviewHandoffInitializedEvent prNumber) (step state (IssueReviewHandoffInitialized prNumber)))
issueImplementObserve (SomeWatcherState state@IssueHandoffInitialized {}) (ObservedReviewHandoffInitialized prNumber) =
  Right (tick (IssueReviewHandoffInitializedEvent prNumber) (step state (IssueReviewHandoffInitialized prNumber)))
issueImplementObserve (SomeWatcherState state@IssueWaitingForPrMerge {}) (ObservedReviewHandoffInitialized prNumber) =
  Right (tick (IssueReviewHandoffInitializedEvent prNumber) (step state (IssueReviewHandoffInitialized prNumber)))
issueImplementObserve (SomeWatcherState state@IssueHandoffInitialized {}) (ObservedReviewHandoffStarted prNumber) =
  Right (tick (IssueReviewHandoffStartedEvent prNumber) (step state (IssueReviewHandoffStarted prNumber)))
issueImplementObserve (SomeWatcherState state@IssueWaitingForPrMerge {}) (ObservedReviewHandoffStarted prNumber) =
  Right (tick (IssueReviewHandoffStartedEvent prNumber) (step state (IssueReviewHandoffStarted prNumber)))
issueImplementObserve (SomeWatcherState state@IssueImplementing {}) (ObservedImplementationCompleted prNumber maybeReviewerThreadId) =
  Right (tick (IssueImplementationCompletedEvent prNumber maybeReviewerThreadId) (step state (IssueImplementationCompleted prNumber maybeReviewerThreadId)))
issueImplementObserve (SomeWatcherState state@IssueHandoffReady {}) (ObservedImplementationCompleted prNumber maybeReviewerThreadId) =
  Right (tick (IssueImplementationCompletedEvent prNumber maybeReviewerThreadId) (step state (IssueImplementationCompleted prNumber maybeReviewerThreadId)))
issueImplementObserve (SomeWatcherState state@IssueHandoffInitialized {}) (ObservedImplementationCompleted prNumber maybeReviewerThreadId) =
  Right (tick (IssueImplementationCompletedEvent prNumber maybeReviewerThreadId) (step state (IssueImplementationCompleted prNumber maybeReviewerThreadId)))
issueImplementObserve (SomeWatcherState state@IssueWaitingForPrMerge {}) (ObservedImplementationCompleted prNumber maybeReviewerThreadId) =
  Right (tick (IssueImplementationCompletedEvent prNumber maybeReviewerThreadId) (step state (IssueImplementationCompleted prNumber maybeReviewerThreadId)))
issueImplementObserve (SomeWatcherState state@IssueHandoffReady {}) (ObservedIssueReviewerThreadReady reviewerThreadId) =
  Right (tick (IssueReviewerThreadReadyEvent reviewerThreadId) (step state (IssueReviewerThreadReady reviewerThreadId)))
issueImplementObserve (SomeWatcherState state@IssueHandoffInitialized {}) (ObservedIssueReviewerThreadReady reviewerThreadId) =
  Right (tick (IssueReviewerThreadReadyEvent reviewerThreadId) (step state (IssueReviewerThreadReady reviewerThreadId)))
issueImplementObserve (SomeWatcherState state@IssueWaitingForPrMerge {}) (ObservedIssueReviewerThreadReady reviewerThreadId) =
  Right (tick (IssueReviewerThreadReadyEvent reviewerThreadId) (step state (IssueReviewerThreadReady reviewerThreadId)))
issueImplementObserve (SomeWatcherState state@IssuePostMergeReviewReady {}) (ObservedIssueReviewerThreadReady reviewerThreadId) =
  Right (tick (IssueReviewerThreadReadyEvent reviewerThreadId) (step state (IssueReviewerThreadReady reviewerThreadId)))
issueImplementObserve (SomeWatcherState state@IssueWaitingForPrMerge {}) (ObservedPullRequestMerged prNumber) =
  Right (tick (IssuePullRequestMergedEvent prNumber) (step state (IssuePullRequestMerged prNumber)))
issueImplementObserve (SomeWatcherState state@IssuePostMergeReviewReady {}) (ObservedPostMergeReviewStarted commit turnId) =
  case state of
    IssuePostMergeReviewReady _config _prNumber _worker (Just reviewer) ->
      let activeTurn = ActiveTurn (reviewerIdleThreadId reviewer) turnId
       in Right (tick (IssuePostMergeReviewStartedEvent commit turnId) (step state (StartIssuePostMergeReview commit activeTurn)))
    IssuePostMergeReviewReady {} ->
      Left "cannot start post-merge reviewer without reviewer thread"
issueImplementObserve (SomeWatcherState state@IssuePostMergeReviewing {}) (ObservedPostMergeReviewerOutcome outcome) =
  case outcome of
    IssueFinalReviewClean evidence ->
      Right (tick (IssuePostMergeReviewCleanEvent evidence) (step state (IssuePostMergeReviewSatisfied evidence)))
    IssueFinalReviewRework evidence ->
      Right (tick (IssuePostMergeReviewFollowUpEvent evidence) (step state (IssuePostMergeReviewFollowUp evidence)))
    IssueFinalReviewIncomplete reason ->
      Right (tick (IssuePostMergeReviewIncompleteEvent reason) (step state (IssuePostMergeReviewIncomplete reason)))
    IssueFinalReviewBlocked reason ->
      Right (tick (WatcherBlocked reason) (step state (MarkBlocked reason)))
issueImplementObserve (SomeWatcherState state@IssueWaitingForIssueClose {}) (ObservedIssueClosed prNumber) =
  Right (tick (IssueClosedEvent prNumber) (step state (IssueClosed prNumber)))
issueImplementObserve (SomeWatcherState state@IssueReadyToPlan {}) (ObservedIssueImplementBlocked reason) =
  Right (tick (WatcherBlocked reason) (step state (MarkBlocked reason)))
issueImplementObserve (SomeWatcherState state@IssuePlanReady {}) (ObservedIssueImplementBlocked reason) =
  Right (tick (WatcherBlocked reason) (step state (MarkBlocked reason)))
issueImplementObserve (SomeWatcherState state@IssueInPlanMode {}) (ObservedIssueImplementBlocked reason) =
  Right (tick (WatcherBlocked reason) (step state (MarkBlocked reason)))
issueImplementObserve (SomeWatcherState state@IssueImplementationReady {}) (ObservedIssueImplementBlocked reason) =
  Right (tick (WatcherBlocked reason) (step state (MarkBlocked reason)))
issueImplementObserve (SomeWatcherState state@IssueImplementing {}) (ObservedIssueImplementBlocked reason) =
  Right (tick (WatcherBlocked reason) (step state (MarkBlocked reason)))
issueImplementObserve (SomeWatcherState state@IssueHandoffReady {}) (ObservedIssueImplementBlocked reason) =
  Right (tick (WatcherBlocked reason) (step state (MarkBlocked reason)))
issueImplementObserve (SomeWatcherState state@IssueHandoffInitialized {}) (ObservedIssueImplementBlocked reason) =
  Right (tick (WatcherBlocked reason) (step state (MarkBlocked reason)))
issueImplementObserve (SomeWatcherState state@IssueWaitingForPrMerge {}) (ObservedIssueImplementBlocked reason) =
  Right (tick (WatcherBlocked reason) (step state (MarkBlocked reason)))
issueImplementObserve (SomeWatcherState state@IssuePostMergeReviewReady {}) (ObservedIssueImplementBlocked reason) =
  Right (tick (WatcherBlocked reason) (step state (MarkBlocked reason)))
issueImplementObserve (SomeWatcherState state@IssuePostMergeReviewing {}) (ObservedIssueImplementBlocked reason) =
  Right (tick (WatcherBlocked reason) (step state (MarkBlocked reason)))
issueImplementObserve (SomeWatcherState state@IssueWaitingForIssueClose {}) (ObservedIssueImplementBlocked reason) =
  Right (tick (WatcherBlocked reason) (step state (MarkBlocked reason)))
issueImplementObserve state observation =
  invalidObservation "issue implementation observation" state observation

tick :: WatcherEvent -> Decision 'IssueImplement -> IssueImplementTick
tick event decision =
  fromObservedTick (observedFromDecision event decision)

fromObservedTick :: ObservedTick -> IssueImplementTick
fromObservedTick observed =
  IssueImplementTick
    { issueImplementTickEvent = observed.observedEvent
    , issueImplementTickState = observed.observedState
    , issueImplementTickEffects = observed.observedEffects
    }

reviewerIdleThreadId :: ReviewerThread 'Idle -> ThreadId
reviewerIdleThreadId (ReviewerIdle threadId) = threadId
