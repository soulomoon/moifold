{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Workflow.Moifold.PrReview
  ( PrReviewCheckingObservation (..)
  , observePrReviewChecking
  , unresolvedReviewEvidence
  ) where

import CodexWatcher.GhGit (ReviewComment (..), ReviewThread (..), ReviewThreadsReport (..))
import CodexWatcher.Observation (ObservedTick, invalidObservation, observedFromDecision)
import CodexWatcher.StateMachine (Event (..), step)
import CodexWatcher.Core.Ids (CommitSha, ReviewThreadId (..), ThreadId, TurnId)
import CodexWatcher.Core.Kinds (Domain (..), Phase (..))
import CodexWatcher.Core.State (SomeWatcherState (..), WatcherState (..))
import CodexWatcher.Core.Thread (ActiveTurn (..), ReviewerThread (..), WorkerThread (..))
import CodexWatcher.Domain.PrReview.Types
  ( ReviewEvidence
  , reviewEvidenceFromThreadCommentRefs
  , reviewEvidenceFromThreads
  )
import CodexWatcher.EventLog.Types (WatcherEvent (..))
import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)
import Data.Text qualified as Text

data PrReviewCheckingObservation
  = CheckingObservedReviewThreads ReviewThreadsReport CommitSha TurnId
  | CheckingObservedReviewFeedback ReviewEvidence TurnId
  | CheckingObservedReviewFixVerificationStarted CommitSha TurnId
  deriving stock (Eq, Show)

observePrReviewChecking :: SomeWatcherState -> PrReviewCheckingObservation -> Either Text ObservedTick
observePrReviewChecking (SomeWatcherState state@PrCheckingReviews {}) (CheckingObservedReviewThreads report commit turnId) =
  case unresolvedThreadIds report of
    Just threadIds ->
      case state of
        PrCheckingReviews _config (WorkerIdle workerThread) _reviewer ->
          let event = PrReviewUnresolvedFound threadIds commit turnId
              evidence = unresolvedReviewEvidenceOrThreadIds report threadIds commit
              decision = step state (ReviewThreadsFound evidence (ActiveTurn workerThread turnId))
           in Right (observedFromDecision event decision)
    Nothing ->
      case state of
        PrCheckingReviews _config _worker (ReviewerIdle reviewerThread) ->
          let event = PrReviewNoUnresolvedFound commit turnId
              decision = step state (NoReviewThreadsFound commit (ActiveTurn reviewerThread turnId))
           in Right (observedFromDecision event decision)
observePrReviewChecking (SomeWatcherState state@PrCheckingReviews {}) (CheckingObservedReviewFeedback evidence turnId) =
  Right (reviewFeedbackObservedTick state evidence turnId)
observePrReviewChecking (SomeWatcherState state@PrReviewFixQueued {}) (CheckingObservedReviewFeedback evidence turnId) =
  Right (reviewFeedbackObservedTick state evidence turnId)
observePrReviewChecking (SomeWatcherState state@PrVerifyingReviewFix {}) (CheckingObservedReviewFeedback evidence turnId) =
  Right (reviewFeedbackObservedTick state evidence turnId)
observePrReviewChecking (SomeWatcherState state@PrVerifyingReviewFix {}) (CheckingObservedReviewFixVerificationStarted reviewTargetSha turnId) =
  case state of
    PrVerifyingReviewFix _config evidence _worker (ReviewerIdle reviewerThread) ->
      let event = PrReviewFixVerificationStarted evidence reviewTargetSha turnId
          decision = step state (StartReviewFixVerification reviewTargetSha (ActiveTurn reviewerThread turnId))
       in Right (observedFromDecision event decision)
observePrReviewChecking state observation =
  invalidObservation "PR review checking observation" state observation

reviewFeedbackObservedTick :: WatcherState 'PrReview 'CheckingReviews -> ReviewEvidence -> TurnId -> ObservedTick
reviewFeedbackObservedTick state evidence turnId =
  case state of
    PrCheckingReviews _config (WorkerIdle workerThread) _reviewer ->
      reviewFeedbackObservedTickWithWorker state evidence workerThread turnId
    PrReviewFixQueued _config _queuedEvidence (WorkerIdle workerThread) _reviewer ->
      reviewFeedbackObservedTickWithWorker state evidence workerThread turnId
    PrVerifyingReviewFix _config _oldEvidence (WorkerIdle workerThread) _reviewer ->
      reviewFeedbackObservedTickWithWorker state evidence workerThread turnId

reviewFeedbackObservedTickWithWorker :: WatcherState 'PrReview 'CheckingReviews -> ReviewEvidence -> ThreadId -> TurnId -> ObservedTick
reviewFeedbackObservedTickWithWorker state evidence workerThread turnId =
  let event = PrReviewFeedbackFound evidence turnId
      decision = step state (ReviewThreadsFound evidence (ActiveTurn workerThread turnId))
   in observedFromDecision event decision

unresolvedThreadIds :: ReviewThreadsReport -> Maybe (NonEmpty ReviewThreadId)
unresolvedThreadIds report =
  case fmap reviewThreadId report.unresolvedReviewThreads of
    [] -> Nothing
    first : rest -> Just (first :| rest)

unresolvedReviewEvidence :: ReviewThreadsReport -> CommitSha -> Maybe ReviewEvidence
unresolvedReviewEvidence report commit =
  case [(thread.reviewThreadId, thread.reviewThreadUrl, reviewThreadSummary thread) | thread <- report.unresolvedReviewThreads] of
    [] -> Nothing
    first : rest -> Just (reviewEvidenceFromThreadCommentRefs (first :| rest) commit)

unresolvedReviewEvidenceOrThreadIds :: ReviewThreadsReport -> NonEmpty ReviewThreadId -> CommitSha -> ReviewEvidence
unresolvedReviewEvidenceOrThreadIds report threadIds commit =
  case unresolvedReviewEvidence report commit of
    Just evidence -> evidence
    Nothing -> reviewEvidenceFromThreads threadIds commit

reviewThreadSummary :: ReviewThread -> Text
reviewThreadSummary thread =
  Text.strip (Text.intercalate " | " (locationText thread : commentTexts))
 where
  locationText value =
    case (value.reviewThreadPath, value.reviewThreadLine, value.reviewThreadStartLine) of
      (Just path, Just line, _) -> path <> ":" <> Text.pack (show line)
      (Just path, Nothing, Just startLine) -> path <> ":" <> Text.pack (show startLine)
      (Just path, Nothing, Nothing) -> path
      _ -> "unresolved review thread"
  commentTexts =
    [ maybe "" (<> ": ") comment.reviewCommentAuthorLogin <> Text.strip comment.reviewCommentBody
    | comment <- thread.reviewThreadComments
    , not (Text.null (Text.strip comment.reviewCommentBody))
    ]
