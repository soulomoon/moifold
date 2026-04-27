{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

module CodexWatcher.StateMachine
  ( CanBlock
  , Event (..)
  , Decision (..)
  , PhaseActionValidationError (..)
  , formatPhaseActionValidationError
  , nextIssueAttemptBranch
  , step
  , validatePhaseActionPlan
  ) where

import CodexWatcher.Effects
import CodexWatcher.Core.Ids (BranchName (..), CommitSha, IssueNumber (..), PrNumber (..), ReviewThreadId, ThreadId)
import CodexWatcher.Core.Kinds (Domain (..), KnownPhase, Phase (..))
import CodexWatcher.Core.Reason (BlockedReason (..), StopReason)
import CodexWatcher.Core.State (CompletionEvidence (..), SomeWatcherState (..), WatcherState (..), someDomain, somePhase)
import CodexWatcher.Core.Thread (ActiveTurn (..), ReviewerThread (..), WorkerThread (..))
import CodexWatcher.Domain.IssueImplement.Types (IssueConfig (..))
import CodexWatcher.Domain.IssuePlanning.Types (IssueCreationRequest, PlannerConfig (..), PlanningGraph)
import CodexWatcher.Domain.PrReview.Types
  ( CleanReviewEvidence
  , MergeCommit
  , PrConfig (..)
  , ReviewEvidence (..)
  , reviewEvidenceHasSummaries
  , reviewEvidenceThreadIds
  )
import Control.Monad (guard)
import Data.Foldable qualified as Foldable
import Data.Char (isDigit)
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
  IssueAttemptBranchAdvanced :: BranchName -> Event 'IssueImplement 'Implementing
  IssuePullRequestReady :: PrNumber -> Event 'IssueImplement 'Implementing
  IssuePullRequestBodyUpdated :: PrNumber -> Event 'IssueImplement 'Implementing
  StartIssueImplementationTurn :: ActiveTurn -> Event 'IssueImplement 'Implementing
  IssueImplementationIncomplete :: Event 'IssueImplement 'Implementing
  IssueReviewHandoffInitialized :: PrNumber -> Event 'IssueImplement 'Implementing
  IssueReviewHandoffStarted :: PrNumber -> Event 'IssueImplement 'Implementing
  IssueImplementationCompleted :: PrNumber -> Maybe ThreadId -> Event 'IssueImplement 'Implementing
  IssueReviewerThreadReady :: ThreadId -> Event 'IssueImplement 'Implementing
  IssuePullRequestMerged :: PrNumber -> Event 'IssueImplement 'Implementing
  StartIssuePostMergeReview :: CommitSha -> ActiveTurn -> Event 'IssueImplement 'Implementing
  IssuePostMergeReviewSatisfied :: CleanReviewEvidence -> Event 'IssueImplement 'Implementing
  IssuePostMergeReviewFollowUp :: ReviewEvidence -> Event 'IssueImplement 'Implementing
  IssuePostMergeReviewIncomplete :: Text.Text -> Event 'IssueImplement 'Implementing
  IssueClosed :: PrNumber -> Event 'IssueImplement 'Implementing

  ReviewThreadsFound :: ReviewEvidence -> ActiveTurn -> Event 'PrReview 'CheckingReviews
  NoReviewThreadsFound :: CommitSha -> ActiveTurn -> Event 'PrReview 'CheckingReviews
  StartReviewFixVerification :: CommitSha -> ActiveTurn -> Event 'PrReview 'CheckingReviews
  ReviewFixCompleted :: Event 'PrReview 'FixingReviews
  ReviewFixIncomplete :: Event 'PrReview 'FixingReviews
  ReviewerFoundClean :: CleanReviewEvidence -> [ReviewThreadId] -> Event 'PrReview 'ReviewingClean
  ReviewerFoundProblems :: ReviewEvidence -> [ReviewThreadId] -> Event 'PrReview 'ReviewingClean
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

data PhaseActionValidationError = PhaseActionValidationError
  { phaseActionState :: Text.Text
  , phaseActionEffect :: Text.Text
  , phaseActionReason :: Text.Text
  }
  deriving stock (Eq, Show)

formatPhaseActionValidationError :: PhaseActionValidationError -> Text.Text
formatPhaseActionValidationError errorValue =
  errorValue.phaseActionReason
    <> " (state="
    <> errorValue.phaseActionState
    <> ", effect="
    <> errorValue.phaseActionEffect
    <> ")"

validatePhaseActionPlan :: SomeWatcherState -> EffectPlan -> Either PhaseActionValidationError ()
validatePhaseActionPlan state effects =
  case filter (not . effectAllowedForState state) effects of
    [] -> Right ()
    effect : _ ->
      Left
        PhaseActionValidationError
          { phaseActionState = watcherStateLabel state
          , phaseActionEffect = someEffectName effect
          , phaseActionReason = "effect is not allowed from watcher phase"
          }

watcherStateLabel :: SomeWatcherState -> Text.Text
watcherStateLabel state =
  Text.pack (show (someDomain state)) <> "/" <> Text.pack (show (somePhase state))

effectAllowedForState :: SomeWatcherState -> SomeEffect -> Bool
effectAllowedForState (SomeWatcherState state) effect
  | commonEffectAllowed effect = True
  | otherwise =
      case state of
        PlanningReady {} ->
          effectIsStartPlannerTurn effect
        PlanningTurnActive {} ->
          effectIsOneOf
            [ effectIsCreateIssue
            , effectIsRecordPlanningGraph
            , effectIsSleep
            ]
            effect
        PlanningWaitingForReadyIssues {} ->
          effectIsSleep effect
        IssueReadyToPlan {} ->
          effectIsStartIssuePlanWorkerTurn effect
        IssueInPlanMode {} ->
          effectIsOneOf [effectIsRecordIssuePlan, effectIsSleep] effect
        IssuePlanReady {} ->
          effectIsOneOf [effectIsRecordIssuePlan, effectIsUpdatePullRequestBody, effectIsSleep] effect
        IssueImplementationReady {} ->
          effectIsOneOf [effectIsCreatePullRequest, effectIsStartIssueImplementationWorkerTurn, effectIsSleep] effect
        IssueImplementing {} ->
          effectIsOneOf [effectIsStartIssueImplementationWorkerTurn, effectIsSleep] effect
        IssueHandoffReady {} ->
          effectIsSleep effect
        IssueHandoffInitialized {} ->
          effectIsSleep effect
        IssueWaitingForPrMerge {} ->
          effectIsSleep effect
        IssuePostMergeReviewReady _config _prNumber _worker maybeReviewer ->
          case maybeReviewer of
            Just {} -> effectIsOneOf [effectIsStartIssueFinalReviewTurn, effectIsSleep] effect
            Nothing -> effectIsSleep effect
        IssuePostMergeReviewing {} ->
          effectIsOneOf [effectIsCloseIssue, effectIsUpdateIssueFollowUp, effectIsSleep] effect
        IssueWaitingForIssueClose {} ->
          effectIsOneOf [effectIsCloseIssue, effectIsSleep] effect
        PrCheckingReviews {} ->
          effectIsOneOf [effectIsStartWorkerTurn, effectIsStartReviewerTurn] effect
        PrFixingReviews {} ->
          effectIsOneOf [effectIsReadReviewThreads, effectIsSleep] effect
        PrVerifyingReviewFix {} ->
          effectIsOneOf [effectIsStartWorkerTurn, effectIsStartReviewerTurn, effectIsStartReviewerVerificationTurn] effect
        PrReviewingClean {} ->
          effectIsOneOf
            [ effectIsResolveReviewThread
            , effectIsDismissRequestChangesReview
            , effectIsRequestChangesReview
            , effectIsReadReviewThreads
            , effectIsSleep
            ]
            effect
        PrWaitingForMergeability {} ->
          effectIsOneOf [effectIsMergePullRequest, effectIsReadReviewThreads, effectIsSleep] effect
        PrMerging {} ->
          effectIsSleep effect
        BlockedState {} ->
          effectIsStopDaemon effect
        CompleteState {} ->
          effectIsStopDaemon effect
        StoppedState {} ->
          effectIsStopDaemon effect

commonEffectAllowed :: SomeEffect -> Bool
commonEffectAllowed effect =
  effectIsOneOf [effectIsRecordBlocked, effectIsStopDaemon] effect

effectIsOneOf :: [SomeEffect -> Bool] -> SomeEffect -> Bool
effectIsOneOf predicates effect =
  any ($ effect) predicates

someEffectName :: SomeEffect -> Text.Text
someEffectName (SomeEffect effect) =
  case effect of
    ReadOpenIssues {} -> "ReadOpenIssues"
    ReadOpenPullRequests {} -> "ReadOpenPullRequests"
    ReadReviewThreads {} -> "ReadReviewThreads"
    StartPlannerTurn {} -> "StartPlannerTurn"
    StartWorkerTurn {} -> "StartWorkerTurn"
    StartIssuePlanWorkerTurn {} -> "StartIssuePlanWorkerTurn"
    StartIssueImplementationWorkerTurn {} -> "StartIssueImplementationWorkerTurn"
    StartReviewerTurn {} -> "StartReviewerTurn"
    StartReviewerVerificationTurn {} -> "StartReviewerVerificationTurn"
    StartIssueFinalReviewTurn {} -> "StartIssueFinalReviewTurn"
    PushBranch {} -> "PushBranch"
    CreateIssue {} -> "CreateIssue"
    CreatePullRequest {} -> "CreatePullRequest"
    UpdatePullRequestBody {} -> "UpdatePullRequestBody"
    UpdateIssueFollowUp {} -> "UpdateIssueFollowUp"
    CloseIssue {} -> "CloseIssue"
    ResolveReviewThread {} -> "ResolveReviewThread"
    RequestChangesReview {} -> "RequestChangesReview"
    DismissRequestChangesReview {} -> "DismissRequestChangesReview"
    RecordIssuePlan {} -> "RecordIssuePlan"
    RecordPlanningGraph {} -> "RecordPlanningGraph"
    RecordBlocked {} -> "RecordBlocked"
    MergePullRequest {} -> "MergePullRequest"
    StopDaemon -> "StopDaemon"
    SleepUntilNextPoll -> "SleepUntilNextPoll"

effectIsReadReviewThreads, effectIsStartPlannerTurn, effectIsStartWorkerTurn, effectIsStartIssuePlanWorkerTurn, effectIsStartIssueImplementationWorkerTurn, effectIsStartReviewerTurn, effectIsStartReviewerVerificationTurn, effectIsStartIssueFinalReviewTurn, effectIsCreateIssue, effectIsCreatePullRequest, effectIsUpdatePullRequestBody, effectIsUpdateIssueFollowUp, effectIsCloseIssue, effectIsResolveReviewThread, effectIsRequestChangesReview, effectIsDismissRequestChangesReview, effectIsRecordIssuePlan, effectIsRecordPlanningGraph, effectIsRecordBlocked, effectIsMergePullRequest, effectIsSleep, effectIsStopDaemon :: SomeEffect -> Bool
effectIsReadReviewThreads (SomeEffect (ReadReviewThreads {})) = True
effectIsReadReviewThreads _ = False
effectIsStartPlannerTurn (SomeEffect (StartPlannerTurn {})) = True
effectIsStartPlannerTurn _ = False
effectIsStartWorkerTurn (SomeEffect (StartWorkerTurn {})) = True
effectIsStartWorkerTurn _ = False
effectIsStartIssuePlanWorkerTurn (SomeEffect (StartIssuePlanWorkerTurn {})) = True
effectIsStartIssuePlanWorkerTurn _ = False
effectIsStartIssueImplementationWorkerTurn (SomeEffect (StartIssueImplementationWorkerTurn {})) = True
effectIsStartIssueImplementationWorkerTurn _ = False
effectIsStartReviewerTurn (SomeEffect (StartReviewerTurn {})) = True
effectIsStartReviewerTurn _ = False
effectIsStartReviewerVerificationTurn (SomeEffect (StartReviewerVerificationTurn {})) = True
effectIsStartReviewerVerificationTurn _ = False
effectIsStartIssueFinalReviewTurn (SomeEffect (StartIssueFinalReviewTurn {})) = True
effectIsStartIssueFinalReviewTurn _ = False
effectIsCreateIssue (SomeEffect (CreateIssue {})) = True
effectIsCreateIssue _ = False
effectIsCreatePullRequest (SomeEffect (CreatePullRequest {})) = True
effectIsCreatePullRequest _ = False
effectIsUpdatePullRequestBody (SomeEffect (UpdatePullRequestBody {})) = True
effectIsUpdatePullRequestBody _ = False
effectIsUpdateIssueFollowUp (SomeEffect (UpdateIssueFollowUp {})) = True
effectIsUpdateIssueFollowUp _ = False
effectIsCloseIssue (SomeEffect (CloseIssue {})) = True
effectIsCloseIssue _ = False
effectIsResolveReviewThread (SomeEffect (ResolveReviewThread {})) = True
effectIsResolveReviewThread _ = False
effectIsRequestChangesReview (SomeEffect (RequestChangesReview {})) = True
effectIsRequestChangesReview _ = False
effectIsDismissRequestChangesReview (SomeEffect (DismissRequestChangesReview {})) = True
effectIsDismissRequestChangesReview _ = False
effectIsRecordIssuePlan (SomeEffect (RecordIssuePlan {})) = True
effectIsRecordIssuePlan _ = False
effectIsRecordPlanningGraph (SomeEffect (RecordPlanningGraph {})) = True
effectIsRecordPlanningGraph _ = False
effectIsRecordBlocked (SomeEffect (RecordBlocked {})) = True
effectIsRecordBlocked _ = False
effectIsMergePullRequest (SomeEffect (MergePullRequest {})) = True
effectIsMergePullRequest _ = False
effectIsSleep (SomeEffect SleepUntilNextPoll) = True
effectIsSleep _ = False
effectIsStopDaemon (SomeEffect StopDaemon) = True
effectIsStopDaemon _ = False

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
step (IssueImplementationReady config Nothing worker) (IssueAttemptBranchAdvanced branch) =
  Decision
    (IssueImplementationReady (config {issueBranch = branch}) Nothing worker)
    [SomeEffect SleepUntilNextPoll]
step (IssueImplementationReady _config (Just prNumber) _worker) (IssueAttemptBranchAdvanced branch) =
  let reason =
        BlockedReason
          ( "cannot advance issue branch to "
              <> unBranchName branch
              <> " after PR #"
              <> Text.pack (show (unPrNumber prNumber))
              <> " is already known"
          )
   in Decision (BlockedState reason) [SomeEffect (RecordBlocked reason), SomeEffect StopDaemon]
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
step (IssueImplementing config maybePr (WorkerActive activeTurn)) (IssueImplementationCompleted prNumber maybeReviewerThreadId)
  | prMatchesKnownStrict maybePr prNumber =
      Decision (IssueHandoffReady config prNumber (WorkerIdle (activeThreadId activeTurn)) (ReviewerIdle <$> maybeReviewerThreadId)) [SomeEffect SleepUntilNextPoll]
  | otherwise =
      prMismatchBlocked maybePr prNumber
step (IssueHandoffReady config expectedPrNumber worker reviewer) (IssueReviewHandoffInitialized prNumber)
  | expectedPrNumber == prNumber =
      Decision (IssueHandoffInitialized config prNumber worker reviewer) [SomeEffect SleepUntilNextPoll]
  | otherwise =
      prMismatchBlocked (Just expectedPrNumber) prNumber
step state@(IssueHandoffInitialized _config expectedPrNumber _worker _reviewer) (IssueReviewHandoffInitialized prNumber)
  | expectedPrNumber == prNumber =
      Decision state [SomeEffect SleepUntilNextPoll]
  | otherwise =
      prMismatchBlocked (Just expectedPrNumber) prNumber
step (IssueHandoffInitialized config expectedPrNumber worker reviewer) (IssueReviewHandoffStarted prNumber)
  | expectedPrNumber == prNumber =
      Decision (IssueWaitingForPrMerge config prNumber worker reviewer) [SomeEffect SleepUntilNextPoll]
  | otherwise =
      prMismatchBlocked (Just expectedPrNumber) prNumber
step state@IssueWaitingForPrMerge {} (IssueReviewHandoffInitialized _prNumber) =
  Decision state [SomeEffect SleepUntilNextPoll]
step state@IssueWaitingForPrMerge {} (IssueReviewHandoffStarted _prNumber) =
  Decision state [SomeEffect SleepUntilNextPoll]
step state@(IssueHandoffReady _config expectedPrNumber _worker _reviewer) (IssueImplementationCompleted prNumber _maybeReviewerThreadId)
  | expectedPrNumber == prNumber =
      Decision state [SomeEffect SleepUntilNextPoll]
  | otherwise =
      prMismatchBlocked (Just expectedPrNumber) prNumber
step state@(IssueHandoffInitialized _config expectedPrNumber _worker _reviewer) (IssueImplementationCompleted prNumber _maybeReviewerThreadId)
  | expectedPrNumber == prNumber =
      Decision state [SomeEffect SleepUntilNextPoll]
  | otherwise =
      prMismatchBlocked (Just expectedPrNumber) prNumber
step state@(IssueWaitingForPrMerge _config expectedPrNumber _worker _reviewer) (IssueImplementationCompleted prNumber _maybeReviewerThreadId)
  | expectedPrNumber == prNumber =
      Decision state [SomeEffect SleepUntilNextPoll]
  | otherwise =
      prMismatchBlocked (Just expectedPrNumber) prNumber
step (IssueWaitingForPrMerge config expectedPrNumber worker reviewer) (IssuePullRequestMerged prNumber)
  | expectedPrNumber == prNumber =
      Decision
        (IssuePostMergeReviewReady config prNumber worker reviewer)
        [SomeEffect SleepUntilNextPoll]
  | otherwise =
      let reason =
            BlockedReason
              ( Text.pack ("issue implementer observed merged PR #" <> show (unPrNumber prNumber))
                  <> Text.pack (" while waiting for PR #" <> show (unPrNumber expectedPrNumber))
              )
       in Decision (BlockedState reason) [SomeEffect (RecordBlocked reason), SomeEffect StopDaemon]
step (IssuePostMergeReviewReady config prNumber worker (Just (ReviewerIdle reviewerThreadId))) (StartIssuePostMergeReview reviewTargetSha activeTurn) =
  Decision
    (IssuePostMergeReviewing config prNumber worker reviewTargetSha (ReviewerActive activeTurn))
    [SomeEffect (StartIssueFinalReviewTurn config prNumber reviewTargetSha reviewerThreadId)]
step (IssuePostMergeReviewReady config prNumber worker _oldReviewer) (IssueReviewerThreadReady reviewerThreadId) =
  Decision
    (IssuePostMergeReviewReady config prNumber worker (Just (ReviewerIdle reviewerThreadId)))
    [SomeEffect SleepUntilNextPoll]
step (IssueHandoffReady config prNumber worker _oldReviewer) (IssueReviewerThreadReady reviewerThreadId) =
  Decision
    (IssueHandoffReady config prNumber worker (Just (ReviewerIdle reviewerThreadId)))
    [SomeEffect SleepUntilNextPoll]
step (IssueHandoffInitialized config prNumber worker _oldReviewer) (IssueReviewerThreadReady reviewerThreadId) =
  Decision
    (IssueHandoffInitialized config prNumber worker (Just (ReviewerIdle reviewerThreadId)))
    [SomeEffect SleepUntilNextPoll]
step (IssueWaitingForPrMerge config prNumber worker _oldReviewer) (IssueReviewerThreadReady reviewerThreadId) =
  Decision
    (IssueWaitingForPrMerge config prNumber worker (Just (ReviewerIdle reviewerThreadId)))
    [SomeEffect SleepUntilNextPoll]
step (IssuePostMergeReviewing config prNumber _worker _reviewTargetSha (ReviewerActive _activeTurn)) (IssuePostMergeReviewSatisfied _evidence) =
  Decision
    (IssueWaitingForIssueClose config prNumber)
    [SomeEffect (CloseIssue config prNumber), SomeEffect SleepUntilNextPoll]
step (IssuePostMergeReviewing config _prNumber (WorkerIdle workerThreadId) _reviewTargetSha (ReviewerActive _activeTurn)) (IssuePostMergeReviewFollowUp evidence) =
  let followUpConfig = postMergeReworkIssueConfig config
   in Decision
        (IssueImplementationReady followUpConfig Nothing (WorkerIdle workerThreadId))
        [SomeEffect (UpdateIssueFollowUp followUpConfig evidence), SomeEffect SleepUntilNextPoll]
step (IssuePostMergeReviewing config prNumber worker _reviewTargetSha (ReviewerActive activeTurn)) (IssuePostMergeReviewIncomplete _reason) =
  Decision
    (IssuePostMergeReviewReady config prNumber worker (Just (ReviewerIdle (activeThreadId activeTurn))))
    [SomeEffect SleepUntilNextPoll]
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
step state@(IssuePostMergeReviewReady {}) (IssuePullRequestMerged _prNumber) =
  Decision state [SomeEffect SleepUntilNextPoll]
step state@(IssuePostMergeReviewing {}) (IssuePullRequestMerged _prNumber) =
  Decision state [SomeEffect SleepUntilNextPoll]
step state@IssueWaitingForIssueClose {} (IssuePullRequestMerged _prNumber) =
  Decision state [SomeEffect SleepUntilNextPoll]
step (PrCheckingReviews config _worker (ReviewerIdle reviewerThreadId)) (ReviewThreadsFound evidence activeTurn) =
  Decision
    (PrFixingReviews config evidence (WorkerActive activeTurn) (ReviewerIdle reviewerThreadId))
    [SomeEffect (StartWorkerTurn (activeThreadId activeTurn))]
step (PrCheckingReviews config (WorkerIdle workerThreadId) _reviewer) (NoReviewThreadsFound commit activeTurn) =
  Decision
    (PrReviewingClean config commit Nothing (WorkerIdle workerThreadId) (ReviewerActive activeTurn))
    [SomeEffect (StartReviewerTurn config commit (activeThreadId activeTurn))]
step (PrVerifyingReviewFix config _oldEvidence _worker (ReviewerIdle reviewerThreadId)) (ReviewThreadsFound evidence activeTurn) =
  Decision
    (PrFixingReviews config evidence (WorkerActive activeTurn) (ReviewerIdle reviewerThreadId))
    [SomeEffect (StartWorkerTurn (activeThreadId activeTurn))]
step (PrVerifyingReviewFix config _oldEvidence (WorkerIdle workerThreadId) _reviewer) (NoReviewThreadsFound commit activeTurn) =
  Decision
    (PrReviewingClean config commit Nothing (WorkerIdle workerThreadId) (ReviewerActive activeTurn))
    [SomeEffect (StartReviewerTurn config commit (activeThreadId activeTurn))]
step (PrVerifyingReviewFix config evidence (WorkerIdle workerThreadId) _reviewer) (StartReviewFixVerification reviewTargetSha activeTurn) =
  Decision
    (PrReviewingClean config reviewTargetSha (Just evidence) (WorkerIdle workerThreadId) (ReviewerActive activeTurn))
    [SomeEffect (StartReviewerVerificationTurn config evidence reviewTargetSha (activeThreadId activeTurn))]
step (PrFixingReviews config evidence (WorkerActive activeTurn) (ReviewerIdle reviewerThreadId)) ReviewFixCompleted =
  Decision
    (PrVerifyingReviewFix config evidence (WorkerIdle (activeThreadId activeTurn)) (ReviewerIdle reviewerThreadId))
    [SomeEffect SleepUntilNextPoll]
step (PrFixingReviews config _evidence (WorkerActive activeTurn) (ReviewerIdle reviewerThreadId)) ReviewFixIncomplete =
  Decision
    (PrCheckingReviews config (WorkerIdle (activeThreadId activeTurn)) (ReviewerIdle reviewerThreadId))
    [SomeEffect (ReadReviewThreads config)]
step (PrReviewingClean config _commit (Just verification) (WorkerIdle workerThreadId) (ReviewerActive activeTurn)) (ReviewerFoundClean evidence resolvedThreadIds)
  | reviewEvidenceHasSummaries verification =
      Decision
        (PrWaitingForMergeability config evidence (WorkerIdle workerThreadId) (ReviewerIdle (activeThreadId activeTurn)))
        (resolveReviewThreads (Just verification) resolvedThreadIds <> [SomeEffect (DismissRequestChangesReview config evidence), SomeEffect SleepUntilNextPoll])
step (PrReviewingClean config _commit (Just verification) (WorkerIdle workerThreadId) (ReviewerActive activeTurn)) (ReviewerFoundClean _evidence resolvedThreadIds) =
  Decision
    (PrCheckingReviews config (WorkerIdle workerThreadId) (ReviewerIdle (activeThreadId activeTurn)))
    (resolveReviewThreads (Just verification) resolvedThreadIds <> [SomeEffect (ReadReviewThreads config)])
step (PrReviewingClean config _commit Nothing (WorkerIdle workerThreadId) (ReviewerActive activeTurn)) (ReviewerFoundClean evidence resolvedThreadIds) =
  Decision
    (PrWaitingForMergeability config evidence (WorkerIdle workerThreadId) (ReviewerIdle (activeThreadId activeTurn)))
    (resolveReviewThreads Nothing resolvedThreadIds <> [SomeEffect SleepUntilNextPoll])
step (PrReviewingClean config _commit verification (WorkerIdle workerThreadId) (ReviewerActive activeTurn)) (ReviewerFoundProblems evidence resolvedThreadIds) =
  Decision
    (PrCheckingReviews config (WorkerIdle workerThreadId) (ReviewerIdle (activeThreadId activeTurn)))
    (resolveReviewThreads verification resolvedThreadIds <> [SomeEffect (RequestChangesReview config evidence), SomeEffect (ReadReviewThreads config)])
step (PrReviewingClean config _commit (Just evidence) (WorkerIdle workerThreadId) (ReviewerActive activeTurn)) ReviewerTurnIncomplete =
  Decision
    (PrVerifyingReviewFix config evidence (WorkerIdle workerThreadId) (ReviewerIdle (activeThreadId activeTurn)))
    [SomeEffect SleepUntilNextPoll]
step (PrReviewingClean config _commit Nothing (WorkerIdle workerThreadId) (ReviewerActive activeTurn)) ReviewerTurnIncomplete =
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

resolveReviewThreads :: Maybe ReviewEvidence -> [ReviewThreadId] -> EffectPlan
resolveReviewThreads Nothing _resolvedThreadIds =
  []
resolveReviewThreads (Just evidence) resolvedThreadIds =
  [ SomeEffect (ResolveReviewThread threadId)
  | threadId <- reviewEvidenceThreadIds evidence
  , threadId `elem` resolvedThreadIds
  ]

postMergeReworkIssueConfig :: IssueConfig -> IssueConfig
postMergeReworkIssueConfig config =
  config {issueBranch = nextIssueAttemptBranch (issueNumber config) (issueBranch config)}

nextIssueAttemptBranch :: IssueNumber -> BranchName -> BranchName
nextIssueAttemptBranch issueNumber' (BranchName currentBranch) =
  BranchName (baseBranch <> "-" <> Text.pack (show (attempt + 1)))
 where
  (baseBranch, attempt) =
    case splitIssueAttemptBranch issueNumber' currentBranch of
      Just parsed -> parsed
      Nothing -> (currentBranch, 1)

splitIssueAttemptBranch :: IssueNumber -> Text.Text -> Maybe (Text.Text, Int)
splitIssueAttemptBranch (IssueNumber issueNumber') branch = do
  let digits = Text.takeWhileEnd isDigit branch
      baseWithDash = Text.dropWhileEnd isDigit branch
      issueSuffix = Text.pack (show issueNumber')
  guard (not (Text.null digits))
  (base, separator) <- Text.unsnoc baseWithDash
  guard (separator == '-')
  guard (issueSuffix `Text.isSuffixOf` base)
  attempt <- parsePositiveInt digits
  pure (base, attempt)

parsePositiveInt :: Text.Text -> Maybe Int
parsePositiveInt digits =
  case Text.foldl' decimalStep (Just 0) digits of
    Just value | value > 0 -> Just value
    _ -> Nothing
 where
  decimalStep Nothing _char = Nothing
  decimalStep (Just value) char
    | isDigit char = Just (value * 10 + fromEnum char - fromEnum '0')
    | otherwise = Nothing
