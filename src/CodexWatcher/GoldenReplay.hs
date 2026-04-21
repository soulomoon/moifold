{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE OverloadedRecordDot #-}

module CodexWatcher.GoldenReplay
  ( SnapshotKind (..)
  , TypedSnapshot (..)
  , ReplayResult (..)
  , normalizeNodeSnapshot
  , replayTypedSnapshot
  , replayNodeSnapshot
  , replayNodeIssueImplementSnapshot
  , replayNodePrReviewSnapshot
  ) where

import CodexWatcher.Snapshot
import CodexWatcher.Types
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Data.Text qualified as Text

data SnapshotKind
  = PrReviewSnapshotKind
  | IssueImplementSnapshotKind
  deriving stock (Eq, Show)

data TypedSnapshot = TypedSnapshot
  { typedKind :: SnapshotKind
  , typedState :: SomeWatcherState
  , typedWarnings :: [Text]
  }
  deriving stock (Show)

data ReplayResult = ReplayResult
  { replayState :: SomeWatcherState
  , replayWarnings :: [Text]
  }
  deriving stock (Show)

normalizeNodeSnapshot :: NodeSnapshot -> Either Text TypedSnapshot
normalizeNodeSnapshot (NodePrReview snapshot) = normalizeNodePrReviewSnapshot snapshot
normalizeNodeSnapshot (NodeIssueImplement snapshot) = normalizeNodeIssueImplementSnapshot snapshot

replayTypedSnapshot :: TypedSnapshot -> Either Text ReplayResult
replayTypedSnapshot snapshot =
  pure ReplayResult
    { replayState = snapshot.typedState
    , replayWarnings = snapshot.typedWarnings
    }

replayNodeSnapshot :: NodeSnapshot -> Either Text ReplayResult
replayNodeSnapshot snapshot = normalizeNodeSnapshot snapshot >>= replayTypedSnapshot

replayNodePrReviewSnapshot :: NodePrReviewSnapshot -> Either Text ReplayResult
replayNodePrReviewSnapshot snapshot = replayNodeSnapshot (NodePrReview snapshot)

replayNodeIssueImplementSnapshot :: NodeIssueImplementSnapshot -> Either Text ReplayResult
replayNodeIssueImplementSnapshot snapshot = replayNodeSnapshot (NodeIssueImplement snapshot)

normalizeNodePrReviewSnapshot :: NodePrReviewSnapshot -> Either Text TypedSnapshot
normalizeNodePrReviewSnapshot snapshot =
  case snapshot.blockedState of
    Just blocked | blocked.blocked ->
      pure (typedPrReview (BlockedState (BlockedReason (fromMaybe "Node watcher blocked without reason" blocked.reason) ) :: WatcherState 'PrReview 'Blocked) [])
    _ ->
      normalizeUnblockedPrReviewSnapshot snapshot

normalizeUnblockedPrReviewSnapshot :: NodePrReviewSnapshot -> Either Text TypedSnapshot
normalizeUnblockedPrReviewSnapshot snapshot
  | Just reason <- snapshot.watcherState.blockedReason =
      pure (typedPrReview (BlockedState (BlockedReason reason) :: WatcherState 'PrReview 'Blocked) [])
  | snapshot.watcherState.lastTurnStatus == Just "merged" =
      pure (typedPrReview (CompleteState (PrMerged (MergeCommit (CommitSha (bestKnownCommit snapshot)))) :: WatcherState 'PrReview 'Complete) (staleReviewerBlockedWarning snapshot))
  | maybe False (.hasUnresolved) (checkerState snapshot) =
      pure (typedPrReview (prCheckingReviewsState snapshot) ["Snapshot has unresolved review threads; replayed to CheckingReviews because no active turn is represented in persisted state."])
  | reviewerSaysClean snapshot =
      pure
        ( typedPrReview
            ( PrMerging
                (toPrConfig snapshot.config)
                (CleanReviewEvidence (CommitSha (bestKnownCommit snapshot)) "LGTM")
                :: WatcherState 'PrReview 'Merging
            )
            []
        )
  | otherwise =
      pure (typedPrReview (prCheckingReviewsState snapshot) [])

normalizeNodeIssueImplementSnapshot :: NodeIssueImplementSnapshot -> Either Text TypedSnapshot
normalizeNodeIssueImplementSnapshot snapshot =
  case snapshot.blockedState of
    Just blocked | blocked.blocked ->
      pure (typedIssueImplement (BlockedState (BlockedReason (fromMaybe "Node issue watcher blocked without reason" blocked.reason)) :: WatcherState 'IssueImplement 'Blocked) [])
    _ ->
      normalizeUnblockedIssueImplementSnapshot snapshot

normalizeUnblockedIssueImplementSnapshot :: NodeIssueImplementSnapshot -> Either Text TypedSnapshot
normalizeUnblockedIssueImplementSnapshot snapshot
  | Just reason <- snapshot.issueState >>= (.issueBlockedReason), issueStatusText snapshot == Just "blocked" =
      pure (typedIssueImplement (BlockedState (BlockedReason reason) :: WatcherState 'IssueImplement 'Blocked) [])
  | Just (purpose, activeTurn) <- activeIssueTurn snapshot =
      replayActiveIssueTurn snapshot purpose activeTurn
  | otherwise =
      replayIdleIssueStatus snapshot (issueStatusText snapshot)

replayActiveIssueTurn :: NodeIssueImplementSnapshot -> Text -> ActiveTurn -> Either Text TypedSnapshot
replayActiveIssueTurn snapshot purpose activeTurn
  | purpose == "triage" =
      pure (typedIssueImplement (IssueTriageActive (toIssueConfig snapshot.config) (WorkerActive activeTurn) :: WatcherState 'IssueImplement 'Triage) [])
  | purpose == "plan" =
      pure (typedIssueImplement (IssueInPlanMode (toIssueConfig snapshot.config) (WorkerActive activeTurn) :: WatcherState 'IssueImplement 'PlanMode) [])
  | purpose == "implement" =
      pure (typedIssueImplement (IssueImplementing (toIssueConfig snapshot.config) (PrNumber <$> (snapshot.issueState >>= (.issuePrNumber))) (WorkerActive activeTurn) :: WatcherState 'IssueImplement 'Implementing) [])
  | otherwise =
      pure
        ( typedIssueImplement
            (IssueNeedsTriage (toIssueConfig snapshot.config) (WorkerIdle (ThreadId snapshot.config.threadId)) :: WatcherState 'IssueImplement 'Triage)
            ["Unknown active issue turn purpose: " <> purpose]
        )

replayIdleIssueStatus :: NodeIssueImplementSnapshot -> Maybe Text -> Either Text TypedSnapshot
replayIdleIssueStatus snapshot status =
  case status of
    Nothing ->
      pure (typedIssueImplement (IssueNeedsTriage config worker :: WatcherState 'IssueImplement 'Triage) [])
    Just "blocked" ->
      pure (typedIssueImplement (BlockedState (BlockedReason (fromMaybe "Issue worker reported blocked without reason" (snapshot.issueState >>= (.issueBlockedReason)))) :: WatcherState 'IssueImplement 'Blocked) [])
    Just "already_resolved" ->
      pure (typedIssueImplement (CompleteState (IssueAlreadyResolved (IssueNumber snapshot.config.issueNumber)) :: WatcherState 'IssueImplement 'Complete) [])
    Just "needs_implementation" ->
      pure (typedIssueImplement (IssuePlanReady config worker :: WatcherState 'IssueImplement 'PlanMode) [])
    Just "plan_ready" ->
      pure
        ( typedIssueImplement
            (IssuePlanReady config worker :: WatcherState 'IssueImplement 'PlanMode)
            ["Issue plan is ready; next step should create/update the PR before implementation."]
        )
    Just "in_progress" ->
      pure (typedIssueImplement (IssueImplementationReady config maybePr worker :: WatcherState 'IssueImplement 'Implementing) [])
    Just "incomplete" ->
      pure
        ( typedIssueImplement
            (IssueImplementationReady config maybePr worker :: WatcherState 'IssueImplement 'Implementing)
            ["Issue implementation is incomplete; watcher should immediately continue implementation."]
        )
    Just "complete" ->
      case maybePr of
        Just pr -> pure (typedIssueImplement (CompleteState (IssueComplete pr) :: WatcherState 'IssueImplement 'Complete) [])
        Nothing -> pure (typedIssueImplement (BlockedState (BlockedReason "Issue state is complete but pr_number is missing") :: WatcherState 'IssueImplement 'Blocked) [])
    Just unknown ->
      pure
        ( typedIssueImplement
            (IssueNeedsTriage config worker :: WatcherState 'IssueImplement 'Triage)
            ["Unknown issue_status: " <> unknown]
        )
 where
  config = toIssueConfig snapshot.config
  worker = WorkerIdle (ThreadId snapshot.config.threadId)
  maybePr = PrNumber <$> (snapshot.issueState >>= (.issuePrNumber))

typedPrReview :: WatcherState 'PrReview phase -> [Text] -> TypedSnapshot
typedPrReview state warnings =
  TypedSnapshot
    { typedKind = PrReviewSnapshotKind
    , typedState = SomeWatcherState state
    , typedWarnings = warnings
    }

typedIssueImplement :: WatcherState 'IssueImplement phase -> [Text] -> TypedSnapshot
typedIssueImplement state warnings =
  TypedSnapshot
    { typedKind = IssueImplementSnapshotKind
    , typedState = SomeWatcherState state
    , typedWarnings = warnings
    }

toPrConfig :: NodePrReviewConfig -> PrConfig
toPrConfig config =
  PrConfig (RepoName config.repoFullName) (PrNumber config.prNumber) (BranchName config.branch)

toIssueConfig :: NodeIssueImplementConfig -> IssueConfig
toIssueConfig config =
  IssueConfig (RepoName config.repoFullName) (IssueNumber config.issueNumber) (BranchName config.branch)

prCheckingReviewsState :: NodePrReviewSnapshot -> WatcherState 'PrReview 'CheckingReviews
prCheckingReviewsState snapshot =
  PrCheckingReviews
    (toPrConfig snapshot.config)
    (WorkerIdle (ThreadId snapshot.config.threadId))
    (ReviewerIdle (ThreadId (fromMaybe snapshot.config.threadId snapshot.config.reviewerThreadId)))

reviewerSaysClean :: NodePrReviewSnapshot -> Bool
reviewerSaysClean snapshot =
  maybe False ((`elem` ["clean", "approved", "lgtm"]) . Text.toLower) (snapshot.reviewerState >>= (.reviewStatus))

issueStatusText :: NodeIssueImplementSnapshot -> Maybe Text
issueStatusText snapshot = snapshot.issueState >>= (.issueStatus)

activeIssueTurn :: NodeIssueImplementSnapshot -> Maybe (Text, ActiveTurn)
activeIssueTurn snapshot = do
  daemon <- snapshot.daemonState
  turnId <- daemon.activeTurnId
  purpose <- daemon.activeTurnPurpose
  pure (purpose, ActiveTurn (ThreadId snapshot.config.threadId) (TurnId turnId))

bestKnownCommit :: NodePrReviewSnapshot -> Text
bestKnownCommit snapshot =
  firstJust
    [ snapshot.watcherState.lastReviewTargetSha
    , snapshot.watcherState.lastReviewerTargetSha
    , snapshot.agentState >>= (.publishedCommitSha)
    , snapshot.reviewerState >>= (.reviewedCommitSha)
    ]
    "unknown-commit"

staleReviewerBlockedWarning :: NodePrReviewSnapshot -> [Text]
staleReviewerBlockedWarning snapshot =
  case snapshot.reviewerState >>= (.blockedReason) of
    Just reason -> ["Ignoring stale reviewer blocked reason for merged PR snapshot: " <> reason]
    Nothing -> []

firstJust :: [Maybe a] -> a -> a
firstJust [] fallback = fallback
firstJust (Just value : _) _ = value
firstJust (Nothing : rest) fallback = firstJust rest fallback
