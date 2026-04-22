{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

module CodexWatcher.StateMachine
  ( CanBlock
  , Event (..)
  , Decision (..)
  , nextPhase
  , step
  , effectsForTerminalState
  ) where

import CodexWatcher.Effects
import CodexWatcher.Types
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
  PlannerRequestedIssueCreation :: [IssueCreationRequest] -> Event 'IssuePlanning 'PlanMode
  PlannerUpdatedGraph :: PlanningGraph -> Event 'IssuePlanning 'PlanMode
  PlannerTurnCompleted :: Event 'IssuePlanning 'PlanMode

  StartIssueTriageTurn :: ActiveTurn -> Event 'IssueImplement 'Triage
  IssueTriageAlreadyFixed :: Event 'IssueImplement 'Triage
  IssueTriageNeedsImplementation :: Event 'IssueImplement 'Triage
  IssueTriageBlocked :: BlockedReason -> Event 'IssueImplement 'Triage
  StartIssuePlanTurn :: ActiveTurn -> Event 'IssueImplement 'Triage
  StartReadyIssuePlanTurn :: ActiveTurn -> Event 'IssueImplement 'PlanMode
  IssuePlanCompleted :: Maybe ActiveTurn -> Event 'IssueImplement 'PlanMode
  IssuePullRequestReady :: PrNumber -> Event 'IssueImplement 'Implementing
  StartIssueImplementationTurn :: ActiveTurn -> Event 'IssueImplement 'Implementing
  IssueImplementationIncomplete :: Event 'IssueImplement 'Implementing
  IssueReviewHandoffInitialized :: PrNumber -> Event 'IssueImplement 'Implementing
  IssueReviewHandoffStarted :: PrNumber -> Event 'IssueImplement 'Implementing
  IssueImplementationCompleted :: PrNumber -> Event 'IssueImplement 'Implementing
  IssuePullRequestMerged :: PrNumber -> Event 'IssueImplement 'Implementing

  ReviewThreadsFound :: ReviewEvidence -> ActiveTurn -> Event 'PrReview 'CheckingReviews
  NoReviewThreadsFound :: CommitSha -> ActiveTurn -> Event 'PrReview 'CheckingReviews
  ReviewFixCompleted :: Event 'PrReview 'FixingReviews
  ReviewFixIncomplete :: Event 'PrReview 'FixingReviews
  ReviewerFoundClean :: CleanReviewEvidence -> Event 'PrReview 'ReviewingClean
  ReviewerFoundProblems :: Event 'PrReview 'ReviewingClean
  ReviewerTurnIncomplete :: Event 'PrReview 'ReviewingClean
  MergeCompleted :: MergeCommit -> Event 'PrReview 'Merging

  MarkBlocked :: CanBlock phase => BlockedReason -> Event domain phase
  StopWatcher :: StopReason -> Event domain phase

data Decision (domain :: Domain) where
  Decision
    :: WatcherState domain nextPhase
    -> EffectPlan
    -> Decision domain

nextPhase :: Decision domain -> Phase
nextPhase (Decision state _) = phaseOf state

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
    ([SomeEffect (CreateIssue (plannerRepo config) request) | request <- requests] <> [SomeEffect SleepUntilNextPoll])
step (IssueNeedsTriage config (WorkerIdle threadId)) (StartIssueTriageTurn activeTurn) =
  Decision
    (IssueTriageActive config (WorkerActive activeTurn))
    [SomeEffect (StartIssueTriageWorkerTurn threadId)]
step state@IssueTriageActive {} (StartIssueTriageTurn _activeTurn) =
  Decision state []
step (IssueTriageActive config _activeTurn) IssueTriageAlreadyFixed =
  Decision
    (CompleteState (IssueAlreadyResolved (issueNumber config)))
    [SomeEffect SleepUntilNextPoll]
step (IssueTriageActive config (WorkerActive activeTurn)) IssueTriageNeedsImplementation =
  Decision
    (IssuePlanReady config (WorkerIdle (activeThreadId activeTurn)))
    [SomeEffect SleepUntilNextPoll]
step _ (IssueTriageBlocked reason) =
  Decision (BlockedState reason) [SomeEffect (RecordBlocked reason), SomeEffect StopDaemon]
step (IssueNeedsTriage config (WorkerIdle threadId)) (StartIssuePlanTurn activeTurn) =
  Decision
    (IssueInPlanMode config (WorkerActive activeTurn))
    [SomeEffect (StartIssuePlanWorkerTurn config threadId)]
step state@IssueTriageActive {} (StartIssuePlanTurn _activeTurn) =
  Decision state []
step (IssuePlanReady config (WorkerIdle threadId)) (StartReadyIssuePlanTurn activeTurn) =
  Decision
    (IssueInPlanMode config (WorkerActive activeTurn))
    [SomeEffect (StartIssuePlanWorkerTurn config threadId)]
step (IssueInPlanMode config (WorkerActive activeTurn)) (IssuePlanCompleted Nothing) =
  Decision
    (IssueImplementationReady config Nothing (WorkerIdle (activeThreadId activeTurn)))
    [ SomeEffect (PushBranch (issueBranch config))
    , SomeEffect (CreatePullRequest config)
    ]
step (IssueInPlanMode config (WorkerActive _activeTurn)) (IssuePlanCompleted (Just nextTurn)) =
  Decision
    (IssueImplementing config Nothing (WorkerActive nextTurn))
    [ SomeEffect (PushBranch (issueBranch config))
    , SomeEffect (CreatePullRequest config)
    , SomeEffect (StartIssueImplementationWorkerTurn (activeThreadId nextTurn))
    ]
step (IssuePlanReady config (WorkerIdle _threadId)) (IssuePlanCompleted Nothing) =
  Decision
    (IssueImplementationReady config Nothing (WorkerIdle _threadId))
    [ SomeEffect (PushBranch (issueBranch config))
    , SomeEffect (CreatePullRequest config)
    ]
step (IssuePlanReady config (WorkerIdle _threadId)) (IssuePlanCompleted (Just nextTurn)) =
  Decision
    (IssueImplementing config Nothing (WorkerActive nextTurn))
    [ SomeEffect (PushBranch (issueBranch config))
    , SomeEffect (CreatePullRequest config)
    , SomeEffect (StartIssueImplementationWorkerTurn (activeThreadId nextTurn))
    ]
step (IssueImplementationReady config _maybePr worker) (IssuePullRequestReady prNumber) =
  Decision
    (IssueImplementationReady config (Just prNumber) worker)
    [SomeEffect SleepUntilNextPoll]
step (IssueImplementing config _maybePr worker) (IssuePullRequestReady prNumber) =
  Decision
    (IssueImplementing config (Just prNumber) worker)
    [SomeEffect SleepUntilNextPoll]
step (IssueImplementationReady config maybePr (WorkerIdle threadId)) (StartIssueImplementationTurn activeTurn) =
  Decision
    (IssueImplementing config maybePr (WorkerActive activeTurn))
    [SomeEffect (StartIssueImplementationWorkerTurn threadId)]
step (IssueImplementing config maybePr (WorkerActive activeTurn)) IssueImplementationIncomplete =
  Decision
    (IssueImplementationReady config maybePr (WorkerIdle (activeThreadId activeTurn)))
    [SomeEffect (StartIssueImplementationWorkerTurn (activeThreadId activeTurn))]
step state@IssueImplementationReady {} (IssueReviewHandoffInitialized _prNumber) =
  Decision state [SomeEffect SleepUntilNextPoll]
step (IssueImplementationReady config maybePr _worker) (IssueReviewHandoffStarted prNumber)
  | prMatchesKnown maybePr prNumber =
      Decision (IssueWaitingForPrMerge config prNumber) [SomeEffect SleepUntilNextPoll]
  | otherwise =
      prMismatchBlocked maybePr prNumber
step state@IssueImplementing {} (IssueReviewHandoffInitialized _prNumber) =
  Decision state [SomeEffect SleepUntilNextPoll]
step (IssueImplementing config maybePr _thread) (IssueReviewHandoffStarted prNumber)
  | prMatchesKnown maybePr prNumber =
      Decision (IssueWaitingForPrMerge config prNumber) [SomeEffect SleepUntilNextPoll]
  | otherwise =
      prMismatchBlocked maybePr prNumber
step state@IssueWaitingForPrMerge {} (IssueReviewHandoffInitialized _prNumber) =
  Decision state [SomeEffect SleepUntilNextPoll]
step state@IssueWaitingForPrMerge {} (IssueReviewHandoffStarted _prNumber) =
  Decision state [SomeEffect SleepUntilNextPoll]
step state@IssueImplementing {} (IssueImplementationCompleted _prNumber) =
  Decision state [SomeEffect SleepUntilNextPoll]
step state@IssueImplementationReady {} (IssueImplementationCompleted _prNumber) =
  Decision state [SomeEffect SleepUntilNextPoll]
step state@IssueWaitingForPrMerge {} (IssueImplementationCompleted _prNumber) =
  Decision state [SomeEffect SleepUntilNextPoll]
step (IssueWaitingForPrMerge _config expectedPrNumber) (IssuePullRequestMerged prNumber)
  | expectedPrNumber == prNumber =
      Decision
        (CompleteState (IssueComplete prNumber))
        [SomeEffect StopDaemon]
  | otherwise =
      let reason =
            BlockedReason
              ( Text.pack ("issue implementer observed merged PR #" <> show (unPrNumber prNumber))
                  <> Text.pack (" while waiting for PR #" <> show (unPrNumber expectedPrNumber))
              )
       in Decision (BlockedState reason) [SomeEffect (RecordBlocked reason), SomeEffect StopDaemon]
step state@(IssueImplementing {}) (IssuePullRequestMerged _prNumber) =
  Decision state [SomeEffect SleepUntilNextPoll]
step state@(IssueImplementationReady {}) (IssuePullRequestMerged _prNumber) =
  Decision
    state
    [SomeEffect SleepUntilNextPoll]
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
step (PrReviewingClean config _commit _worker _reviewer) (ReviewerFoundClean evidence) =
  Decision
    (PrMerging config evidence)
    [SomeEffect (MergePullRequest (prNumber config) evidence)]
step (PrReviewingClean config _commit (WorkerIdle workerThreadId) (ReviewerActive activeTurn)) ReviewerFoundProblems =
  Decision
    (PrCheckingReviews config (WorkerIdle workerThreadId) (ReviewerIdle (activeThreadId activeTurn)))
    [SomeEffect (ReadReviewThreads config)]
step (PrReviewingClean config _commit (WorkerIdle workerThreadId) (ReviewerActive activeTurn)) ReviewerTurnIncomplete =
  Decision
    (PrCheckingReviews config (WorkerIdle workerThreadId) (ReviewerIdle (activeThreadId activeTurn)))
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

effectsForTerminalState :: WatcherState domain phase -> EffectPlan
effectsForTerminalState = \case
  BlockedState {} -> []
  CompleteState {} -> []
  StoppedState {} -> []
  _ -> []

prMatchesKnown :: Maybe PrNumber -> PrNumber -> Bool
prMatchesKnown Nothing _ = True
prMatchesKnown (Just expected) actual = expected == actual

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
