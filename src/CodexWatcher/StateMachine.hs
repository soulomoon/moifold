{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

module CodexWatcher.StateMachine
  ( CanBlock
  , Event (..)
  , Decision (..)
  , step
  ) where

import CodexWatcher.Effects
import CodexWatcher.Types
import Data.Foldable qualified as Foldable
import Data.List.NonEmpty (NonEmpty)
import Data.Kind (Constraint)
import qualified Data.Text as Text
import GHC.TypeLits (ErrorMessage (..), TypeError)

type family CanBlock (phase :: Phase) :: Constraint where
  CanBlock 'Blocked =
    TypeError ('Text "A blocked watcher cannot be blocked again.")
  CanBlock 'Complete =
    TypeError ('Text "A complete watcher cannot transition to blocked.")
  CanBlock 'Stopped =
    TypeError ('Text "A stopped watcher cannot transition to blocked.")
  CanBlock _ = ()

data Event (domain :: Domain) (phase :: Phase) where
  StartPlanningTurn :: ActiveTurn -> Event 'IssuePlanning 'Initialized
  PlannerReadyIssuesFixed :: Event 'IssuePlanning 'Initialized
  PlannerScopeCompleted :: Event 'IssuePlanning 'Initialized
  PlannerRequestedIssueCreation :: NonEmpty IssueCreationRequest -> Event 'IssuePlanning 'PlanMode
  PlannerUpdatedGraph :: PlanningGraph -> Event 'IssuePlanning 'PlanMode
  PlannerTurnRetryRequested :: BlockedReason -> Event 'IssuePlanning 'PlanMode
  PlannerTurnCompleted :: Event 'IssuePlanning 'PlanMode

  StartReadyIssuePlanTurn :: ActiveTurn -> Event 'IssueImplement 'PlanMode
  IssuePlanCompleted :: Text.Text -> Maybe ActiveTurn -> Event 'IssueImplement 'PlanMode
  IssuePullRequestReady :: PrNumber -> Event 'IssueImplement 'Implementing
  IssuePullRequestBodyUpdated :: PrNumber -> Event 'IssueImplement 'Implementing
  StartIssueImplementationTurn :: ActiveTurn -> Event 'IssueImplement 'Implementing
  IssueImplementationIncomplete :: Event 'IssueImplement 'Implementing
  IssueReviewHandoffInitialized :: PrNumber -> Event 'IssueImplement 'Implementing
  IssueReviewHandoffStarted :: PrNumber -> Event 'IssueImplement 'Implementing
  IssueImplementationCompleted :: PrNumber -> Event 'IssueImplement 'Implementing
  IssuePullRequestMerged :: PrNumber -> Event 'IssueImplement 'Implementing
  IssueClosed :: PrNumber -> Event 'IssueImplement 'Implementing

  ReviewThreadsFound :: ReviewEvidence -> ActiveTurn -> Event 'PrReview 'CheckingReviews
  NoReviewThreadsFound :: CommitSha -> ActiveTurn -> Event 'PrReview 'CheckingReviews
  ReviewFixCompleted :: Event 'PrReview 'FixingReviews
  ReviewFixIncomplete :: Event 'PrReview 'FixingReviews
  ReviewerFoundClean :: CleanReviewEvidence -> Event 'PrReview 'ReviewingClean
  ReviewerFoundProblems :: Event 'PrReview 'ReviewingClean
  ReviewerTurnIncomplete :: Event 'PrReview 'ReviewingClean
  MergeabilityClean :: Event 'PrReview 'WaitingMergeability
  MergeabilityRetryLater :: Text.Text -> Event 'PrReview 'WaitingMergeability
  MergeabilityRecheckReviews :: Text.Text -> Event 'PrReview 'WaitingMergeability
  MergeCompleted :: MergeCommit -> Event 'PrReview 'Merging

  MarkBlocked :: CanBlock phase => BlockedReason -> Event domain phase
  StopWatcher :: StopReason -> Event domain phase

data Decision (domain :: Domain) where
  Decision
    :: KnownPhase nextPhase
    => WatcherState domain nextPhase
    -> EffectPlan
    -> Decision domain

step :: WatcherState domain phase -> Event domain phase -> Decision domain
step _ (MarkBlocked reason) =
  Decision (BlockedState reason) [SomeEffect (RecordBlocked reason), SomeEffect StopDaemon]
step _ (StopWatcher reason) =
  Decision (StoppedState reason) [SomeEffect StopDaemon]
step (PlanningReady config) (StartPlanningTurn activeTurn) =
  Decision
    (PlanningTurnActive config activeTurn)
    [SomeEffect (StartPlannerTurn (activeThreadId activeTurn))]
step (PlanningWaitingForReadyIssues config _graph) PlannerReadyIssuesFixed =
  Decision
    (PlanningReady config)
    [SomeEffect SleepUntilNextPoll]
step (PlanningReady _config) PlannerScopeCompleted =
  Decision
    (CompleteState PlanningComplete)
    [SomeEffect StopDaemon]
step (PlanningTurnActive config _activeTurn) (PlannerTurnRetryRequested _reason) =
  Decision
    (PlanningReady config)
    [SomeEffect SleepUntilNextPoll]
step (PlanningTurnActive _config _activeTurn) PlannerTurnCompleted =
  Decision
    (CompleteState PlanningComplete)
    [SomeEffect StopDaemon]
step (PlanningTurnActive config _activeTurn) (PlannerUpdatedGraph graph) =
  Decision
    (PlanningWaitingForReadyIssues config graph)
    [SomeEffect (RecordPlanningGraph graph), SomeEffect SleepUntilNextPoll]
step (PlanningTurnActive config _activeTurn) (PlannerRequestedIssueCreation requests) =
  Decision
    (PlanningReady config)
    ([SomeEffect (CreateIssue (plannerRepo config) request) | request <- Foldable.toList requests] <> [SomeEffect SleepUntilNextPoll])
step (IssueReadyToPlan config prNumber (WorkerIdle threadId)) (StartReadyIssuePlanTurn activeTurn) =
  Decision
    (IssueInPlanMode config prNumber (WorkerActive activeTurn))
    [SomeEffect (StartIssuePlanWorkerTurn config prNumber threadId)]
step (IssueInPlanMode config prNumber (WorkerActive activeTurn)) (IssuePlanCompleted planMarkdown maybeNextTurn) =
  let nextTurn = maybe activeTurn id maybeNextTurn
   in Decision
        (IssuePlanReady config prNumber (WorkerIdle (activeThreadId nextTurn)))
        [SomeEffect (RecordIssuePlan config prNumber planMarkdown), SomeEffect SleepUntilNextPoll]
step (IssueImplementationReady config _maybePr worker) (IssuePullRequestReady prNumber) =
  Decision
    (IssueReadyToPlan config prNumber worker)
    [SomeEffect SleepUntilNextPoll]
step (IssueImplementing config _maybePr worker) (IssuePullRequestReady prNumber) =
  Decision
    (IssueImplementing config (Just prNumber) worker)
    [SomeEffect SleepUntilNextPoll]
step state@(IssuePlanReady _config expectedPrNumber _worker) (IssuePullRequestBodyUpdated prNumber)
  | expectedPrNumber == prNumber =
      case state of
        IssuePlanReady config _ (WorkerIdle threadId) ->
          Decision (IssueImplementationReady config (Just prNumber) (WorkerIdle threadId)) [SomeEffect SleepUntilNextPoll]
  | otherwise =
      prMismatchBlocked (Just expectedPrNumber) prNumber
step state@(IssueImplementationReady _config maybePr _worker) (IssuePullRequestBodyUpdated prNumber)
  | prMatchesKnownStrict maybePr prNumber =
      Decision state [SomeEffect SleepUntilNextPoll]
  | otherwise =
      prMismatchBlocked maybePr prNumber
step state@(IssueImplementing _config maybePr _worker) (IssuePullRequestBodyUpdated prNumber)
  | prMatchesKnownStrict maybePr prNumber =
      Decision state [SomeEffect SleepUntilNextPoll]
  | otherwise =
      prMismatchBlocked maybePr prNumber
step (IssueImplementationReady config maybePr (WorkerIdle threadId)) (StartIssueImplementationTurn activeTurn) =
  Decision
    (IssueImplementing config maybePr (WorkerActive activeTurn))
    [SomeEffect (StartIssueImplementationWorkerTurn threadId)]
step (IssueImplementing config maybePr (WorkerActive activeTurn)) IssueImplementationIncomplete =
  Decision
    (IssueImplementationReady config maybePr (WorkerIdle (activeThreadId activeTurn)))
    [SomeEffect (StartIssueImplementationWorkerTurn (activeThreadId activeTurn))]
step (IssueImplementing config maybePr _thread) (IssueImplementationCompleted prNumber)
  | prMatchesKnownStrict maybePr prNumber =
      Decision (IssueHandoffReady config prNumber) [SomeEffect SleepUntilNextPoll]
  | otherwise =
      prMismatchBlocked maybePr prNumber
step (IssueHandoffReady config expectedPrNumber) (IssueReviewHandoffInitialized prNumber)
  | expectedPrNumber == prNumber =
      Decision (IssueHandoffInitialized config prNumber) [SomeEffect SleepUntilNextPoll]
  | otherwise =
      prMismatchBlocked (Just expectedPrNumber) prNumber
step state@(IssueHandoffInitialized _config expectedPrNumber) (IssueReviewHandoffInitialized prNumber)
  | expectedPrNumber == prNumber =
      Decision state [SomeEffect SleepUntilNextPoll]
  | otherwise =
      prMismatchBlocked (Just expectedPrNumber) prNumber
step (IssueHandoffInitialized config expectedPrNumber) (IssueReviewHandoffStarted prNumber)
  | expectedPrNumber == prNumber =
      Decision (IssueWaitingForPrMerge config prNumber) [SomeEffect SleepUntilNextPoll]
  | otherwise =
      prMismatchBlocked (Just expectedPrNumber) prNumber
step state@IssueWaitingForPrMerge {} (IssueReviewHandoffInitialized _prNumber) =
  Decision state [SomeEffect SleepUntilNextPoll]
step state@IssueWaitingForPrMerge {} (IssueReviewHandoffStarted _prNumber) =
  Decision state [SomeEffect SleepUntilNextPoll]
step state@(IssueHandoffReady _config expectedPrNumber) (IssueImplementationCompleted prNumber)
  | expectedPrNumber == prNumber =
      Decision state [SomeEffect SleepUntilNextPoll]
  | otherwise =
      prMismatchBlocked (Just expectedPrNumber) prNumber
step state@(IssueHandoffInitialized _config expectedPrNumber) (IssueImplementationCompleted prNumber)
  | expectedPrNumber == prNumber =
      Decision state [SomeEffect SleepUntilNextPoll]
  | otherwise =
      prMismatchBlocked (Just expectedPrNumber) prNumber
step state@(IssueWaitingForPrMerge _config expectedPrNumber) (IssueImplementationCompleted prNumber)
  | expectedPrNumber == prNumber =
      Decision state [SomeEffect SleepUntilNextPoll]
  | otherwise =
      prMismatchBlocked (Just expectedPrNumber) prNumber
step (IssueWaitingForPrMerge config expectedPrNumber) (IssuePullRequestMerged prNumber)
  | expectedPrNumber == prNumber =
      Decision
        (IssueWaitingForIssueClose config prNumber)
        [SomeEffect (CloseIssue config prNumber), SomeEffect SleepUntilNextPoll]
  | otherwise =
      let reason =
            BlockedReason
              ( Text.pack ("issue implementer observed merged PR #" <> show (unPrNumber prNumber))
                  <> Text.pack (" while waiting for PR #" <> show (unPrNumber expectedPrNumber))
              )
       in Decision (BlockedState reason) [SomeEffect (RecordBlocked reason), SomeEffect StopDaemon]
step (IssueWaitingForIssueClose _config expectedPrNumber) (IssueClosed prNumber)
  | expectedPrNumber == prNumber =
      Decision
        (CompleteState (IssueComplete prNumber))
        [SomeEffect StopDaemon]
  | otherwise =
      prMismatchBlocked (Just expectedPrNumber) prNumber
step state@(IssueImplementing {}) (IssuePullRequestMerged _prNumber) =
  Decision state [SomeEffect SleepUntilNextPoll]
step state@(IssueImplementationReady {}) (IssuePullRequestMerged _prNumber) =
  Decision
    state
    [SomeEffect SleepUntilNextPoll]
step state@(IssueHandoffReady {}) (IssuePullRequestMerged _prNumber) =
  Decision state [SomeEffect SleepUntilNextPoll]
step state@(IssueHandoffInitialized {}) (IssuePullRequestMerged _prNumber) =
  Decision state [SomeEffect SleepUntilNextPoll]
step state@IssueWaitingForIssueClose {} (IssuePullRequestMerged _prNumber) =
  Decision state [SomeEffect SleepUntilNextPoll]
step (PrCheckingReviews config _worker (ReviewerIdle reviewerThreadId)) (ReviewThreadsFound evidence activeTurn) =
  Decision
    (PrFixingReviews config evidence (WorkerActive activeTurn) (ReviewerIdle reviewerThreadId))
    [SomeEffect (StartWorkerTurn (activeThreadId activeTurn))]
step (PrCheckingReviews config (WorkerIdle workerThreadId) _reviewer) (NoReviewThreadsFound commit activeTurn) =
  Decision
    (PrReviewingClean config commit (WorkerIdle workerThreadId) (ReviewerActive activeTurn))
    [SomeEffect (StartReviewerTurn config commit (activeThreadId activeTurn))]
step (PrFixingReviews config _evidence (WorkerActive activeTurn) (ReviewerIdle reviewerThreadId)) ReviewFixCompleted =
  Decision
    (PrCheckingReviews config (WorkerIdle (activeThreadId activeTurn)) (ReviewerIdle reviewerThreadId))
    [SomeEffect (ReadReviewThreads config)]
step (PrFixingReviews config _evidence (WorkerActive activeTurn) (ReviewerIdle reviewerThreadId)) ReviewFixIncomplete =
  Decision
    (PrCheckingReviews config (WorkerIdle (activeThreadId activeTurn)) (ReviewerIdle reviewerThreadId))
    [SomeEffect (ReadReviewThreads config)]
step (PrReviewingClean config _commit (WorkerIdle workerThreadId) (ReviewerActive activeTurn)) (ReviewerFoundClean evidence) =
  Decision
    (PrWaitingForMergeability config evidence (WorkerIdle workerThreadId) (ReviewerIdle (activeThreadId activeTurn)))
    [SomeEffect SleepUntilNextPoll]
step (PrReviewingClean config _commit (WorkerIdle workerThreadId) (ReviewerActive activeTurn)) ReviewerFoundProblems =
  Decision
    (PrCheckingReviews config (WorkerIdle workerThreadId) (ReviewerIdle (activeThreadId activeTurn)))
    [SomeEffect (ReadReviewThreads config)]
step (PrReviewingClean config _commit (WorkerIdle workerThreadId) (ReviewerActive activeTurn)) ReviewerTurnIncomplete =
  Decision
    (PrCheckingReviews config (WorkerIdle workerThreadId) (ReviewerIdle (activeThreadId activeTurn)))
    [SomeEffect (ReadReviewThreads config)]
step (PrWaitingForMergeability config evidence _worker _reviewer) MergeabilityClean =
  Decision
    (PrMerging config evidence)
    [SomeEffect (MergePullRequest (prNumber config) evidence)]
step state@PrWaitingForMergeability {} (MergeabilityRetryLater _reason) =
  Decision state [SomeEffect SleepUntilNextPoll]
step (PrWaitingForMergeability config _evidence (WorkerIdle workerThreadId) (ReviewerIdle reviewerThreadId)) (MergeabilityRecheckReviews _reason) =
  Decision
    (PrCheckingReviews config (WorkerIdle workerThreadId) (ReviewerIdle reviewerThreadId))
    [SomeEffect (ReadReviewThreads config)]
step (PrMerging _config _evidence) (MergeCompleted mergeCommit) =
  Decision
    (CompleteState (PrMerged mergeCommit))
    [SomeEffect StopDaemon]
step _ _ =
  let reason = BlockedReason (Text.pack "invalid state/event transition")
   in Decision
        (BlockedState reason)
        [SomeEffect (RecordBlocked reason), SomeEffect StopDaemon]

prMatchesKnownStrict :: Maybe PrNumber -> PrNumber -> Bool
prMatchesKnownStrict Nothing _ = False
prMatchesKnownStrict (Just expected) actual = expected == actual

prMismatchBlocked :: Maybe PrNumber -> PrNumber -> Decision 'IssueImplement
prMismatchBlocked expected actual =
  let reason =
        BlockedReason
          ( "review handoff PR mismatch: expected "
              <> maybe "known PR" (Text.pack . show . unPrNumber) expected
              <> ", got "
              <> Text.pack (show (unPrNumber actual))
          )
   in Decision (BlockedState reason) [SomeEffect (RecordBlocked reason), SomeEffect StopDaemon]
