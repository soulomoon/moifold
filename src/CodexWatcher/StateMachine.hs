{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
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
import CodexWatcher.Core.Kinds (Domain (..), KnownPhase, Phase (..), SActionKind (..), ThreadActivity (..))
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
  , ReviewContext (..)
  , SomeReviewContext (..)
  , normalReviewContext
  , verificationReviewContext
  , reviewEvidenceHasSummaries
  , reviewEvidenceThreadComments
  , reviewEvidenceThreadIds
  )
import Control.Monad (guard)
import Data.Foldable qualified as Foldable
import Data.Char (isDigit)
import Data.List.NonEmpty (NonEmpty)
import Data.Kind (Constraint)
import qualified Data.Text as Text
import Data.Type.Equality ((:~:) (Refl))
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
  IssueWorkerThreadReady :: ThreadId -> Event 'IssueImplement phase
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
  MergeabilityFixRequired :: ReviewEvidence -> Event 'PrReview 'WaitingMergeability
  MergeCompleted :: MergeCommit -> Event 'PrReview 'Merging

  MarkBlocked :: CanBlock phase => BlockedReason -> Event domain phase
  StopWatcher :: StopReason -> Event domain phase

data Decision (domain :: Domain) where
  Decision
    :: KnownPhase nextPhase
    => WatcherState domain nextPhase
    -> EffectPlan
    -> Decision domain

data ActionPermission (domain :: Domain) (phase :: Phase) (action :: ActionKind) where
  ActionPermission :: ActionPermission domain phase action

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
effectAllowedForState (SomeWatcherState state) (SomeEffect effect) =
  case checkActionPermission state (effectActionSing effect) of
    Just ActionPermission -> True
    Nothing -> False

checkActionPermission
  :: WatcherState domain phase
  -> SActionKind action
  -> Maybe (ActionPermission domain phase action)
checkActionPermission state action
  | commonActionAllowed action = Just ActionPermission
  | otherwise =
      case state of
        PlanningReady {} ->
          allowOneOf [SomeEffectAction SStartPlannerTurnAction] action
        PlanningTurnActive {} ->
          allowOneOf [SomeEffectAction SCreateIssueAction, SomeEffectAction SRecordPlanningGraphAction, SomeEffectAction SSleepUntilNextPollAction] action
        PlanningWaitingForReadyIssues {} ->
          allowOneOf [SomeEffectAction SSleepUntilNextPollAction] action
        IssueReadyToPlan {} ->
          allowOneOf [SomeEffectAction SStartIssuePlanWorkerTurnAction, SomeEffectAction SSleepUntilNextPollAction] action
        IssueInPlanMode {} ->
          allowOneOf [SomeEffectAction SRecordIssuePlanAction, SomeEffectAction SSleepUntilNextPollAction] action
        IssuePlanReady {} ->
          allowOneOf [SomeEffectAction SRecordIssuePlanAction, SomeEffectAction SUpdatePullRequestBodyAction, SomeEffectAction SSleepUntilNextPollAction] action
        IssueImplementationReady {} ->
          allowOneOf [SomeEffectAction SCreatePullRequestAction, SomeEffectAction SStartIssueImplementationWorkerTurnAction, SomeEffectAction SSleepUntilNextPollAction] action
        IssueImplementing {} ->
          allowOneOf [SomeEffectAction SStartIssueImplementationWorkerTurnAction, SomeEffectAction SSleepUntilNextPollAction] action
        IssueHandoffReady {} ->
          allowOneOf [SomeEffectAction SSleepUntilNextPollAction] action
        IssueHandoffInitialized {} ->
          allowOneOf [SomeEffectAction SSleepUntilNextPollAction] action
        IssueWaitingForPrMerge {} ->
          allowOneOf [SomeEffectAction SSleepUntilNextPollAction] action
        IssuePostMergeReviewPendingReviewer {} ->
          allowOneOf [SomeEffectAction SSleepUntilNextPollAction] action
        IssuePostMergeReviewReady {} ->
          allowOneOf [SomeEffectAction SStartIssueFinalReviewTurnAction, SomeEffectAction SSleepUntilNextPollAction] action
        IssuePostMergeReviewing {} ->
          allowOneOf [SomeEffectAction SCloseIssueAction, SomeEffectAction SUpdateIssueFollowUpAction, SomeEffectAction SSleepUntilNextPollAction] action
        IssueWaitingForIssueClose {} ->
          allowOneOf [SomeEffectAction SCloseIssueAction, SomeEffectAction SSleepUntilNextPollAction] action
        PrCheckingReviews {} ->
          allowOneOf [SomeEffectAction SStartWorkerTurnAction, SomeEffectAction SStartReviewerTurnAction] action
        PrFixingReviews {} ->
          allowOneOf [SomeEffectAction SReadReviewThreadsAction, SomeEffectAction SSleepUntilNextPollAction] action
        PrReviewFixQueued {} ->
          allowOneOf [SomeEffectAction SStartWorkerTurnAction, SomeEffectAction SSleepUntilNextPollAction] action
        PrVerifyingReviewFix {} ->
          allowOneOf [SomeEffectAction SStartWorkerTurnAction, SomeEffectAction SStartReviewerTurnAction, SomeEffectAction SStartReviewerVerificationTurnAction] action
        PrReviewingClean {} ->
          allowOneOf
            [ SomeEffectAction SResolveReviewThreadAction
            , SomeEffectAction SReplyReviewThreadAction
            , SomeEffectAction SPublishReviewFindingsAction
            , SomeEffectAction SReadReviewThreadsAction
            , SomeEffectAction SSleepUntilNextPollAction
            ]
            action
        PrWaitingForMergeability {} ->
          allowOneOf [SomeEffectAction SMergePullRequestAction, SomeEffectAction SReadReviewThreadsAction, SomeEffectAction SPublishReviewFindingsAction, SomeEffectAction SSleepUntilNextPollAction] action
        PrMerging {} ->
          allowOneOf [SomeEffectAction SSleepUntilNextPollAction] action
        BlockedState {} ->
          allowOneOf [SomeEffectAction SStopDaemonAction] action
        CompleteState {} ->
          allowOneOf [SomeEffectAction SStopDaemonAction] action
        StoppedState {} ->
          allowOneOf [SomeEffectAction SStopDaemonAction] action

commonActionAllowed :: SActionKind action -> Bool
commonActionAllowed SRecordBlockedAction = True
commonActionAllowed SStopDaemonAction = True
commonActionAllowed _ = False

allowOneOf
  :: [SomeEffectAction]
  -> SActionKind action
  -> Maybe (ActionPermission domain phase action)
allowOneOf allowed action =
  if any (`sameAction` action) allowed
    then Just ActionPermission
    else Nothing

sameAction :: SomeEffectAction -> SActionKind action -> Bool
sameAction (SomeEffectAction left) right =
  case left `sameActionKind` right of
    Just Refl -> True
    Nothing -> False

sameActionKind :: SActionKind left -> SActionKind right -> Maybe (left :~: right)
sameActionKind SReadOpenIssuesAction SReadOpenIssuesAction = Just Refl
sameActionKind SReadOpenPullRequestsAction SReadOpenPullRequestsAction = Just Refl
sameActionKind SReadReviewThreadsAction SReadReviewThreadsAction = Just Refl
sameActionKind SStartPlannerTurnAction SStartPlannerTurnAction = Just Refl
sameActionKind SStartWorkerTurnAction SStartWorkerTurnAction = Just Refl
sameActionKind SStartIssuePlanWorkerTurnAction SStartIssuePlanWorkerTurnAction = Just Refl
sameActionKind SStartIssueImplementationWorkerTurnAction SStartIssueImplementationWorkerTurnAction = Just Refl
sameActionKind SStartReviewerTurnAction SStartReviewerTurnAction = Just Refl
sameActionKind SStartReviewerVerificationTurnAction SStartReviewerVerificationTurnAction = Just Refl
sameActionKind SStartIssueFinalReviewTurnAction SStartIssueFinalReviewTurnAction = Just Refl
sameActionKind SPushBranchAction SPushBranchAction = Just Refl
sameActionKind SCreateIssueAction SCreateIssueAction = Just Refl
sameActionKind SCreatePullRequestAction SCreatePullRequestAction = Just Refl
sameActionKind SUpdatePullRequestBodyAction SUpdatePullRequestBodyAction = Just Refl
sameActionKind SUpdateIssueFollowUpAction SUpdateIssueFollowUpAction = Just Refl
sameActionKind SCloseIssueAction SCloseIssueAction = Just Refl
sameActionKind SResolveReviewThreadAction SResolveReviewThreadAction = Just Refl
sameActionKind SReplyReviewThreadAction SReplyReviewThreadAction = Just Refl
sameActionKind SPublishReviewFindingsAction SPublishReviewFindingsAction = Just Refl
sameActionKind SRecordIssuePlanAction SRecordIssuePlanAction = Just Refl
sameActionKind SRecordPlanningGraphAction SRecordPlanningGraphAction = Just Refl
sameActionKind SRecordBlockedAction SRecordBlockedAction = Just Refl
sameActionKind SMergePullRequestAction SMergePullRequestAction = Just Refl
sameActionKind SStopDaemonAction SStopDaemonAction = Just Refl
sameActionKind SSleepUntilNextPollAction SSleepUntilNextPollAction = Just Refl
sameActionKind _ _ = Nothing

someEffectName :: SomeEffect -> Text.Text
someEffectName effect =
  case someEffectAction effect of
    SomeEffectAction action -> actionKindText action

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
step (IssueReadyToPlan config prNumber _oldWorker) (IssueWorkerThreadReady threadId) =
  Decision
    (IssueReadyToPlan config prNumber (WorkerIdle threadId))
    [SomeEffect SleepUntilNextPoll]
step (IssueInPlanMode config prNumber (WorkerActive activeTurn)) (IssuePlanCompleted planMarkdown maybeNextTurn) =
  let nextTurn = maybe activeTurn id maybeNextTurn
   in Decision
        (IssuePlanReady config prNumber (WorkerIdle (activeThreadId nextTurn)))
        [SomeEffect (RecordIssuePlan config prNumber planMarkdown), SomeEffect SleepUntilNextPoll]
step (IssuePlanReady config prNumber _oldWorker) (IssueWorkerThreadReady threadId) =
  Decision
    (IssuePlanReady config prNumber (WorkerIdle threadId))
    [SomeEffect SleepUntilNextPoll]
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
step (IssueImplementationReady config maybePr _oldWorker) (IssueWorkerThreadReady threadId) =
  Decision
    (IssueImplementationReady config maybePr (WorkerIdle threadId))
    [SomeEffect SleepUntilNextPoll]
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
step (IssueWaitingForPrMerge config expectedPrNumber worker maybeReviewer) (IssuePullRequestMerged prNumber)
  | expectedPrNumber == prNumber =
      Decision
        (postMergeReviewState config prNumber worker maybeReviewer)
        [SomeEffect SleepUntilNextPoll]
  | otherwise =
      let reason =
            BlockedReason
              ( Text.pack ("issue implementer observed merged PR #" <> show (unPrNumber prNumber))
                  <> Text.pack (" while waiting for PR #" <> show (unPrNumber expectedPrNumber))
              )
       in Decision (BlockedState reason) [SomeEffect (RecordBlocked reason), SomeEffect StopDaemon]
step (IssuePostMergeReviewReady config prNumber worker (ReviewerIdle reviewerThreadId)) (StartIssuePostMergeReview reviewTargetSha activeTurn) =
  Decision
    (IssuePostMergeReviewing config prNumber worker reviewTargetSha (ReviewerActive activeTurn))
    [SomeEffect (StartIssueFinalReviewTurn config prNumber reviewTargetSha reviewerThreadId)]
step (IssuePostMergeReviewPendingReviewer config prNumber worker) (IssueReviewerThreadReady reviewerThreadId) =
  postMergeReviewerReady config prNumber worker reviewerThreadId
step (IssuePostMergeReviewReady config prNumber worker _oldReviewer) (IssueReviewerThreadReady reviewerThreadId) =
  postMergeReviewerReady config prNumber worker reviewerThreadId
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
    (IssuePostMergeReviewReady config prNumber worker (ReviewerIdle (activeThreadId activeTurn)))
    [SomeEffect SleepUntilNextPoll]
step (IssueWaitingForIssueClose _config expectedPrNumber) (IssueClosed prNumber)
  | expectedPrNumber == prNumber =
      Decision
        (CompleteState (IssueComplete prNumber))
        [SomeEffect StopDaemon]
  | otherwise =
      prMismatchBlocked (Just expectedPrNumber) prNumber
step state@(IssueImplementing {}) (IssuePullRequestMerged _prNumber) =
  ignoreMergedPrEvent state
step state@(IssueImplementationReady {}) (IssuePullRequestMerged _prNumber) =
  ignoreMergedPrEvent state
step state@(IssueHandoffReady {}) (IssuePullRequestMerged _prNumber) =
  ignoreMergedPrEvent state
step state@(IssueHandoffInitialized {}) (IssuePullRequestMerged _prNumber) =
  ignoreMergedPrEvent state
step state@(IssuePostMergeReviewPendingReviewer {}) (IssuePullRequestMerged _prNumber) =
  ignoreMergedPrEvent state
step state@(IssuePostMergeReviewReady {}) (IssuePullRequestMerged _prNumber) =
  ignoreMergedPrEvent state
step state@(IssuePostMergeReviewing {}) (IssuePullRequestMerged _prNumber) =
  ignoreMergedPrEvent state
step state@IssueWaitingForIssueClose {} (IssuePullRequestMerged _prNumber) =
  ignoreMergedPrEvent state
step (PrCheckingReviews config _worker (ReviewerIdle reviewerThreadId)) (ReviewThreadsFound evidence activeTurn) =
  startPrReviewWorker config evidence activeTurn reviewerThreadId
step (PrReviewFixQueued config _queuedEvidence _worker (ReviewerIdle reviewerThreadId)) (ReviewThreadsFound evidence activeTurn) =
  startPrReviewWorker config evidence activeTurn reviewerThreadId
step (PrCheckingReviews config (WorkerIdle workerThreadId) _reviewer) (NoReviewThreadsFound commit activeTurn) =
  startCleanReviewer config workerThreadId commit activeTurn
step (PrVerifyingReviewFix config _oldEvidence _worker (ReviewerIdle reviewerThreadId)) (ReviewThreadsFound evidence activeTurn) =
  startPrReviewWorker config evidence activeTurn reviewerThreadId
step (PrVerifyingReviewFix config _oldEvidence (WorkerIdle workerThreadId) _reviewer) (NoReviewThreadsFound commit activeTurn) =
  startCleanReviewer config workerThreadId commit activeTurn
step (PrVerifyingReviewFix config evidence (WorkerIdle workerThreadId) _reviewer) (StartReviewFixVerification reviewTargetSha activeTurn) =
  Decision
    (PrReviewingClean config reviewTargetSha (verificationReviewContext evidence) (WorkerIdle workerThreadId) (ReviewerActive activeTurn))
    [SomeEffect (StartReviewerVerificationTurn config evidence reviewTargetSha (activeThreadId activeTurn))]
step (PrFixingReviews config evidence (WorkerActive activeTurn) (ReviewerIdle reviewerThreadId)) ReviewFixCompleted =
  Decision
    (PrVerifyingReviewFix config evidence (WorkerIdle (activeThreadId activeTurn)) (ReviewerIdle reviewerThreadId))
    [SomeEffect SleepUntilNextPoll]
step (PrFixingReviews config _evidence (WorkerActive activeTurn) (ReviewerIdle reviewerThreadId)) ReviewFixIncomplete =
  Decision
    (PrReviewFixQueued config _evidence (WorkerIdle (activeThreadId activeTurn)) (ReviewerIdle reviewerThreadId))
    [SomeEffect SleepUntilNextPoll]
step (PrReviewingClean config _commit (SomeReviewContext (VerificationReviewContext verification)) (WorkerIdle workerThreadId) (ReviewerActive activeTurn)) (ReviewerFoundClean _evidence resolvedThreadIds) =
  recheckPrReviews config workerThreadId (activeThreadId activeTurn) (resolveReviewThreads (verificationReviewContext verification) resolvedThreadIds)
step (PrReviewingClean config _commit (SomeReviewContext NormalReviewContext) (WorkerIdle workerThreadId) (ReviewerActive activeTurn)) (ReviewerFoundClean evidence resolvedThreadIds) =
  Decision
    (PrWaitingForMergeability config evidence (WorkerIdle workerThreadId) (ReviewerIdle (activeThreadId activeTurn)))
    (resolveReviewThreads normalReviewContext resolvedThreadIds <> [SomeEffect SleepUntilNextPoll])
step (PrReviewingClean config _commit reviewContext (WorkerIdle workerThreadId) (ReviewerActive activeTurn)) (ReviewerFoundProblems evidence resolvedThreadIds) =
  Decision
    (PrReviewFixQueued config evidence (WorkerIdle workerThreadId) (ReviewerIdle (activeThreadId activeTurn)))
    (resolveReviewThreads reviewContext resolvedThreadIds <> replyReviewThreads evidence <> publishReviewFindingsWhenNeeded config evidence <> [SomeEffect SleepUntilNextPoll])
step (PrReviewingClean config _commit (SomeReviewContext (VerificationReviewContext evidence)) (WorkerIdle workerThreadId) (ReviewerActive activeTurn)) ReviewerTurnIncomplete =
  Decision
    (PrVerifyingReviewFix config evidence (WorkerIdle workerThreadId) (ReviewerIdle (activeThreadId activeTurn)))
    [SomeEffect SleepUntilNextPoll]
step (PrReviewingClean config _commit (SomeReviewContext NormalReviewContext) (WorkerIdle workerThreadId) (ReviewerActive activeTurn)) ReviewerTurnIncomplete =
  recheckPrReviews config workerThreadId (activeThreadId activeTurn) []
step (PrWaitingForMergeability config evidence _worker _reviewer) MergeabilityClean =
  Decision
    (PrMerging config evidence)
    [SomeEffect (MergePullRequest (prNumber config) evidence)]
step state@PrWaitingForMergeability {} (MergeabilityRetryLater _reason) =
  Decision state [SomeEffect SleepUntilNextPoll]
step (PrWaitingForMergeability config _evidence (WorkerIdle workerThreadId) (ReviewerIdle reviewerThreadId)) (MergeabilityRecheckReviews _reason) =
  recheckPrReviews config workerThreadId reviewerThreadId []
step (PrWaitingForMergeability config _cleanEvidence (WorkerIdle workerThreadId) (ReviewerIdle reviewerThreadId)) (MergeabilityFixRequired evidence) =
  Decision
    (PrReviewFixQueued config evidence (WorkerIdle workerThreadId) (ReviewerIdle reviewerThreadId))
    [SomeEffect (PublishReviewFindings config evidence), SomeEffect SleepUntilNextPoll]
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

postMergeReviewState :: IssueConfig -> PrNumber -> WorkerThread 'Idle -> Maybe (ReviewerThread 'Idle) -> WatcherState 'IssueImplement 'Implementing
postMergeReviewState config prNumber worker Nothing =
  IssuePostMergeReviewPendingReviewer config prNumber worker
postMergeReviewState config prNumber worker (Just reviewer) =
  IssuePostMergeReviewReady config prNumber worker reviewer

postMergeReviewerReady :: IssueConfig -> PrNumber -> WorkerThread 'Idle -> ThreadId -> Decision 'IssueImplement
postMergeReviewerReady config prNumber worker reviewerThreadId =
  Decision
    (IssuePostMergeReviewReady config prNumber worker (ReviewerIdle reviewerThreadId))
    [SomeEffect SleepUntilNextPoll]

ignoreMergedPrEvent :: WatcherState 'IssueImplement 'Implementing -> Decision 'IssueImplement
ignoreMergedPrEvent state =
  Decision state [SomeEffect SleepUntilNextPoll]

resolveReviewThreads :: SomeReviewContext -> [ReviewThreadId] -> EffectPlan
resolveReviewThreads (SomeReviewContext NormalReviewContext) _resolvedThreadIds =
  []
resolveReviewThreads (SomeReviewContext (VerificationReviewContext evidence)) resolvedThreadIds =
  [ SomeEffect (ResolveReviewThread threadId)
  | threadId <- reviewEvidenceThreadIds evidence
  , threadId `elem` resolvedThreadIds
  ]

replyReviewThreads :: ReviewEvidence -> EffectPlan
replyReviewThreads evidence =
  [ SomeEffect (ReplyReviewThread threadId comment)
  | (threadId, comment) <- reviewEvidenceThreadComments evidence
  ]

publishReviewFindingsWhenNeeded :: PrConfig -> ReviewEvidence -> EffectPlan
publishReviewFindingsWhenNeeded config evidence
  | reviewEvidenceHasSummaries evidence = [SomeEffect (PublishReviewFindings config evidence)]
  | otherwise = []

startPrReviewWorker :: PrConfig -> ReviewEvidence -> ActiveTurn -> ThreadId -> Decision 'PrReview
startPrReviewWorker config evidence activeTurn reviewerThreadId =
  Decision
    (PrFixingReviews config evidence (WorkerActive activeTurn) (ReviewerIdle reviewerThreadId))
    [SomeEffect (StartWorkerTurn evidence (activeThreadId activeTurn))]

startCleanReviewer :: PrConfig -> ThreadId -> CommitSha -> ActiveTurn -> Decision 'PrReview
startCleanReviewer config workerThreadId commit activeTurn =
  Decision
    (PrReviewingClean config commit normalReviewContext (WorkerIdle workerThreadId) (ReviewerActive activeTurn))
    [SomeEffect (StartReviewerTurn config commit (activeThreadId activeTurn))]

recheckPrReviews :: PrConfig -> ThreadId -> ThreadId -> EffectPlan -> Decision 'PrReview
recheckPrReviews config workerThreadId reviewerThreadId beforeReadEffects =
  Decision
    (PrCheckingReviews config (WorkerIdle workerThreadId) (ReviewerIdle reviewerThreadId))
    (beforeReadEffects <> [SomeEffect (ReadReviewThreads config)])

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
