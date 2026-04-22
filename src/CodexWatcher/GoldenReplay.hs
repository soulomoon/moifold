{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE LambdaCase #-}
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
  , bootstrapNodeSnapshotEvents
  , bootstrapNodePrReviewSnapshotEvents
  , bootstrapNodeIssueImplementSnapshotEvents
  ) where

import CodexWatcher.EventLog (WatcherEvent (..))
import CodexWatcher.Snapshot
import CodexWatcher.Types
import Control.Applicative (asum)
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

bootstrapNodeSnapshotEvents :: NodeSnapshot -> [WatcherEvent]
bootstrapNodeSnapshotEvents = \case
  NodePrReview snapshot -> bootstrapNodePrReviewSnapshotEvents snapshot
  NodeIssueImplement snapshot -> bootstrapNodeIssueImplementSnapshotEvents snapshot

bootstrapNodePrReviewSnapshotEvents :: NodePrReviewSnapshot -> [WatcherEvent]
bootstrapNodePrReviewSnapshotEvents snapshot =
  case snapshot.blockedState of
    Just blocked | blocked.blocked ->
      initialEvents <> [WatcherBlocked (BlockedReason (fromMaybe "Node watcher blocked without reason" blocked.reason))]
    _ ->
      bootstrapUnblockedPrReviewSnapshotEvents snapshot initialEvents
 where
  initialEvents =
    [ PrReviewInitialized
        (toPrConfig snapshot.config)
        (ThreadId snapshot.config.threadId)
        (ThreadId (fromMaybe snapshot.config.threadId snapshot.config.reviewerThreadId))
    ]

bootstrapUnblockedPrReviewSnapshotEvents :: NodePrReviewSnapshot -> [WatcherEvent] -> [WatcherEvent]
bootstrapUnblockedPrReviewSnapshotEvents snapshot initialEvents
  | Just reason <- snapshot.watcherState.blockedReason =
      initialEvents <> [WatcherBlocked (BlockedReason reason)]
  | snapshot.watcherState.lastTurnStatus == Just "merged" =
      reviewerCleanEvents <> [PrReviewMergeCompleted (MergeCommit commit)]
  | reviewerSaysClean snapshot =
      reviewerCleanEvents
  | otherwise =
      initialEvents
 where
  commit = CommitSha (bestKnownCommit snapshot)
  reviewerCleanEvents =
    initialEvents
      <> [ PrReviewNoUnresolvedFound commit bootstrapReviewerTurn
         , PrReviewCleanFound (CleanReviewEvidence commit "LGTM")
         ]

bootstrapNodeIssueImplementSnapshotEvents :: NodeIssueImplementSnapshot -> [WatcherEvent]
bootstrapNodeIssueImplementSnapshotEvents snapshot =
  case snapshot.blockedState of
    Just blocked | blocked.blocked ->
      initialEvents <> [WatcherBlocked (BlockedReason (fromMaybe "Node issue watcher blocked without reason" blocked.reason))]
    _ ->
      bootstrapUnblockedIssueImplementSnapshotEvents snapshot initialEvents
 where
  initialEvents =
    [ IssueImplementInitialized
        (toIssueConfig snapshot.config)
        (ThreadId snapshot.config.threadId)
    ]

bootstrapUnblockedIssueImplementSnapshotEvents :: NodeIssueImplementSnapshot -> [WatcherEvent] -> [WatcherEvent]
bootstrapUnblockedIssueImplementSnapshotEvents snapshot initialEvents
  | Just reason <- snapshot.issueState >>= (.issueBlockedReason), issueStatusText snapshot == Just "blocked" =
      initialEvents <> [WatcherBlocked (BlockedReason reason)]
  | Just (purpose, activeTurn) <- activeIssueTurn snapshot =
      bootstrapActiveIssueTurnEvents snapshot initialEvents purpose activeTurn
  | otherwise =
      bootstrapIdleIssueStatusEvents snapshot initialEvents (issueStatusText snapshot)

bootstrapActiveIssueTurnEvents :: NodeIssueImplementSnapshot -> [WatcherEvent] -> Text -> ActiveTurn -> [WatcherEvent]
bootstrapActiveIssueTurnEvents snapshot initialEvents purpose activeTurn
  | purpose == "triage" =
      initialEvents <> [IssueTriageTurnStartedEvent activeTurn.activeTurnId]
  | purpose == "plan" =
      initialEvents <> [IssuePlanTurnStartedEvent activeTurn.activeTurnId]
  | purpose == "implement" =
      bootstrapImplementationReadyEvents snapshot initialEvents
        <> [IssueImplementationTurnStartedEvent activeTurn.activeTurnId]
  | otherwise =
      initialEvents

bootstrapIdleIssueStatusEvents :: NodeIssueImplementSnapshot -> [WatcherEvent] -> Maybe Text -> [WatcherEvent]
bootstrapIdleIssueStatusEvents snapshot initialEvents = \case
  Nothing ->
    initialEvents
  Just "blocked" ->
    initialEvents <> [WatcherBlocked (BlockedReason (fromMaybe "Issue worker reported blocked without reason" (snapshot.issueState >>= (.issueBlockedReason))))]
  Just "already_resolved" ->
    initialEvents
      <> [ IssueTriageTurnStartedEvent bootstrapTriageTurn
         , IssueTriageAlreadyFixedEvent
         ]
  Just "needs_implementation" ->
    initialEvents
      <> [ IssueTriageTurnStartedEvent bootstrapTriageTurn
         , IssueTriageNeedsImplementationEvent
         ]
  Just "plan_ready" ->
    initialEvents
      <> [ IssueTriageTurnStartedEvent bootstrapTriageTurn
         , IssueTriageNeedsImplementationEvent
         ]
  Just "in_progress" ->
    bootstrapImplementationReadyEvents snapshot initialEvents
  Just "incomplete" ->
    bootstrapImplementationReadyEvents snapshot initialEvents
  Just "complete" ->
    case snapshotPrNumber snapshot of
      Just prNumber ->
        bootstrapImplementationReadyEvents snapshot initialEvents
          <> [ IssueReviewHandoffInitializedEvent prNumber
             , IssueReviewHandoffStartedEvent prNumber
             , IssuePullRequestMergedEvent prNumber
             ]
      Nothing ->
        initialEvents <> [WatcherBlocked (BlockedReason "Issue state is complete but pr_number is missing")]
  Just _unknown ->
    initialEvents

bootstrapImplementationReadyEvents :: NodeIssueImplementSnapshot -> [WatcherEvent] -> [WatcherEvent]
bootstrapImplementationReadyEvents snapshot initialEvents =
  initialEvents
    <> [ IssuePlanTurnStartedEvent bootstrapPlanTurn
       , IssuePlanCompletedEvent Nothing
       ]
    <> maybe [] (\prNumber -> [IssuePullRequestReusedEvent prNumber]) (snapshotPrNumber snapshot)

snapshotPrNumber :: NodeIssueImplementSnapshot -> Maybe PrNumber
snapshotPrNumber snapshot =
  PrNumber <$> (snapshot.issueState >>= (.issuePrNumber))

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
    Just "waiting_pr_merge" ->
      case maybePr of
        Just pr -> pure (typedIssueImplement (IssueWaitingForPrMerge config pr :: WatcherState 'IssueImplement 'Implementing) [])
        Nothing -> pure (typedIssueImplement (BlockedState (BlockedReason "Issue state is waiting_pr_merge but pr_number is missing") :: WatcherState 'IssueImplement 'Blocked) [])
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
  fromMaybe
    "unknown-commit"
    ( asum
        [ snapshot.watcherState.lastReviewTargetSha
        , snapshot.watcherState.lastReviewerTargetSha
        , snapshot.agentState >>= (.publishedCommitSha)
        , snapshot.reviewerState >>= (.reviewedCommitSha)
        ]
    )

staleReviewerBlockedWarning :: NodePrReviewSnapshot -> [Text]
staleReviewerBlockedWarning snapshot =
  case snapshot.reviewerState >>= (.blockedReason) of
    Just reason -> ["Ignoring stale reviewer blocked reason for merged PR snapshot: " <> reason]
    Nothing -> []

bootstrapTriageTurn :: TurnId
bootstrapTriageTurn = TurnId "bootstrap-triage-turn"

bootstrapPlanTurn :: TurnId
bootstrapPlanTurn = TurnId "bootstrap-plan-turn"

bootstrapReviewerTurn :: TurnId
bootstrapReviewerTurn = TurnId "bootstrap-reviewer-turn"
