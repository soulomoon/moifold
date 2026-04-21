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

  StartIssuePlanMode :: ActiveTurn -> Event 'IssueImplement 'Triage
  IssuePlanCompleted :: ActiveTurn -> Event 'IssueImplement 'PlanMode
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
step (IssueNeedsTriage config (WorkerIdle threadId)) (StartIssuePlanMode activeTurn) =
  Decision
    (IssueInPlanMode config (WorkerActive activeTurn))
    [SomeEffect (StartWorkerTurn threadId)]
step state@IssueTriageActive {} (StartIssuePlanMode _activeTurn) =
  Decision state []
step (IssueInPlanMode config (WorkerActive _activeTurn)) (IssuePlanCompleted nextTurn) =
  Decision
    (IssueImplementing config (WorkerActive nextTurn))
    [ SomeEffect (PushBranch (issueBranch config))
    , SomeEffect (CreatePullRequest config)
    , SomeEffect (StartWorkerTurn (activeThreadId nextTurn))
    ]
step (IssuePlanReady config (WorkerIdle _threadId)) (IssuePlanCompleted nextTurn) =
  Decision
    (IssueImplementing config (WorkerActive nextTurn))
    [ SomeEffect (PushBranch (issueBranch config))
    , SomeEffect (CreatePullRequest config)
    , SomeEffect (StartWorkerTurn (activeThreadId nextTurn))
    ]
step (IssueImplementing _config _thread) (IssueImplementationCompleted prNumber) =
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

effectsForTerminalState :: WatcherState domain phase -> EffectPlan
effectsForTerminalState = \case
  BlockedState {} -> []
  CompleteState {} -> []
  StoppedState {} -> []
  _ -> []
