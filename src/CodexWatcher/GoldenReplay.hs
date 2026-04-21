{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE OverloadedRecordDot #-}

module CodexWatcher.GoldenReplay
  ( ReplayResult (..)
  , replayNodePrReviewSnapshot
  ) where

import CodexWatcher.Snapshot
import CodexWatcher.Types
import Data.Text (Text)

data ReplayResult = ReplayResult
  { replayState :: SomeWatcherState
  , replayWarnings :: [Text]
  }
  deriving stock (Show)

replayNodePrReviewSnapshot :: NodePrReviewSnapshot -> Either Text ReplayResult
replayNodePrReviewSnapshot snapshot =
  case blockedState snapshot of
    Just blocked | blocked.blocked ->
      pure $ ReplayResult
        { replayState = SomeWatcherState (BlockedState (BlockedReason (maybe "Node watcher blocked without reason" id blocked.reason)) :: WatcherState 'PrReview 'Blocked)
        , replayWarnings = []
        }
    _ ->
      replayUnblockedPrReviewSnapshot snapshot

replayUnblockedPrReviewSnapshot :: NodePrReviewSnapshot -> Either Text ReplayResult
replayUnblockedPrReviewSnapshot snapshot
  | snapshot.watcherState.lastTurnStatus == Just "merged" =
      pure $ ReplayResult
        { replayState = SomeWatcherState (CompleteState (PrMerged (MergeCommit (CommitSha (bestKnownCommit snapshot)))) :: WatcherState 'PrReview 'Complete)
        , replayWarnings = staleReviewerBlockedWarning snapshot
        }
  | maybe False (.hasUnresolved) (checkerState snapshot) =
      pure $ ReplayResult
        { replayState =
            SomeWatcherState
              ( PrCheckingReviews
                  (toPrConfig snapshot.config)
                  (WorkerIdle (ThreadId snapshot.config.threadId))
                  (ReviewerIdle (ThreadId (maybe snapshot.config.threadId id snapshot.config.reviewerThreadId)))
                  :: WatcherState 'PrReview 'CheckingReviews
              )
        , replayWarnings = ["Snapshot has unresolved review threads; replayed to CheckingReviews because no active turn is represented in persisted state."]
        }
  | otherwise =
      pure $ ReplayResult
        { replayState =
            SomeWatcherState
              ( PrCheckingReviews
                  (toPrConfig snapshot.config)
                  (WorkerIdle (ThreadId snapshot.config.threadId))
                  (ReviewerIdle (ThreadId (maybe snapshot.config.threadId id snapshot.config.reviewerThreadId)))
                  :: WatcherState 'PrReview 'CheckingReviews
              )
        , replayWarnings = []
        }

toPrConfig :: NodePrReviewConfig -> PrConfig
toPrConfig config =
  PrConfig (RepoName config.repoFullName) (PrNumber config.prNumber) (BranchName config.branch)

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
