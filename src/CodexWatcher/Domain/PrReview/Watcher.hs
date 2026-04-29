{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Domain.PrReview.Watcher
  ( PrReviewObservation (..)
  , PrReviewTick (..)
  , prReviewObserve
  , unresolvedReviewEvidence
  ) where

import CodexWatcher.Effects
import CodexWatcher.EventLog.Types
import CodexWatcher.GhGit
import CodexWatcher.Observation
import CodexWatcher.Domain.PrReview.Protocol
import CodexWatcher.StateMachine
import CodexWatcher.Core.Ids (CommitSha, ReviewThreadId (..), TurnId)
import CodexWatcher.Core.Kinds (Domain (..), Phase (..))
import CodexWatcher.Core.Reason (BlockedReason)
import CodexWatcher.Core.State (SomeWatcherState (..), WatcherState (..))
import CodexWatcher.Core.Thread (ActiveTurn (..), ReviewerThread (..), WorkerThread (..))
import CodexWatcher.Domain.PrReview.Types
  ( CleanReviewEvidence (..)
  , MergeCommit
  , ReviewEvidence (..)
  , reviewEvidenceFromThreadCommentRefs
  , reviewEvidenceFromThreads
  , reviewEvidenceThreadIds
  )
import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)
import Data.Text qualified as Text

data PrReviewObservation
  = ObservedReviewThreads ReviewThreadsReport CommitSha TurnId
  | ObservedReviewFeedback ReviewEvidence TurnId
  | ObservedReviewFixVerificationStarted CommitSha TurnId
  | ObservedWorkerOutcome WorkerOutcome
  | ObservedReviewerOutcome ReviewerOutcome
  | ObservedMergeabilityClean CommitSha
  | ObservedMergeabilityRetry Text
  | ObservedMergeabilityRecheck Text
  | ObservedMergeabilityFixRequired ReviewEvidence
  | ObservedMergeCompleted MergeCommit
  | ObservedPrReviewBlocked BlockedReason
  deriving stock (Eq, Show)

data PrReviewTick = PrReviewTick
  { prReviewTickEvent :: WatcherEvent
  , prReviewTickState :: SomeWatcherState
  , prReviewTickEffects :: EffectPlan
  }
  deriving stock (Show)

prReviewObserve :: SomeWatcherState -> PrReviewObservation -> Either Text PrReviewTick
prReviewObserve (SomeWatcherState state@PrCheckingReviews {}) (ObservedReviewThreads report commit turnId) =
  case unresolvedThreadIds report of
    Just threadIds ->
      case state of
        PrCheckingReviews _config (WorkerIdle workerThread) _reviewer ->
          let event = PrReviewUnresolvedFound threadIds commit turnId
              evidence = unresolvedReviewEvidenceOrThreadIds report threadIds commit
              decision = step state (ReviewThreadsFound evidence (ActiveTurn workerThread turnId))
           in Right (tick event decision)
    Nothing ->
      case state of
        PrCheckingReviews _config _worker (ReviewerIdle reviewerThread) ->
          let event = PrReviewNoUnresolvedFound commit turnId
              decision = step state (NoReviewThreadsFound commit (ActiveTurn reviewerThread turnId))
           in Right (tick event decision)
prReviewObserve (SomeWatcherState state@PrCheckingReviews {}) (ObservedReviewFeedback evidence turnId) =
  case state of
    PrCheckingReviews _config (WorkerIdle workerThread) _reviewer ->
      let event = PrReviewFeedbackFound evidence turnId
          decision = step state (ReviewThreadsFound evidence (ActiveTurn workerThread turnId))
       in Right (tick event decision)
prReviewObserve (SomeWatcherState state@PrReviewFixQueued {}) (ObservedReviewFeedback evidence turnId) =
  case state of
    PrReviewFixQueued _config _queuedEvidence (WorkerIdle workerThread) _reviewer ->
      let event = PrReviewFeedbackFound evidence turnId
          decision = step state (ReviewThreadsFound evidence (ActiveTurn workerThread turnId))
       in Right (tick event decision)
prReviewObserve (SomeWatcherState state@PrVerifyingReviewFix {}) (ObservedReviewFeedback evidence turnId) =
  case state of
    PrVerifyingReviewFix _config _oldEvidence (WorkerIdle workerThread) _reviewer ->
      let event = PrReviewFeedbackFound evidence turnId
          decision = step state (ReviewThreadsFound evidence (ActiveTurn workerThread turnId))
       in Right (tick event decision)
prReviewObserve (SomeWatcherState state@PrFixingReviews {}) (ObservedWorkerOutcome outcome) =
  case outcome of
    WorkerCompleted ->
      Right (tick PrReviewFixCompleted (step state ReviewFixCompleted))
    WorkerIncomplete reason ->
      Right (tick (PrReviewFixIncomplete reason) (step state ReviewFixIncomplete))
    WorkerBlocked reason ->
      Right (tick (WatcherBlocked reason) (step state (MarkBlocked reason)))
prReviewObserve (SomeWatcherState state@PrVerifyingReviewFix {}) (ObservedReviewFixVerificationStarted reviewTargetSha turnId) =
  case state of
    PrVerifyingReviewFix _config evidence _worker (ReviewerIdle reviewerThread) ->
      let event = PrReviewFixVerificationStarted evidence reviewTargetSha turnId
          decision = step state (StartReviewFixVerification reviewTargetSha (ActiveTurn reviewerThread turnId))
       in Right (tick event decision)
prReviewObserve (SomeWatcherState state@PrReviewingClean {}) (ObservedReviewerOutcome outcome) =
  case verifyReviewerOutcome state outcome of
    ReviewerClean evidence resolvedThreadIds ->
      Right (tick (PrReviewCleanFound evidence resolvedThreadIds) (step state (ReviewerFoundClean evidence resolvedThreadIds)))
    ReviewerProblemsAdded evidence resolvedThreadIds ->
      Right (tick (PrReviewProblemsAdded evidence resolvedThreadIds) (step state (ReviewerFoundProblems evidence resolvedThreadIds)))
    ReviewerIncomplete reason ->
      Right (tick (PrReviewReviewIncomplete reason) (step state ReviewerTurnIncomplete))
    ReviewerBlocked reason ->
      Right (tick (WatcherBlocked reason) (step state (MarkBlocked reason)))
prReviewObserve (SomeWatcherState state@PrWaitingForMergeability {}) (ObservedMergeabilityClean commitSha) =
  case state of
    PrWaitingForMergeability _config evidence _worker _reviewer
      | cleanReviewCommit evidence == commitSha ->
          Right (tick (PrReviewMergeabilityClean commitSha) (step state MergeabilityClean))
      | otherwise ->
          Left "mergeability clean commit does not match reviewed commit"
prReviewObserve (SomeWatcherState state@PrWaitingForMergeability {}) (ObservedMergeabilityRetry reason) =
  Right (tick (PrReviewMergeabilityWaiting reason) (step state (MergeabilityRetryLater reason)))
prReviewObserve (SomeWatcherState state@PrWaitingForMergeability {}) (ObservedMergeabilityRecheck reason) =
  Right (tick (PrReviewMergeabilityRecheck reason) (step state (MergeabilityRecheckReviews reason)))
prReviewObserve (SomeWatcherState state@PrWaitingForMergeability {}) (ObservedMergeabilityFixRequired evidence) =
  Right (tick (PrReviewMergeabilityFixRequired evidence) (step state (MergeabilityFixRequired evidence)))
prReviewObserve (SomeWatcherState state@PrMerging {}) (ObservedMergeCompleted mergeCommit) =
  Right (tick (PrReviewMergeCompleted mergeCommit) (step state (MergeCompleted mergeCommit)))
prReviewObserve (SomeWatcherState state@PrCheckingReviews {}) (ObservedPrReviewBlocked reason) =
  Right (tick (WatcherBlocked reason) (step state (MarkBlocked reason)))
prReviewObserve (SomeWatcherState state@PrFixingReviews {}) (ObservedPrReviewBlocked reason) =
  Right (tick (WatcherBlocked reason) (step state (MarkBlocked reason)))
prReviewObserve (SomeWatcherState state@PrVerifyingReviewFix {}) (ObservedPrReviewBlocked reason) =
  Right (tick (WatcherBlocked reason) (step state (MarkBlocked reason)))
prReviewObserve (SomeWatcherState state@PrReviewingClean {}) (ObservedPrReviewBlocked reason) =
  Right (tick (WatcherBlocked reason) (step state (MarkBlocked reason)))
prReviewObserve (SomeWatcherState state@PrWaitingForMergeability {}) (ObservedPrReviewBlocked reason) =
  Right (tick (WatcherBlocked reason) (step state (MarkBlocked reason)))
prReviewObserve (SomeWatcherState state@PrMerging {}) (ObservedPrReviewBlocked reason) =
  Right (tick (WatcherBlocked reason) (step state (MarkBlocked reason)))
prReviewObserve state observation =
  invalidObservation "PR review observation" state observation

tick :: WatcherEvent -> Decision 'PrReview -> PrReviewTick
tick event decision =
  fromObservedTick (observedFromDecision event decision)

fromObservedTick :: ObservedTick -> PrReviewTick
fromObservedTick observed =
  PrReviewTick
    { prReviewTickEvent = observed.observedEvent
    , prReviewTickState = observed.observedState
    , prReviewTickEffects = observed.observedEffects
    }

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

verifyReviewerOutcome :: WatcherState 'PrReview 'ReviewingClean -> ReviewerOutcome -> ReviewerOutcome
verifyReviewerOutcome (PrReviewingClean _config _commit (Just evidence) _worker _reviewer) (ReviewerClean cleanEvidence resolvedThreadIds)
  | null missingThreadIds =
      ReviewerClean cleanEvidence resolvedThreadIds
  | otherwise =
      ReviewerIncomplete ("clean verification did not mark fixed prior review threads as resolved: " <> Text.intercalate ", " (fmap unReviewThreadId missingThreadIds))
 where
  missingThreadIds =
    filter (`notElem` resolvedThreadIds) (reviewEvidenceThreadIds evidence)
verifyReviewerOutcome _ outcome =
  outcome
