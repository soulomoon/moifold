{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.CompatibilityState
  ( CompatibilityWrite (..)
  , compatibilityStateWrites
  ) where

import CodexWatcher.Types
import Data.Aeson (Value (..), object, (.=))
import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)
import System.FilePath ((</>))

data CompatibilityWrite = CompatibilityWrite
  { compatibilityWritePath :: FilePath
  , compatibilityWriteValue :: Value
  }
  deriving stock (Eq, Show)

compatibilityStateWrites :: FilePath -> SomeWatcherState -> [CompatibilityWrite]
compatibilityStateWrites stateDir state =
  case state of
    SomeWatcherState (PlanningReady config) ->
      [ write "planner-state.json" (plannerStateJson config "ready")
      , write "daemon-state.json" idleDaemonJson
      ]
    SomeWatcherState (PlanningTurnActive config activeTurn) ->
      [ write "planner-state.json" (plannerStateJson config "active")
      , write "daemon-state.json" (activeDaemonJson "plan" activeTurn)
      ]
    SomeWatcherState (IssueNeedsTriage config (WorkerIdle _threadId)) ->
      [ write "issue-state.json" (issueStateJson config "triage" Nothing Nothing)
      , write "daemon-state.json" idleDaemonJson
      ]
    SomeWatcherState (IssueTriageActive config (WorkerActive activeTurn)) ->
      [ write "issue-state.json" (issueStateJson config "triage" Nothing Nothing)
      , write "daemon-state.json" (activeDaemonJson "triage" activeTurn)
      ]
    SomeWatcherState (IssuePlanReady config (WorkerIdle _threadId)) ->
      [ write "issue-state.json" (issueStateJson config "plan_ready" Nothing Nothing)
      , write "daemon-state.json" idleDaemonJson
      ]
    SomeWatcherState (IssueInPlanMode config (WorkerActive activeTurn)) ->
      [ write "issue-state.json" (issueStateJson config "needs_implementation" Nothing Nothing)
      , write "daemon-state.json" (activeDaemonJson "plan" activeTurn)
      ]
    SomeWatcherState (IssueImplementationReady config maybePr (WorkerIdle _threadId)) ->
      [ write "issue-state.json" (issueStateJson config "in_progress" maybePr Nothing)
      , write "daemon-state.json" idleDaemonJson
      ]
    SomeWatcherState (IssueImplementing config maybePr (WorkerActive activeTurn)) ->
      [ write "issue-state.json" (issueStateJson config "in_progress" maybePr Nothing)
      , write "daemon-state.json" (activeDaemonJson "implement" activeTurn)
      ]
    SomeWatcherState (PrCheckingReviews config (WorkerIdle workerThread) (ReviewerIdle reviewerThread)) ->
      [ write "watcher-state.json" (prWatcherStateJson config workerThread reviewerThread "checking" Nothing Nothing)
      ]
    SomeWatcherState (PrFixingReviews config evidence (WorkerActive activeTurn) (ReviewerIdle reviewerThread)) ->
      [ write "watcher-state.json" (prWatcherStateJson config (activeThreadId activeTurn) reviewerThread "worker_active" (Just (reviewedCommit evidence)) Nothing)
      , write "checker-state.json" (checkerStateJson config (unresolvedThreads evidence))
      ]
    SomeWatcherState (PrReviewingClean config commit (WorkerIdle workerThread) (ReviewerActive activeTurn)) ->
      [ write "watcher-state.json" (prWatcherStateJson config workerThread (activeThreadId activeTurn) "reviewer_active" (Just commit) (Just commit))
      ]
    SomeWatcherState (PrMerging config evidence) ->
      [ write "watcher-state.json" (prWatcherStateJson config (ThreadId "") (ThreadId "") "clean" (Just (cleanReviewCommit evidence)) (Just (cleanReviewCommit evidence)))
      , write "reviewer-state.json" (reviewerStateJson evidence)
      ]
    SomeWatcherState (BlockedState reason) ->
      [write "block-state.json" (blockedStateJson reason)]
    SomeWatcherState (StoppedState reason) ->
      [write "daemon-state.json" (stoppedDaemonJson reason)]
    SomeWatcherState (CompleteState PlanningComplete) ->
      [write "planner-state.json" (object ["status" .= ("complete" :: Text)])]
    SomeWatcherState (CompleteState (IssueAlreadyResolved issueNumber)) ->
      [write "issue-state.json" (object ["issue_status" .= ("already_resolved" :: Text), "issueNumber" .= unIssueNumber issueNumber])]
    SomeWatcherState (CompleteState (IssueComplete prNumber)) ->
      [write "issue-state.json" (object ["issue_status" .= ("complete" :: Text), "pr_number" .= unPrNumber prNumber])]
    SomeWatcherState (CompleteState (PrMerged mergeCommit)) ->
      [write "watcher-state.json" (object ["lastTurnStatus" .= ("merged" :: Text), "mergeCommitSha" .= unCommitSha (unMergeCommit mergeCommit)])]
 where
  write fileName value =
    CompatibilityWrite
      { compatibilityWritePath = stateDir </> fileName
      , compatibilityWriteValue = value
      }

plannerStateJson :: PlannerConfig -> Text -> Value
plannerStateJson config statusValue =
  object
    [ "repoFullName" .= unRepoName (plannerRepo config)
    , "maxParallel" .= plannerMaxParallel config
    , "status" .= statusValue
    ]

issueStateJson :: IssueConfig -> Text -> Maybe PrNumber -> Maybe BlockedReason -> Value
issueStateJson config statusValue maybePr maybeBlockedReason =
  object
    [ "repoFullName" .= unRepoName (issueRepo config)
    , "issueNumber" .= unIssueNumber (issueNumber config)
    , "branch" .= unBranchName (issueBranch config)
    , "issue_status" .= statusValue
    , "pr_number" .= fmap unPrNumber maybePr
    , "blocked_reason" .= fmap unBlockedReason maybeBlockedReason
    ]

prWatcherStateJson :: PrConfig -> ThreadId -> ThreadId -> Text -> Maybe CommitSha -> Maybe CommitSha -> Value
prWatcherStateJson config workerThread reviewerThread turnStatus maybeReviewTarget maybeReviewerTarget =
  object
    [ "repoFullName" .= unRepoName (prRepo config)
    , "prNumber" .= unPrNumber (prNumber config)
    , "branch" .= unBranchName (prBranch config)
    , "threadId" .= unThreadId workerThread
    , "reviewerThreadId" .= unThreadId reviewerThread
    , "lastTurnStatus" .= turnStatus
    , "lastReviewTargetSha" .= fmap unCommitSha maybeReviewTarget
    , "lastReviewerTargetSha" .= fmap unCommitSha maybeReviewerTarget
    ]

checkerStateJson :: PrConfig -> NonEmpty ReviewThreadId -> Value
checkerStateJson config threads =
  object
    [ "repo" .= unRepoName (prRepo config)
    , "pr_number" .= unPrNumber (prNumber config)
    , "has_unresolved" .= True
    , "unresolved_count" .= length (nonEmptyToList threads)
    , "unresolved_thread_ids" .= fmap unReviewThreadId (nonEmptyToList threads)
    ]

reviewerStateJson :: CleanReviewEvidence -> Value
reviewerStateJson evidence =
  object
    [ "review_status" .= ("clean" :: Value)
    , "reviewed_commit_sha" .= unCommitSha (cleanReviewCommit evidence)
    , "approval_comment" .= cleanReviewComment evidence
    ]

blockedStateJson :: BlockedReason -> Value
blockedStateJson reason =
  object
    [ "blocked" .= True
    , "reason" .= unBlockedReason reason
    ]

idleDaemonJson :: Value
idleDaemonJson =
  object
    [ "activeTurnId" .= Null
    , "activeTurnPurpose" .= Null
    , "activeTurnCollaborationMode" .= Null
    ]

activeDaemonJson :: Text -> ActiveTurn -> Value
activeDaemonJson purpose activeTurn =
  object
    [ "activeTurnId" .= unTurnId (activeTurnId activeTurn)
    , "activeTurnPurpose" .= purpose
    , "activeThreadId" .= unThreadId (activeThreadId activeTurn)
    ]

stoppedDaemonJson :: StopReason -> Value
stoppedDaemonJson reason =
  object
    [ "activeTurnId" .= Null
    , "activeTurnPurpose" .= Null
    , "stopReason" .= unStopReason reason
    ]

nonEmptyToList :: NonEmpty a -> [a]
nonEmptyToList (first :| rest) = first : rest
