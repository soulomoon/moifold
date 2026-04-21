{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE LambdaCase #-}
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
step (PlanningTurnActive config _activeTurn) PlannerTurnCompleted =
  Decision
    (PlanningReady config)
    [SomeEffect SleepUntilNextPoll]
step (IssueNeedsTriage config (WorkerIdle threadId)) (StartIssueTriageTurn activeTurn) =
  Decision
    (IssueTriageActive config (WorkerActive activeTurn))
    [SomeEffect (StartWorkerTurn threadId)]
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
    [SomeEffect (StartWorkerTurn threadId)]
step state@IssueTriageActive {} (StartIssuePlanTurn _activeTurn) =
  Decision state []
step (IssuePlanReady config (WorkerIdle threadId)) (StartReadyIssuePlanTurn activeTurn) =
  Decision
    (IssueInPlanMode config (WorkerActive activeTurn))
    [SomeEffect (StartWorkerTurn threadId)]
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
    , SomeEffect (StartWorkerTurn (activeThreadId nextTurn))
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
    , SomeEffect (StartWorkerTurn (activeThreadId nextTurn))
    ]
step (IssueImplementationReady config _maybePr worker) (IssuePullRequestReady prNumber) =
  Decision
    (IssueImplementationReady config (Just prNumber) worker)
    [SomeEffect SleepUntilNextPoll]
step (IssueImplementationReady config maybePr (WorkerIdle threadId)) (StartIssueImplementationTurn activeTurn) =
  Decision
    (IssueImplementing config maybePr (WorkerActive activeTurn))
    [SomeEffect (StartWorkerTurn threadId)]
step (IssueImplementing config maybePr (WorkerActive activeTurn)) IssueImplementationIncomplete =
  Decision
    (IssueImplementationReady config maybePr (WorkerIdle (activeThreadId activeTurn)))
    [SomeEffect (StartWorkerTurn (activeThreadId activeTurn))]
step state@IssueImplementationReady {} (IssueReviewHandoffInitialized _prNumber) =
  Decision state [SomeEffect SleepUntilNextPoll]
step state@IssueImplementationReady {} (IssueReviewHandoffStarted _prNumber) =
  Decision state [SomeEffect SleepUntilNextPoll]
step state@IssueImplementing {} (IssueReviewHandoffInitialized _prNumber) =
  Decision state [SomeEffect SleepUntilNextPoll]
step state@IssueImplementing {} (IssueReviewHandoffStarted _prNumber) =
  Decision state [SomeEffect SleepUntilNextPoll]
step (IssueImplementing _config _maybePr _thread) (IssueImplementationCompleted prNumber) =
  Decision
    (CompleteState (IssueComplete prNumber))
    [SomeEffect SleepUntilNextPoll]
step (IssueImplementationReady _config _maybePr _thread) (IssueImplementationCompleted prNumber) =
  Decision
    (CompleteState (IssueComplete prNumber))
    [SomeEffect SleepUntilNextPoll]
step (PrCheckingReviews config _worker (ReviewerIdle reviewerThreadId)) (ReviewThreadsFound evidence activeTurn) =
  Decision
    (PrFixingReviews config evidence (WorkerActive activeTurn) (ReviewerIdle reviewerThreadId))
    [SomeEffect (StartWorkerTurn (activeThreadId activeTurn))]
step (PrCheckingReviews config (WorkerIdle workerThreadId) _reviewer) (NoReviewThreadsFound commit activeTurn) =
  Decision
    (PrReviewingClean config commit (WorkerIdle workerThreadId) (ReviewerActive activeTurn))
    [SomeEffect (StartReviewerTurn (activeThreadId activeTurn))]
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
