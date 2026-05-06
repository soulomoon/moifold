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
import CodexWatcher.Domain.PrReview.Types
  ( MergeCommit
  , ReviewContext (..)
  , ReviewEvidence (..)
  , SomeReviewContext (..)
  , reviewEvidenceThreadIds
  )
import CodexWatcher.Workflow.Moifold.PrReview
  ( PrReviewCheckingObservation (..)
  , observePrReviewChecking
  , unresolvedReviewEvidence
  )
import CodexWatcher.Workflow.Moifold.PrReview.Mergeability
  ( PrReviewMergeabilityObservation (..)
  , observePrReviewMergeability
  )
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
prReviewObserve state (ObservedReviewThreads report commit turnId) =
  fromObservedTick <$> observePrReviewChecking state (CheckingObservedReviewThreads report commit turnId)
prReviewObserve state (ObservedReviewFeedback evidence turnId) =
  fromObservedTick <$> observePrReviewChecking state (CheckingObservedReviewFeedback evidence turnId)
prReviewObserve (SomeWatcherState state@PrFixingReviews {}) (ObservedWorkerOutcome outcome) =
  case outcome of
    WorkerCompleted ->
      Right (tick PrReviewFixCompleted (step state ReviewFixCompleted))
    WorkerIncomplete reason ->
      Right (tick (PrReviewFixIncomplete reason) (step state ReviewFixIncomplete))
    WorkerBlocked reason ->
      Right (tick (WatcherBlocked reason) (step state (MarkBlocked reason)))
prReviewObserve state (ObservedReviewFixVerificationStarted reviewTargetSha turnId) =
  fromObservedTick <$> observePrReviewChecking state (CheckingObservedReviewFixVerificationStarted reviewTargetSha turnId)
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
prReviewObserve state (ObservedMergeabilityClean commitSha) =
  fromObservedTick <$> observePrReviewMergeability state (MergeabilityObservedClean commitSha)
prReviewObserve state (ObservedMergeabilityRetry reason) =
  fromObservedTick <$> observePrReviewMergeability state (MergeabilityObservedRetry reason)
prReviewObserve state (ObservedMergeabilityRecheck reason) =
  fromObservedTick <$> observePrReviewMergeability state (MergeabilityObservedRecheck reason)
prReviewObserve state (ObservedMergeabilityFixRequired evidence) =
  fromObservedTick <$> observePrReviewMergeability state (MergeabilityObservedFixRequired evidence)
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

verifyReviewerOutcome :: WatcherState 'PrReview 'ReviewingClean -> ReviewerOutcome -> ReviewerOutcome
verifyReviewerOutcome (PrReviewingClean _config _commit (SomeReviewContext (VerificationReviewContext evidence)) _worker _reviewer) (ReviewerClean cleanEvidence resolvedThreadIds)
  | null missingThreadIds =
      ReviewerClean cleanEvidence resolvedThreadIds
  | otherwise =
      ReviewerIncomplete ("clean verification did not mark fixed prior review threads as resolved: " <> Text.intercalate ", " (fmap unReviewThreadId missingThreadIds))
 where
  missingThreadIds =
    filter (`notElem` resolvedThreadIds) (reviewEvidenceThreadIds evidence)
verifyReviewerOutcome _ outcome =
  outcome
