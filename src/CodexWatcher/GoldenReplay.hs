{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE OverloadedRecordDot #-}

module CodexWatcher.GoldenReplay
  ( TypedSnapshot (..)
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

import CodexWatcher.EventLog.Types (WatcherEvent (..))
import CodexWatcher.Snapshot
import CodexWatcher.Core.Types
import Control.Applicative (asum)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Data.Text qualified as Text

data TypedSnapshot = TypedSnapshot
  { typedKind :: Domain
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
      reviewerCleanEvents <> [PrReviewMergeabilityClean commit, PrReviewMergeCompleted (MergeCommit commit)]
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
  | purpose == "plan" =
      initialEvents <> bootstrapPrReadyEvents snapshot <> [IssuePlanTurnStartedEvent activeTurn.activeTurnId]
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
  Just "ready_to_plan" ->
    initialEvents <> bootstrapPrReadyEvents snapshot
  Just "planning" ->
    initialEvents <> bootstrapPrReadyEvents snapshot
  Just "plan_ready" ->
    bootstrapPlanReadyEvents snapshot initialEvents
  Just "in_progress" ->
    bootstrapImplementationReadyEvents snapshot initialEvents
  Just "incomplete" ->
    bootstrapImplementationReadyEvents snapshot initialEvents
  Just "complete" ->
    case snapshotPrNumber snapshot of
      Just prNumber ->
        bootstrapImplementationReadyEvents snapshot initialEvents
          <> [ IssueImplementationTurnStartedEvent bootstrapImplementationTurn
             , IssueImplementationCompletedEvent prNumber
             , IssueReviewHandoffInitializedEvent prNumber
             , IssueReviewHandoffStartedEvent prNumber
             , IssuePullRequestMergedEvent prNumber
             , IssueClosedEvent prNumber
             ]
      Nothing ->
        initialEvents <> [WatcherBlocked (BlockedReason "Issue state is complete but pr_number is missing")]
  Just _unknown ->
    initialEvents

bootstrapImplementationReadyEvents :: NodeIssueImplementSnapshot -> [WatcherEvent] -> [WatcherEvent]
bootstrapImplementationReadyEvents snapshot initialEvents =
  bootstrapPlanReadyEvents snapshot initialEvents
    <> maybe [] (\prNumber -> [IssuePullRequestBodyUpdatedEvent prNumber]) (snapshotPrNumber snapshot)

bootstrapPlanReadyEvents :: NodeIssueImplementSnapshot -> [WatcherEvent] -> [WatcherEvent]
bootstrapPlanReadyEvents snapshot initialEvents =
  initialEvents
    <> bootstrapPrReadyEvents snapshot
    <> [ IssuePlanTurnStartedEvent bootstrapPlanTurn
       , IssuePlanCompletedEvent bootstrapPlanMarkdown Nothing
       ]

bootstrapPrReadyEvents :: NodeIssueImplementSnapshot -> [WatcherEvent]
bootstrapPrReadyEvents snapshot =
  maybe [] (\prNumber -> [IssuePullRequestReusedEvent prNumber]) (snapshotPrNumber snapshot)

bootstrapPlanMarkdown :: Text
bootstrapPlanMarkdown =
  "Bootstrapped from existing watcher state. Continue from the current issue and PR context."

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
            ( PrWaitingForMergeability
                (toPrConfig snapshot.config)
                (CleanReviewEvidence (CommitSha (bestKnownCommit snapshot)) "LGTM")
                (WorkerIdle (ThreadId snapshot.config.threadId))
                (ReviewerIdle (ThreadId (fromMaybe snapshot.config.threadId snapshot.config.reviewerThreadId)))
                :: WatcherState 'PrReview 'WaitingMergeability
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
  | purpose == "plan" =
      case PrNumber <$> (snapshot.issueState >>= (.issuePrNumber)) of
        Just pr ->
          pure (typedIssueImplement (IssueInPlanMode (toIssueConfig snapshot.config) pr (WorkerActive activeTurn) :: WatcherState 'IssueImplement 'PlanMode) [])
        Nothing ->
          pure (typedIssueImplement (BlockedState (BlockedReason "Active issue plan turn is missing pr_number") :: WatcherState 'IssueImplement 'Blocked) [])
  | purpose == "implement" =
      pure (typedIssueImplement (IssueImplementing (toIssueConfig snapshot.config) (PrNumber <$> (snapshot.issueState >>= (.issuePrNumber))) (WorkerActive activeTurn) :: WatcherState 'IssueImplement 'Implementing) [])
  | otherwise =
      pure
        ( typedIssueImplement
            (IssueImplementationReady (toIssueConfig snapshot.config) (PrNumber <$> (snapshot.issueState >>= (.issuePrNumber))) (WorkerIdle (ThreadId snapshot.config.threadId)) :: WatcherState 'IssueImplement 'Implementing)
            ["Unknown active issue turn purpose: " <> purpose]
        )

replayIdleIssueStatus :: NodeIssueImplementSnapshot -> Maybe Text -> Either Text TypedSnapshot
replayIdleIssueStatus snapshot status =
  case status of
    Nothing ->
      pure (typedIssueImplement (IssueImplementationReady config Nothing worker :: WatcherState 'IssueImplement 'Implementing) [])
    Just "blocked" ->
      pure (typedIssueImplement (BlockedState (BlockedReason (fromMaybe "Issue worker reported blocked without reason" (snapshot.issueState >>= (.issueBlockedReason)))) :: WatcherState 'IssueImplement 'Blocked) [])
    Just "ready_to_plan" ->
      case maybePr of
        Just pr -> pure (typedIssueImplement (IssueReadyToPlan config pr worker :: WatcherState 'IssueImplement 'PlanMode) [])
        Nothing -> pure (typedIssueImplement (BlockedState (BlockedReason "Issue state is ready_to_plan but pr_number is missing") :: WatcherState 'IssueImplement 'Blocked) [])
    Just "planning" ->
      case maybePr of
        Just pr -> pure (typedIssueImplement (IssueReadyToPlan config pr worker :: WatcherState 'IssueImplement 'PlanMode) ["Issue state says planning but no active plan turn is represented."])
        Nothing -> pure (typedIssueImplement (BlockedState (BlockedReason "Issue state is planning but pr_number is missing") :: WatcherState 'IssueImplement 'Blocked) [])
    Just "plan_ready" ->
      case maybePr of
        Just pr -> pure (typedIssueImplement (IssuePlanReady config pr worker :: WatcherState 'IssueImplement 'Implementing) [])
        Nothing -> pure (typedIssueImplement (BlockedState (BlockedReason "Issue state is plan_ready but pr_number is missing") :: WatcherState 'IssueImplement 'Blocked) [])
    Just "in_progress" ->
      pure (typedIssueImplement (IssueImplementationReady config maybePr worker :: WatcherState 'IssueImplement 'Implementing) [])
    Just "waiting_pr_merge" ->
      case maybePr of
        Just pr -> pure (typedIssueImplement (IssueWaitingForPrMerge config pr :: WatcherState 'IssueImplement 'Implementing) [])
        Nothing -> pure (typedIssueImplement (BlockedState (BlockedReason "Issue state is waiting_pr_merge but pr_number is missing") :: WatcherState 'IssueImplement 'Blocked) [])
    Just "waiting_issue_close" ->
      case maybePr of
        Just pr -> pure (typedIssueImplement (IssueWaitingForIssueClose config pr :: WatcherState 'IssueImplement 'Implementing) [])
        Nothing -> pure (typedIssueImplement (BlockedState (BlockedReason "Issue state is waiting_issue_close but pr_number is missing") :: WatcherState 'IssueImplement 'Blocked) [])
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
            (IssueImplementationReady config maybePr worker :: WatcherState 'IssueImplement 'Implementing)
            ["Unknown issue_status: " <> unknown]
        )
 where
  config = toIssueConfig snapshot.config
  worker = WorkerIdle (ThreadId snapshot.config.threadId)
  maybePr = PrNumber <$> (snapshot.issueState >>= (.issuePrNumber))

typedPrReview :: KnownPhase phase => WatcherState 'PrReview phase -> [Text] -> TypedSnapshot
typedPrReview state warnings =
  TypedSnapshot
    { typedKind = PrReview
    , typedState = SomeWatcherState state
    , typedWarnings = warnings
    }

typedIssueImplement :: KnownPhase phase => WatcherState 'IssueImplement phase -> [Text] -> TypedSnapshot
typedIssueImplement state warnings =
  TypedSnapshot
    { typedKind = IssueImplement
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

bootstrapPlanTurn :: TurnId
bootstrapPlanTurn = TurnId "bootstrap-plan-turn"

bootstrapImplementationTurn :: TurnId
bootstrapImplementationTurn = TurnId "bootstrap-implementation-turn"

bootstrapReviewerTurn :: TurnId
bootstrapReviewerTurn = TurnId "bootstrap-reviewer-turn"
