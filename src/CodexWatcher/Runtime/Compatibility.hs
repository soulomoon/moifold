{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Runtime.Compatibility
  ( CompatibilityWrite (..)
  , compatibilityStateWrites
  , writeCompatibility
  ) where

import CodexWatcher.Core.Ids
  ( BranchName (..)
  , CommitSha (..)
  , IssueNumber (..)
  , PrNumber (..)
  , RepoName (..)
  , ReviewThreadId (..)
  , ThreadId (..)
  , TurnId (..)
  )
import CodexWatcher.Core.Limits (MaxParallel (..))
import CodexWatcher.Core.Reason (BlockedReason (..), StopReason (..))
import CodexWatcher.Core.State (CompletionEvidence (..), SomeWatcherState (..), WatcherState (..))
import CodexWatcher.Core.Thread (ActiveTurn (..), ReviewerThread (..), WorkerThread (..))
import CodexWatcher.Domain.IssueImplement.Types (IssueConfig (..))
import CodexWatcher.Domain.IssuePlanning.Types (PlannerConfig (..))
import CodexWatcher.Domain.PrReview.Types
  ( CleanReviewEvidence (..)
  , MergeCommit (..)
  , PrConfig (..)
  , ReviewEvidence (..)
  , reviewEvidenceSummaries
  , reviewEvidenceThreadIds
  )
import CodexWatcher.Runtime.BlockedState (blockedStateJson)
import CodexWatcher.Runtime.Interpreter (RuntimeInterpreter (..))
import CodexWatcher.TurnOutput (reviewerPromptVersion)
import Data.Aeson (Value (..), object, toJSON, (.=))
import Data.Text (Text)
import Data.Text qualified as Text
import System.FilePath ((</>))

data CompatibilityWrite = CompatibilityWrite
  { compatibilityWritePath :: FilePath
  , compatibilityWriteValue :: Value
  }
  deriving stock (Eq, Show)

writeCompatibility :: RuntimeInterpreter m -> CompatibilityWrite -> m ()
writeCompatibility interpreter write =
  interpreter.runtimeWriteJsonValue write.compatibilityWritePath write.compatibilityWriteValue

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
    SomeWatcherState (PlanningWaitingForReadyIssues config graph) ->
      [ write "planner-state.json" (plannerStateJson config "waiting_ready_issues")
      , write "planning-state.json" (toJSON graph)
      , write "daemon-state.json" idleDaemonJson
      ]
    SomeWatcherState (IssueReadyToPlan config prNumber (WorkerIdle _threadId)) ->
      [ write "issue-state.json" (issueStateJson config "ready_to_plan" (Just prNumber) Nothing)
      , write "daemon-state.json" idleDaemonJson
      ]
    SomeWatcherState (IssueInPlanMode config prNumber (WorkerActive activeTurn)) ->
      [ write "issue-state.json" (issueStateJson config "planning" (Just prNumber) Nothing)
      , write "daemon-state.json" (activeDaemonJson "plan" activeTurn)
      ]
    SomeWatcherState (IssuePlanReady config prNumber (WorkerIdle _threadId)) ->
      [ write "issue-state.json" (issueStateJson config "plan_ready" (Just prNumber) Nothing)
      , write "daemon-state.json" idleDaemonJson
      ]
    SomeWatcherState (IssueImplementationReady config maybePr (WorkerIdle _threadId)) ->
      [ write "issue-state.json" (issueStateJson config (maybe "preparing_pr" (const "in_progress") maybePr) maybePr Nothing)
      , write "daemon-state.json" idleDaemonJson
      ]
    SomeWatcherState (IssueImplementing config maybePr (WorkerActive activeTurn)) ->
      [ write "issue-state.json" (issueStateJson config "in_progress" maybePr Nothing)
      , write "daemon-state.json" (activeDaemonJson "implement" activeTurn)
      ]
    SomeWatcherState (IssueHandoffReady config prNumber _worker _reviewer) ->
      [ write "issue-state.json" (issueStateJson config "in_progress" (Just prNumber) Nothing)
      , write "daemon-state.json" idleDaemonJson
      ]
    SomeWatcherState (IssueHandoffInitialized config prNumber _worker _reviewer) ->
      [ write "issue-state.json" (issueStateJson config "in_progress" (Just prNumber) Nothing)
      , write "daemon-state.json" idleDaemonJson
      ]
    SomeWatcherState (IssueWaitingForPrMerge config prNumber _worker _reviewer) ->
      [ write "issue-state.json" (issueStateJson config "waiting_pr_merge" (Just prNumber) Nothing)
      , write "daemon-state.json" idleDaemonJson
      ]
    SomeWatcherState (IssuePostMergeReviewReady config prNumber _worker _reviewer) ->
      [ write "issue-state.json" (issueStateJson config "post_merge_review" (Just prNumber) Nothing)
      , write "daemon-state.json" idleDaemonJson
      ]
    SomeWatcherState (IssuePostMergeReviewing config prNumber _worker _commit (ReviewerActive activeTurn)) ->
      [ write "issue-state.json" (issueStateJson config "post_merge_review" (Just prNumber) Nothing)
      , write "daemon-state.json" (activeDaemonJson "post-merge-review" activeTurn)
      ]
    SomeWatcherState (IssueWaitingForIssueClose config prNumber) ->
      [ write "issue-state.json" (issueStateJson config "waiting_issue_close" (Just prNumber) Nothing)
      , write "daemon-state.json" idleDaemonJson
      ]
    SomeWatcherState (PrCheckingReviews config (WorkerIdle workerThread) (ReviewerIdle reviewerThread)) ->
      [ write "watcher-state.json" (prWatcherStateJson config workerThread reviewerThread "checking" Nothing Nothing)
      , write "checker-state.json" (checkerStateClearJson config)
      ]
    SomeWatcherState (PrFixingReviews config evidence (WorkerActive activeTurn) (ReviewerIdle reviewerThread)) ->
      [ write "watcher-state.json" (prWatcherStateJson config (activeThreadId activeTurn) reviewerThread "worker_active" (Just (reviewedCommit evidence)) Nothing)
      , write "checker-state.json" (checkerStateJson config evidence)
      ]
    SomeWatcherState (PrReviewFixQueued config evidence (WorkerIdle workerThread) (ReviewerIdle reviewerThread)) ->
      [ write "watcher-state.json" (prWatcherStateJson config workerThread reviewerThread "worker_queued" (Just (reviewedCommit evidence)) Nothing)
      , write "checker-state.json" (checkerStateJson config evidence)
      ]
    SomeWatcherState (PrVerifyingReviewFix config evidence (WorkerIdle workerThread) (ReviewerIdle reviewerThread)) ->
      [ write "watcher-state.json" (prWatcherStateJson config workerThread reviewerThread "verifying_fix" (Just (reviewedCommit evidence)) Nothing)
      , write "checker-state.json" (checkerStateJson config evidence)
      ]
    SomeWatcherState (PrReviewingClean config commit _verification (WorkerIdle workerThread) (ReviewerActive activeTurn)) ->
      [ write "watcher-state.json" (prWatcherStateJson config workerThread (activeThreadId activeTurn) "reviewer_active" (Just commit) (Just commit))
      , write "checker-state.json" (checkerStateClearJson config)
      ]
    SomeWatcherState (PrWaitingForMergeability config evidence (WorkerIdle workerThread) (ReviewerIdle reviewerThread)) ->
      [ write "watcher-state.json" (prWatcherStateJson config workerThread reviewerThread "waiting_mergeability" (Just (cleanReviewCommit evidence)) (Just (cleanReviewCommit evidence)))
      , write "checker-state.json" (checkerStateClearJson config)
      , write "reviewer-state.json" (reviewerStateJson evidence)
      ]
    SomeWatcherState (PrMerging config evidence) ->
      [ write "watcher-state.json" (prWatcherStateJson config (ThreadId "") (ThreadId "") "clean" (Just (cleanReviewCommit evidence)) (Just (cleanReviewCommit evidence)))
      , write "checker-state.json" (checkerStateClearJson config)
      , write "reviewer-state.json" (reviewerStateJson evidence)
      ]
    SomeWatcherState (BlockedState reason) ->
      [write "block-state.json" (blockedStateJson reason)]
    SomeWatcherState (StoppedState reason) ->
      [write "daemon-state.json" (stoppedDaemonJson reason)]
    SomeWatcherState (CompleteState PlanningComplete) ->
      [write "planner-state.json" (object ["status" .= ("complete" :: Text)])]
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
    , "maxParallel" .= unMaxParallel (plannerMaxParallel config)
    , "scopeIssueNumbers" .= fmap unIssueNumber (plannerScopeIssues config)
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
    , "pr_url" .= fmap (issuePrUrl config) maybePr
    , "blocked_reason" .= fmap unBlockedReason maybeBlockedReason
    ]

issuePrUrl :: IssueConfig -> PrNumber -> Text
issuePrUrl config prNumber =
  "https://github.com/" <> unRepoName (issueRepo config) <> "/pull/" <> Text.pack (show (unPrNumber prNumber))

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

checkerStateJson :: PrConfig -> ReviewEvidence -> Value
checkerStateJson config evidence =
  object
    [ "repo" .= unRepoName (prRepo config)
    , "pr_number" .= unPrNumber (prNumber config)
    , "has_unresolved" .= not (null threadIds)
    , "unresolved_count" .= length threadIds
    , "unresolved_thread_ids" .= fmap unReviewThreadId threadIds
    , "has_feedback" .= True
    , "review_findings" .= reviewEvidenceSummaries evidence
    ]
 where
  threadIds = reviewEvidenceThreadIds evidence

checkerStateClearJson :: PrConfig -> Value
checkerStateClearJson config =
  object
    [ "repo" .= unRepoName (prRepo config)
    , "pr_number" .= unPrNumber (prNumber config)
    , "has_unresolved" .= False
    , "unresolved_count" .= (0 :: Int)
    , "unresolved_thread_ids" .= ([] :: [Text])
    , "has_feedback" .= False
    , "review_findings" .= ([] :: [Text])
    ]

reviewerStateJson :: CleanReviewEvidence -> Value
reviewerStateJson evidence =
  object
    [ "review_status" .= ("clean" :: Text)
    , "reviewed_commit_sha" .= unCommitSha (cleanReviewCommit evidence)
    , "reviewer_prompt_version" .= reviewerPromptVersion
    , "added_review_comment_count" .= (0 :: Int)
    , "lgtm_comment" .= cleanReviewComment evidence
    , "findings_summary" .= ([] :: [Text])
    , "blocked_reason" .= Null
    , "solved_threads" .= ([] :: [Value])
    , "remaining_review_threads" .= ([] :: [Value])
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
