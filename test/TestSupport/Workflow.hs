{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}
{-# OPTIONS_GHC -Wno-unused-imports #-}
{-# OPTIONS_GHC -Wno-unused-top-binds #-}

module TestSupport.Workflow
  ( maxParallelForTest
  , staleSecondsForTest
  , pollSecondsForTest
  , sequenceAnd
  , sampleIssuePlanMarkdown
  , sampleIssuePlanFile
  , reviewThreadsReport
  , reviewerStateOutput
  , reviewerStateOutputWithRemaining
  , reviewerStateOutputWithSolvedAndRemaining
  , effectRuntimeConfig
  , EffectTag (..)
  , effectTag
  , hasEffect
  , lacksEffect
  , startWorkerEvidenceFromEffects
  , expectRight
  , expectLeft
  , replaySatisfies
  , appServerRequestId
  , lookupValue
  , assert
  , sameWatcherStateShape
  , lastEffectPlanIs
  , isRightUnit
  , FakeActionCall (..)
  , fakeActionExecutor
  , fakeActionExecutorWith
  , fakeActionExecutorWithLogger
  , fakeActionExecutorWithJsonStore
  , defaultFakeCommand
  , failedCommandReport
  , defaultFakeAppServer
  , callBefore
  )
where


import CodexWatcher.AppServerProtocol
import CodexWatcher.ActionExecutor
import CodexWatcher.ChildDaemon (readPidFile, restoreOwnedPidFile)
import CodexWatcher.Cli.Types
import CodexWatcher.Runtime.Compatibility
import CodexWatcher.Daemon
import CodexWatcher.DaemonLoop
import CodexWatcher.EffectInterpreter
import CodexWatcher.Cli.RuntimeConfig
import CodexWatcher.Effects
import CodexWatcher.EventLog.File (loadEventLogFile)
import CodexWatcher.EventLog.Replay (replayEventLog)
import CodexWatcher.EventLog.Types
import CodexWatcher.EventLogRepair
import CodexWatcher.Failure
import CodexWatcher.GhGit (ReviewComment (..), ReviewThread (..), ReviewThreadsReport (..))
import CodexWatcher.GoldenReplay
import CodexWatcher.Cli.Command.IssueFanout (IssueImplementerChildLaunch (..), issueImplementerChildArgs, issueImplementerChildLaunchMode, issueImplementerLaunchManifest, readyIssueStatusFromRuntime, resolveFanoutActiveIssues, retryableLaunchCommandFailure)
import CodexWatcher.AutomaticLoop.Runner (retryableAutomaticLoopFailure)
import CodexWatcher.Domain.IssueImplement.Watcher
import CodexWatcher.Domain.IssuePlanning.Fanout
import CodexWatcher.Domain.IssuePlanning.Watcher
import CodexWatcher.Logging qualified as Log
import CodexWatcher.Observation
import CodexWatcher.Cli.Command.Observe (parseDaemonObservation)
import CodexWatcher.Domain.IssuePlanning.Graph.Canonical
import CodexWatcher.Domain.PrReview.Protocol
import CodexWatcher.Domain.PrReview.Watcher
import CodexWatcher.Runtime.Command.Types (CommandReport (..), RuntimeCommand (..))
import CodexWatcher.Runtime.Command.Render (renderRuntimeCommand)
import CodexWatcher.Runtime.Defaults
import CodexWatcher.Runtime.Interpreter (RuntimeInterpreter (..))
import CodexWatcher.Runtime.Owner.Cli (clearRuntimeLease, clearRuntimeLeaseIfOwnedByCurrentProcess)
import CodexWatcher.Runtime.Owner.Store
import CodexWatcher.Runtime.Owner.Types
import CodexWatcher.RunnerGuard
import CodexWatcher.Snapshot
import CodexWatcher.StateMachine
import CodexWatcher.Supervisor
import CodexWatcher.Domain.IssueImplement.TurnClassifier
import CodexWatcher.Domain.IssuePlanning.TurnClassifier
import CodexWatcher.Domain.PrReview.TurnClassifier
import CodexWatcher.Turn.Classifier.Common
import CodexWatcher.TurnOutput
import CodexWatcher.Workflow.Agent.Ids (RequestId (..), ThreadId, TurnId (..))
import CodexWatcher.Workflow.GitHub.Ids (BranchName (..), CommitSha (..), IssueNumber (..), PrNumber (..), RepoName, ReviewThreadId (..))
import CodexWatcher.Core.Kinds
import CodexWatcher.Core.Limits
import CodexWatcher.Core.Reason
import CodexWatcher.Core.State
import CodexWatcher.Core.Thread
import CodexWatcher.Domain.IssueImplement.Types
import CodexWatcher.Domain.IssuePlanning.Types
import CodexWatcher.Domain.PrReview.Types
import CodexWatcher.Runtime.Paths
import CodexWatcher.WatcherRuntimeStatus
import CodexWatcher.Workflow.Agent qualified as WorkflowAgent
import CodexWatcher.Workflow.Agent.Codex qualified as WorkflowAgentCodex
import CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn (..))
import CodexWatcher.Workflow.Agent.Codex.Protocol qualified as WorkflowAgentCodexProtocol
import CodexWatcher.Workflow.Codec qualified as WorkflowCodec
import CodexWatcher.Workflow.Daemon.Core qualified as WorkflowDaemon
import CodexWatcher.Workflow.DSL qualified as WorkflowDSL
import CodexWatcher.Workflow.DocsMigration qualified as DocsMigration
import CodexWatcher.Workflow.EventLog.Commit.Core qualified as WorkflowEventLogCommit
import CodexWatcher.Workflow.EventLog.File.Core qualified as WorkflowEventLogFileCore
import CodexWatcher.Workflow.Execution qualified as WorkflowExecution
import CodexWatcher.Workflow.Execution.Core qualified as WorkflowExecutionCore
import CodexWatcher.Workflow.Indexed.Spec qualified as IndexedWorkflow
import CodexWatcher.Workflow.Moifold.IssueImplement.Indexed qualified as IssueImplementIndexed
import CodexWatcher.Workflow.Moifold.IssuePlanning.Indexed
  ( IssuePlanningIndexedActiveTurn
  , IssuePlanningIndexedBlocked
  , IssuePlanningIndexedComplete
  , IssuePlanningIndexedEffect (..)
  , IssuePlanningIndexedEffectPlan (..)
  , IssuePlanningIndexedEvent (..)
  , IssuePlanningIndexedInitialized
  , IssuePlanningIndexedObservation (..)
  , IssuePlanningIndexedReplayResult (..)
  , IssuePlanningIndexedProjection (..)
  , IssuePlanningIndexedSpec
  , IssuePlanningIndexedState (..)
  , IssuePlanningIndexedWaitingReadyIssues
  , issuePlanningIndexedTransitionToCompatibility
  , projectIssuePlanningBlockedActiveTurnObservation
  , projectIssuePlanningBlockedInitializedObservation
  , projectIssuePlanningBlockedWaitingReadyIssuesObservation
  , projectIssuePlanningGraphUpdatedObservation
  , projectIssuePlanningIssuesRequestedObservation
  , projectIssuePlanningReadyIssuesFixedObservation
  , projectIssuePlanningScopeCompletedObservation
  , projectIssuePlanningTurnCompletedDslTransition
  , projectIssuePlanningTurnCompletedObservation
  , projectIssuePlanningTurnRetryObservation
  , projectIssuePlanningTurnStartedObservation
  )
import CodexWatcher.Workflow.Moifold.PrReview qualified as WorkflowPrReview
import CodexWatcher.Workflow.Moifold.PrReview.Agent qualified as WorkflowPrReviewAgent
import CodexWatcher.Workflow.Moifold.PrReview.Checking.Indexed
  ( PrReviewCheckingIndexedCheckingReviews
  , PrReviewCheckingIndexedEffect (..)
  , PrReviewCheckingIndexedEffectPlan (..)
  , PrReviewCheckingIndexedEvent (..)
  , PrReviewCheckingIndexedFixingReviews
  , PrReviewCheckingIndexedObservation (..)
  , PrReviewCheckingIndexedReplayResult (..)
  , PrReviewCheckingIndexedReviewingClean
  , PrReviewCheckingIndexedSpec
  , PrReviewCheckingIndexedState (..)
  , PrReviewCheckingIndexedUninitialized
  )
import CodexWatcher.Workflow.Moifold.PrReview.Mergeability.Indexed
  ( PrReviewIndexedBlocked
  , PrReviewIndexedCheckingReviews
  , PrReviewIndexedComplete
  , PrReviewIndexedEffect (..)
  , PrReviewIndexedEffectPlan (..)
  , PrReviewIndexedEvent (..)
  , PrReviewIndexedFixingReviews
  , PrReviewIndexedMerging
  , PrReviewIndexedObservation (..)
  , PrReviewIndexedReplayResult (..)
  , PrReviewIndexedReviewingClean
  , PrReviewIndexedState (..)
  , PrReviewIndexedUninitialized
  , PrReviewIndexedWaitingForMergeability
  , PrReviewMergeabilityIndexedProjection (..)
  , PrReviewMergeabilityIndexedSpec
  , projectPrReviewMergeabilityCleanObservation
  )
import CodexWatcher.Workflow.Moifold.PrReview.Mergeability qualified as WorkflowPrReviewMergeability
import CodexWatcher.Workflow.Moifold.PrReview.Reviewer.Indexed
  ( PrReviewReviewerIndexedBlocked
  , PrReviewReviewerIndexedCheckingReviews
  , PrReviewReviewerIndexedEffect (..)
  , PrReviewReviewerIndexedEffectPlan (..)
  , PrReviewReviewerIndexedEvent (..)
  , PrReviewReviewerIndexedFixingReviews
  , PrReviewReviewerIndexedObservation (..)
  , PrReviewReviewerIndexedReplayResult (..)
  , PrReviewReviewerIndexedReviewingClean
  , PrReviewReviewerIndexedSpec
  , PrReviewReviewerIndexedState (..)
  , PrReviewReviewerIndexedUninitialized
  , PrReviewReviewerIndexedVerifyingReviewFix
  , PrReviewReviewerIndexedWaitingMergeability
  )
import CodexWatcher.Workflow.Moifold.PrReview.Worker.Indexed
  ( PrReviewWorkerIndexedBlocked
  , PrReviewWorkerIndexedCheckingReviews
  , PrReviewWorkerIndexedEffect (..)
  , PrReviewWorkerIndexedEffectPlan (..)
  , PrReviewWorkerIndexedEvent (..)
  , PrReviewWorkerIndexedFixingReviews
  , PrReviewWorkerIndexedObservation (..)
  , PrReviewWorkerIndexedReplayResult (..)
  , PrReviewWorkerIndexedSpec
  , PrReviewWorkerIndexedState (..)
  , PrReviewWorkerIndexedUninitialized
  )
import CodexWatcher.Workflow.Observation.Agent qualified as WorkflowObservationAgent
import CodexWatcher.Workflow.Transaction.Core qualified as WorkflowTransaction
import CodexWatcher.Workflow.Types (MoifoldSpec, PlannedTransition (..), WorkflowSpec (..), legacyObservedPlannedTransition, moifoldPlannedTransitionFromEffects, workflowPlanObservation)
import Control.Exception (try)
import Control.Monad (when)
import Data.Aeson
  ( Value (..)
  , eitherDecodeStrict'
  , encode
  , object
  , toJSON
  , (.=)
  )
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Foldable qualified as Foldable
import Data.IORef
import Data.Kind (Type)
import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text.Encoding
import Data.Text.IO qualified as TextIO
import Data.Time.Calendar (fromGregorian)
import Data.Time.Clock (UTCTime (..), addUTCTime, getCurrentTime, secondsToDiffTime)
import System.Directory (createDirectoryIfMissing, doesDirectoryExist, doesFileExist, removePathForcibly)
import System.FilePath ((</>))
import System.Exit (ExitCode (..), exitFailure)
import System.Posix.Process (getProcessID)
import Test.QuickCheck

maxParallelForTest :: Int -> MaxParallel
maxParallelForTest value =
  case mkMaxParallel value of
    Just parsed -> parsed
    Nothing -> error ("invalid test maxParallel: " <> show value)

staleSecondsForTest :: Int -> StaleSeconds
staleSecondsForTest value =
  case mkStaleSeconds value of
    Just parsed -> parsed
    Nothing -> error ("invalid test stale seconds: " <> show value)

pollSecondsForTest :: Int -> PollSeconds
pollSecondsForTest value =
  case mkPollSeconds value of
    Just parsed -> parsed
    Nothing -> error ("invalid test poll seconds: " <> show value)

sequenceAnd :: [IO Bool] -> IO Bool
sequenceAnd =
  fmap and . sequence

sampleIssuePlanMarkdown :: Text
sampleIssuePlanMarkdown =
  "Implement the issue in small verified steps."

sampleIssuePlanFile :: IssueConfig -> PrNumber -> Text
sampleIssuePlanFile issueConfig prNumber =
  Text.unlines
    [ "---"
    , "issue_number: " <> Text.pack (show (unIssueNumber issueConfig.issueNumber))
    , "pr_number: " <> Text.pack (show (unPrNumber prNumber))
    , "branch: " <> unBranchName issueConfig.issueBranch
    , "---"
    , ""
    , sampleIssuePlanMarkdown
    ]

data EffectTag
  = ReadOpenIssuesTag
  | ReadOpenPullRequestsTag
  | ReadReviewThreadsTag
  | StartPlannerTurnTag
  | StartWorkerTurnTag
  | StartIssuePlanWorkerTurnTag
  | StartIssueImplementationWorkerTurnTag
  | StartReviewerTurnTag
  | StartReviewerVerificationTurnTag
  | StartIssueFinalReviewTurnTag
  | PushBranchTag
  | CreateIssueTag
  | CreatePullRequestTag
  | UpdatePullRequestBodyTag
  | CloseIssueTag
  | UpdateIssueFollowUpTag
  | ResolveReviewThreadTag
  | ReplyReviewThreadTag
  | PublishReviewFindingsTag
  | RecordIssuePlanTag
  | RecordPlanningGraphTag
  | RecordBlockedTag
  | MergePullRequestTag
  | StopDaemonTag
  | SleepUntilNextPollTag
  deriving stock (Eq, Show)

effectTag :: SomeEffect -> EffectTag
effectTag = \case
  SomeEffect ReadOpenIssues {} -> ReadOpenIssuesTag
  SomeEffect ReadOpenPullRequests {} -> ReadOpenPullRequestsTag
  SomeEffect ReadReviewThreads {} -> ReadReviewThreadsTag
  SomeEffect StartPlannerTurn {} -> StartPlannerTurnTag
  SomeEffect StartWorkerTurn {} -> StartWorkerTurnTag
  SomeEffect StartIssuePlanWorkerTurn {} -> StartIssuePlanWorkerTurnTag
  SomeEffect StartIssueImplementationWorkerTurn {} -> StartIssueImplementationWorkerTurnTag
  SomeEffect StartReviewerTurn {} -> StartReviewerTurnTag
  SomeEffect StartReviewerVerificationTurn {} -> StartReviewerVerificationTurnTag
  SomeEffect StartIssueFinalReviewTurn {} -> StartIssueFinalReviewTurnTag
  SomeEffect PushBranch {} -> PushBranchTag
  SomeEffect CreateIssue {} -> CreateIssueTag
  SomeEffect CreatePullRequest {} -> CreatePullRequestTag
  SomeEffect UpdatePullRequestBody {} -> UpdatePullRequestBodyTag
  SomeEffect CloseIssue {} -> CloseIssueTag
  SomeEffect UpdateIssueFollowUp {} -> UpdateIssueFollowUpTag
  SomeEffect ResolveReviewThread {} -> ResolveReviewThreadTag
  SomeEffect ReplyReviewThread {} -> ReplyReviewThreadTag
  SomeEffect PublishReviewFindings {} -> PublishReviewFindingsTag
  SomeEffect RecordIssuePlan {} -> RecordIssuePlanTag
  SomeEffect RecordPlanningGraph {} -> RecordPlanningGraphTag
  SomeEffect RecordBlocked {} -> RecordBlockedTag
  SomeEffect MergePullRequest {} -> MergePullRequestTag
  SomeEffect StopDaemon -> StopDaemonTag
  SomeEffect SleepUntilNextPoll -> SleepUntilNextPollTag

hasEffect :: EffectTag -> [SomeEffect] -> Bool
hasEffect tag =
  any ((== tag) . effectTag)

lacksEffect :: EffectTag -> [SomeEffect] -> Bool
lacksEffect tag =
  not . hasEffect tag

startWorkerEvidenceFromEffects :: [SomeEffect] -> Maybe ReviewEvidence
startWorkerEvidenceFromEffects = \case
  SomeEffect (StartWorkerTurn evidence _) : _ -> Just evidence
  _ : rest -> startWorkerEvidenceFromEffects rest
  [] -> Nothing

expectRight :: Either e a -> (a -> Bool) -> Bool
expectRight result predicate =
  case result of
    Right value -> predicate value
    Left _ -> False

expectLeft :: Either e a -> Bool
expectLeft result =
  case result of
    Left _ -> True
    Right _ -> False

replaySatisfies :: [WatcherEvent] -> (EventReplayResult -> Bool) -> Bool
replaySatisfies events =
  expectRight (replayEventLog events)

appServerRequestId :: PlannedAction -> Maybe Int
appServerRequestId = \case
  PlannedAppServerRequest request -> Just (unRequestId request.requestId)
  _ -> Nothing

lookupValue :: Text -> Value -> Maybe Value
lookupValue key (Object object') =
  KeyMap.lookup (Key.fromText key) object'
lookupValue _ _ =
  Nothing

assert :: String -> Bool -> IO Bool
assert assertionName condition = do
  if condition
    then putStrLn ("PASS " <> assertionName)
    else putStrLn ("FAIL " <> assertionName)
  pure condition

sameWatcherStateShape :: SomeWatcherState -> SomeWatcherState -> Bool
sameWatcherStateShape left right =
  someDomain left == someDomain right
    && somePhase left == somePhase right

lastEffectPlanIs :: Eq effectPlan => effectPlan -> [effectPlan] -> Bool
lastEffectPlanIs expected plans =
  case reverse plans of
    actual : _ -> actual == expected
    [] -> False

isRightUnit :: Either error () -> Bool
isRightUnit = \case
  Right () -> True
  Left _ -> False


reviewThreadsReport :: [ReviewThreadId] -> ReviewThreadsReport
reviewThreadsReport unresolved =
  ReviewThreadsReport
    { reviewThreads = unresolvedThreads <> [resolvedThread]
    , unresolvedReviewThreads = unresolvedThreads
    }
 where
  unresolvedThreads =
    fmap
      (\threadId -> ReviewThread threadId False False (Just "src/File.hs") (Just 12) Nothing [] Nothing)
      unresolved
  resolvedThread =
    ReviewThread (ReviewThreadId "resolved-thread") True False Nothing Nothing Nothing [] Nothing

prop_prReviewWatcherUnresolvedStartsWorker :: PrConfig -> ThreadId -> ThreadId -> ReviewThreadId -> CommitSha -> TurnId -> Bool
prop_prReviewWatcherUnresolvedStartsWorker config workerThread reviewerThread reviewThreadId commit turnId =
  let state = SomeWatcherState (PrCheckingReviews config (WorkerIdle workerThread) (ReviewerIdle reviewerThread))
      observation = ObservedReviewThreads (reviewThreadsReport [reviewThreadId]) commit turnId
   in case prReviewObserve state observation of
        Right tick ->
          prReviewTickEvent tick == PrReviewUnresolvedFound (reviewThreadId :| []) commit turnId
            && somePhase tick.prReviewTickState == FixingReviews
            && hasEffect StartWorkerTurnTag tick.prReviewTickEffects
        Left _ -> False


jsonText :: Value -> Text
jsonText =
  Text.Encoding.decodeUtf8 . LazyByteString.toStrict . encode

reviewerStateOutput :: Text -> Text -> CommitSha -> Text -> Int -> Maybe Text -> [Text] -> [Text] -> Maybe Text -> Text
reviewerStateOutput priorStatus newStatus commit promptVersion commentCount lgtmComment priorFindings newFindings blockedReason =
  reviewerStateOutputWithRemaining priorStatus newStatus commit promptVersion commentCount lgtmComment priorFindings newFindings blockedReason []

reviewerStateOutputWithRemaining :: Text -> Text -> CommitSha -> Text -> Int -> Maybe Text -> [Text] -> [Text] -> Maybe Text -> [(ReviewThreadId, Text)] -> Text
reviewerStateOutputWithRemaining priorStatus newStatus commit promptVersion commentCount lgtmComment priorFindings newFindings blockedReason remainingThreads =
  reviewerStateOutputWithSolvedAndRemaining priorStatus newStatus commit promptVersion commentCount lgtmComment priorFindings newFindings blockedReason [] remainingThreads

reviewerStateOutputWithSolvedAndRemaining :: Text -> Text -> CommitSha -> Text -> Int -> Maybe Text -> [Text] -> [Text] -> Maybe Text -> [(ReviewThreadId, Text)] -> [(ReviewThreadId, Text)] -> Text
reviewerStateOutputWithSolvedAndRemaining priorStatus newStatus commit promptVersion commentCount lgtmComment priorFindings newFindings blockedReason solvedThreads remainingThreads =
  jsonText
    ( object
        [ "reviewed_commit_sha" .= unCommitSha commit
        , "reviewer_prompt_version" .= promptVersion
        , "added_review_comment_count" .= commentCount
        , "prior_findings_status" .= priorStatus
        , "new_findings_status" .= newStatus
        , "lgtm_comment" .= lgtmComment
        , "prior_findings_summary" .= priorFindings
        , "new_findings_summary" .= newFindings
        , "blocked_reason" .= blockedReason
        , "solved_threads" .= solvedReviewThreadsJson solvedThreads
        , "remaining_review_threads" .= remainingReviewThreadsJson remainingThreads
        ]
    )

solvedReviewThreadsJson :: [(ReviewThreadId, Text)] -> [Value]
solvedReviewThreadsJson =
  fmap \(threadId, summary) ->
    object
      [ "thread_id" .= unReviewThreadId threadId
      , "resolution_summary" .= summary
      ]

remainingReviewThreadsJson :: [(ReviewThreadId, Text)] -> [Value]
remainingReviewThreadsJson =
  fmap \(threadId, summary) ->
    object
      [ "thread_id" .= unReviewThreadId threadId
      , "comment" .= summary
      ]

issueFinalReviewOutput :: Text -> CommitSha -> Text -> Bool -> Bool -> Bool -> Bool -> [Text] -> [Text] -> Maybe Text -> Maybe Text -> Text
issueFinalReviewOutput status commit promptVersion issueSolved planImplemented testsSufficient reworkRequired verification findings blockedReason lgtmComment =
  jsonText
    ( object
        [ "completion_status" .= status
        , "reviewed_commit_sha" .= unCommitSha commit
        , "reviewer_prompt_version" .= promptVersion
        , "issue_solved" .= issueSolved
        , "plan_implemented" .= planImplemented
        , "tests_sufficient" .= testsSufficient
        , "rework_required" .= reworkRequired
        , "verification_summary" .= verification
        , "findings_summary" .= findings
        , "blocked_reason" .= blockedReason
        , "lgtm_comment" .= lgtmComment
        ]
    )

prop_turnClassifierCompletionStates :: Bool
prop_turnClassifierCompletionStates =
  classifyTurnCompletion (AppServerTurn (TurnId "running") "running" Nothing) == TurnStillRunning
    && classifyTurnCompletion (AppServerTurn (TurnId "done") "completed" (Just "complete")) == TurnCompleted (Just "complete")
    && classifyTurnCompletion (AppServerTurn (TurnId "failed") "failed" (Just "blocked by CI")) == TurnFailed "blocked by CI"

prop_turnClassifierMapsDomainOutputs :: Bool
prop_turnClassifierMapsDomainOutputs =
  let reviewerCommit = CommitSha "abc123"
      cleanReviewOutput = reviewerStateOutput "not_applicable" "none" reviewerCommit reviewerPromptVersion 0 (Just "LGTM") [] [] Nothing
      cleanFinalReviewOutput = issueFinalReviewOutput "clean" reviewerCommit reviewerPromptVersion True True True False ["validated issue and plan"] [] Nothing (Just "LGTM")
   in
  classifyIssuePlanningTurn (AppServerTurn (TurnId "planning") "completed" (Just "stable issue set")) == Just (ObservedPlanningBlocked (BlockedReason "planning turn completed without structured outcome"))
    && classifyIssuePlanTurn (AppServerTurn (TurnId "plan") "completed" (Just "plan written")) == Just (ObservedIssueImplementBlocked (BlockedReason "plan turn completed without structured plan output"))
    && classifyIssueImplementationTurn (Just (PrNumber 7)) Nothing (AppServerTurn (TurnId "impl") "completed" (Just "ready for review")) == Just (ObservedImplementationIncomplete "implementation turn completed without structured outcome")
    && classifyPrReviewWorkerTurn (AppServerTurn (TurnId "worker") "completed" (Just "resolved")) == Just (ObservedWorkerOutcome (WorkerIncomplete "worker turn completed without structured outcome"))
    && classifyPrReviewReviewerTurn reviewerCommit (AppServerTurn (TurnId "reviewer") "completed" (Just cleanReviewOutput)) == Just (ObservedReviewerOutcome (ReviewerClean (CleanReviewEvidence reviewerCommit "LGTM") []))
    && classifyIssueFinalReviewTurn reviewerCommit (AppServerTurn (TurnId "final-reviewer") "completed" (Just cleanFinalReviewOutput)) == Just (IssueFinalReviewClean (CleanReviewEvidence reviewerCommit "LGTM"))

prop_turnClassifierPrefersStructuredOutputs :: Bool
prop_turnClassifierPrefersStructuredOutputs =
  let issueRequest = IssueCreationRequest "Subissue A" "Split from parent" Nothing
      subissueRequest = IssueCreationRequest "Subissue B" "Split from existing parent" (Just (IssueNumber 8))
      planningGraph =
        PlanningGraph
          [IssueNumber 15]
          [BlockedPlanningIssue (IssueNumber 16) [IssueNumber 15] "wait"]
          [IssueDependency (IssueNumber 16) [IssueNumber 15]]
      remainingThreadEvidence =
        reviewEvidenceFromThreadComments ((ReviewThreadId "thread-1", "still not fixed") :| []) (CommitSha "abc123")
      combinedPriorAndNewEvidence =
        ReviewEvidence
          ( ReviewThreadCommentFinding (ReviewThreadId "thread-1") Nothing "still not fixed"
              :| [ReviewSummaryFinding "new summary finding"]
          )
          (CommitSha "abc123")
   in parseStructuredTurnOutcome "{\"outcome\":\"blocked\",\"reason\":\"schema blocker\"}" == Just (StructuredBlocked "schema blocker")
    && classifyIssuePlanningTurn (AppServerTurn (TurnId "planning") "completed" (Just "{\"outcome\":\"complete\",\"issues_to_create\":[{\"title\":\"Subissue A\",\"body\":\"Split from parent\"}]}")) == Just (ObservedPlanningIssuesRequested (issueRequest :| []))
    && classifyIssuePlanningTurn (AppServerTurn (TurnId "planning-subissue") "completed" (Just "{\"outcome\":\"complete\",\"subissues_to_create\":[{\"title\":\"Subissue B\",\"body\":\"Split from existing parent\",\"parentIssueNumber\":8}]}")) == Just (ObservedPlanningIssuesRequested (subissueRequest :| []))
    && classifyIssuePlanningTurn (AppServerTurn (TurnId "planning-invalid-subissue") "completed" (Just "{\"outcome\":\"complete\",\"subissues_to_create\":[{\"title\":\"Subissue B\",\"parentIssueNumber\":8}]}")) == Just (ObservedPlanningBlocked (BlockedReason "planning turn returned invalid issue creation payload"))
    && classifyIssuePlanningTurn (AppServerTurn (TurnId "planning-graph") "completed" (Just "{\"outcome\":\"complete\",\"ready_issues\":[15],\"blocked_issues\":[{\"issueNumber\":16,\"blockedBy\":[15],\"reason\":\"wait\"}],\"dependencies\":[{\"issueNumber\":16,\"dependsOn\":[15]}]}")) == Just (ObservedPlanningGraphUpdated planningGraph)
    && classifyIssuePlanningTurn (AppServerTurn (TurnId "planning-graph-with-empty-issue-requests") "completed" (Just "{\"outcome\":\"complete\",\"issues_to_create\":[],\"subissues_to_create\":[],\"ready_issues\":[15],\"blocked_issues\":[{\"issueNumber\":16,\"blockedBy\":[15],\"reason\":\"wait\"}],\"dependencies\":[{\"issueNumber\":16,\"dependsOn\":[15]}],\"reason\":\"\",\"summary\":\"graph ready\"}")) == Just (ObservedPlanningGraphUpdated planningGraph)
    && classifyIssuePlanningTurn (AppServerTurn (TurnId "planning-graph-rich") "completed" (Just "{\"outcome\":\"complete\",\"ready_issues\":[{\"number\":15,\"title\":\"ready\"}],\"blocked_issues\":[{\"number\":16,\"blocked_by\":[15],\"reason\":\"wait\"}],\"dependencies\":[{\"issue\":16,\"depends_on\":[15]}]}")) == Just (ObservedPlanningGraphUpdated planningGraph)
    && parseStructuredTurnOutcome "{\"outcome\":\"blocked\"}" == Nothing
    && classifyIssuePlanTurn (AppServerTurn (TurnId "plan") "completed" (Just "{\"outcome\":\"complete\",\"reason\":\"\",\"summary\":\"plan ready\",\"plan_markdown\":\"Implement the issue in small verified steps.\"}")) == Just (ObservedPlanCompleted sampleIssuePlanMarkdown Nothing)
    && classifyIssueImplementationTurn (Just (PrNumber 7)) Nothing (AppServerTurn (TurnId "impl") "completed" (Just "{\"outcome\":\"complete\",\"summary\":\"ready\"}")) == Just (ObservedImplementationCompleted (PrNumber 7) Nothing)
    && classifyIssueImplementationTurn (Just (PrNumber 7)) Nothing (AppServerTurn (TurnId "impl-clean") "completed" (Just "{\"outcome\":\"clean\",\"summary\":\"review-only\"}")) == Just (ObservedImplementationIncomplete "implementation turn completed without structured outcome")
    && classifyIssueImplementationTurn (Just (PrNumber 7)) Nothing (AppServerTurn (TurnId "impl-problems") "completed" (Just "{\"outcome\":\"problems\",\"summary\":\"review-only\"}")) == Just (ObservedImplementationIncomplete "implementation turn completed without structured outcome")
    && classifyPrReviewWorkerTurn (AppServerTurn (TurnId "worker") "completed" (Just "{\"outcome\":\"incomplete\",\"reason\":\"tests still failing\"}")) == Just (ObservedWorkerOutcome (WorkerIncomplete "tests still failing"))
    && classifyPrReviewWorkerTurn (AppServerTurn (TurnId "worker-failed-complete") "failed" (Just "{\"comment\":\"fix applied\",\"evidence\":\"\",\"outcome\":\"complete\",\"reason\":\"\",\"summary\":\"\"}")) == Just (ObservedWorkerOutcome WorkerCompleted)
    && classifyPrReviewWorkerTurn (AppServerTurn (TurnId "worker-failed-incomplete") "failed" (Just "{\"outcome\":\"incomplete\",\"reason\":\"tests still failing\"}")) == Just (ObservedWorkerOutcome (WorkerIncomplete "tests still failing"))
    && classifyPrReviewReviewerTurn (CommitSha "abc123") (AppServerTurn (TurnId "reviewer") "completed" (Just (reviewerStateOutput "not_applicable" "none" (CommitSha "abc123") reviewerPromptVersion 0 (Just "LGTM") [] [] Nothing))) == Just (ObservedReviewerOutcome (ReviewerClean (CleanReviewEvidence (CommitSha "abc123") "LGTM") []))
    && classifyPrReviewReviewerTurn (CommitSha "abc123") (AppServerTurn (TurnId "reviewer-clean-null-comment") "completed" (Just (reviewerStateOutput "not_applicable" "none" (CommitSha "abc123") reviewerPromptVersion 0 Nothing [] [] Nothing))) == Just (ObservedReviewerOutcome (ReviewerClean (CleanReviewEvidence (CommitSha "abc123") "LGTM") []))
    && classifyPrReviewReviewerTurn (CommitSha "abc123") (AppServerTurn (TurnId "reviewer-resolved-prior-summary") "completed" (Just (reviewerStateOutput "resolved" "none" (CommitSha "abc123") reviewerPromptVersion 0 (Just "LGTM") ["resolved prior summary finding"] [] Nothing))) == Just (ObservedReviewerOutcome (ReviewerClean (CleanReviewEvidence (CommitSha "abc123") "LGTM") []))
    && classifyPrReviewReviewerTurn (CommitSha "abc123") (AppServerTurn (TurnId "reviewer-missing-state") "completed" (Just "{\"result\":\"clean\",\"comment\":\"schema LGTM\"}")) == Just (ObservedReviewerOutcome (ReviewerIncomplete "reviewer state missing required fields: reviewed_commit_sha, reviewer_prompt_version, added_review_comment_count, prior_findings_status, new_findings_status, lgtm_comment, prior_findings_summary, new_findings_summary, blocked_reason, solved_threads, remaining_review_threads"))
    && classifyPrReviewReviewerTurn (CommitSha "abc123") (AppServerTurn (TurnId "reviewer-new-findings") "completed" (Just (reviewerStateOutput "not_applicable" "found" (CommitSha "abc123") reviewerPromptVersion 0 Nothing [] ["left summary finding"] Nothing))) == Just (ObservedReviewerOutcome (ReviewerProblemsAdded (reviewEvidenceFromSummaries ("left summary finding" :| []) (CommitSha "abc123")) []))
    && classifyPrReviewReviewerTurn (CommitSha "abc123") (AppServerTurn (TurnId "reviewer-remaining-thread") "completed" (Just (reviewerStateOutputWithRemaining "unresolved" "none" (CommitSha "abc123") reviewerPromptVersion 0 Nothing [] [] Nothing [(ReviewThreadId "thread-1", "still not fixed")]))) == Just (ObservedReviewerOutcome (ReviewerProblemsAdded remainingThreadEvidence []))
    && classifyPrReviewReviewerTurn (CommitSha "abc123") (AppServerTurn (TurnId "reviewer-prior-and-new-findings") "completed" (Just (reviewerStateOutputWithSolvedAndRemaining "unresolved" "found" (CommitSha "abc123") reviewerPromptVersion 0 Nothing [] ["new summary finding"] Nothing [(ReviewThreadId "thread-fixed", "fixed")] [(ReviewThreadId "thread-1", "still not fixed")]))) == Just (ObservedReviewerOutcome (ReviewerProblemsAdded combinedPriorAndNewEvidence [ReviewThreadId "thread-fixed"]))
    && classifyPrReviewReviewerTurn (CommitSha "abc123") (AppServerTurn (TurnId "reviewer-not-applicable-solved-thread") "completed" (Just (reviewerStateOutputWithSolvedAndRemaining "not_applicable" "none" (CommitSha "abc123") reviewerPromptVersion 0 Nothing [] [] Nothing [(ReviewThreadId "thread-fixed", "fixed")] []))) == Just (ObservedReviewerOutcome (ReviewerIncomplete "solved_threads require prior_findings_status=resolved or unresolved"))
    && classifyPrReviewReviewerTurn (CommitSha "abc123") (AppServerTurn (TurnId "reviewer-sha-mismatch") "completed" (Just (reviewerStateOutput "not_applicable" "none" (CommitSha "def456") reviewerPromptVersion 0 (Just "LGTM") [] [] Nothing))) == Just (ObservedReviewerOutcome (ReviewerIncomplete "reviewer inspected def456, expected abc123"))
    && classifyIssueFinalReviewTurn (CommitSha "abc123") (AppServerTurn (TurnId "final-review-clean") "completed" (Just (issueFinalReviewOutput "clean" (CommitSha "abc123") reviewerPromptVersion True True True False ["validated issue and plan"] [] Nothing Nothing))) == Just (IssueFinalReviewClean (CleanReviewEvidence (CommitSha "abc123") "LGTM"))
    && classifyIssueFinalReviewTurn (CommitSha "abc123") (AppServerTurn (TurnId "final-review-clean-with-findings") "completed" (Just (issueFinalReviewOutput "clean" (CommitSha "abc123") reviewerPromptVersion True True True False ["validated issue and plan"] ["follow-up needed"] Nothing Nothing))) == Just (IssueFinalReviewIncomplete "clean final review must leave findings_summary empty; use verification_summary for successful validation evidence")
    && classifyIssueFinalReviewTurn (CommitSha "abc123") (AppServerTurn (TurnId "final-review-rework") "completed" (Just (issueFinalReviewOutput "rework_required" (CommitSha "abc123") reviewerPromptVersion False True True True [] ["issue not solved"] Nothing Nothing))) == Just (IssueFinalReviewRework (reviewEvidenceFromSummaries ("issue not solved" :| []) (CommitSha "abc123")))
    && classifyIssueFinalReviewTurn (CommitSha "abc123") (AppServerTurn (TurnId "final-review-missing-state") "completed" (Just "{\"result\":\"clean\"}")) == Just (IssueFinalReviewIncomplete "final review state missing required fields: completion_status, reviewed_commit_sha, reviewer_prompt_version, issue_solved, plan_implemented, tests_sufficient, rework_required, verification_summary, findings_summary, blocked_reason, lgtm_comment")
    && classifyIssueFinalReviewTurn (CommitSha "abc123") (AppServerTurn (TurnId "final-review-sha-mismatch") "completed" (Just (issueFinalReviewOutput "clean" (CommitSha "def456") reviewerPromptVersion True True True False ["validated issue and plan"] [] Nothing (Just "LGTM")))) == Just (IssueFinalReviewIncomplete "final reviewer inspected def456, expected abc123")

prop_turnClassifierBlocksMissingOutputs :: Bool
prop_turnClassifierBlocksMissingOutputs =
  classifyIssuePlanningTurn (AppServerTurn (TurnId "planning") "completed" Nothing) == Just (ObservedPlanningBlocked (BlockedReason "planning turn completed without output"))
    && classifyIssuePlanTurn (AppServerTurn (TurnId "plan") "completed" Nothing) == Just (ObservedIssueImplementBlocked (BlockedReason "plan turn completed without output"))
    && classifyIssueImplementationTurn (Just (PrNumber 7)) Nothing (AppServerTurn (TurnId "impl") "completed" Nothing) == Just (ObservedImplementationBlocked (BlockedReason "implementation turn completed without output"))
    && classifyPrReviewWorkerTurn (AppServerTurn (TurnId "worker") "completed" Nothing) == Just (ObservedWorkerOutcome (WorkerBlocked (BlockedReason "worker turn completed without output")))
    && classifyPrReviewReviewerTurn (CommitSha "abc123") (AppServerTurn (TurnId "reviewer") "completed" (Just "  ")) == Just (ObservedReviewerOutcome (ReviewerBlocked (BlockedReason "reviewer turn completed without output")))
    && classifyIssueFinalReviewTurn (CommitSha "abc123") (AppServerTurn (TurnId "final-reviewer") "completed" (Just "  ")) == Just (IssueFinalReviewBlocked (BlockedReason "final reviewer turn completed without output"))

effectRuntimeConfig :: RepoName -> FilePath -> Int -> EffectRuntimeConfig
effectRuntimeConfig repo workdir requestId =
  EffectRuntimeConfig
    { effectRuntimeRepo = repo
    , effectRuntimeWorkdir = runtimeWorkdir
    , effectRuntimeStateDir = runtimeStateDir
    , effectRuntimeMergeMethod = "merge"
    , effectRuntimeNextRequestId = RequestId requestId
    , effectRuntimePlannerThreadInstructions = "planner developer instructions"
    , effectRuntimePlannerTurn = mkTurnRuntime (RuntimeStateDirCwd runtimeStateDir) "planner prompt" Nothing
    , effectRuntimeWorkerTurn = turnRuntime "worker prompt" Nothing
    , effectRuntimeIssuePlanTurn = turnRuntime "issue plan prompt" Nothing
    , effectRuntimeIssueImplementationTurn = turnRuntime "issue implementation prompt" Nothing
    , effectRuntimeReviewerTurn = turnRuntime "reviewer prompt" Nothing
    }
 where
  runtimeWorkdir = RuntimeWorkdir workdir
  runtimeStateDir = RuntimeStateDir (workdir </> ".watcher")
  mkTurnRuntime cwd input collaborationMode =
    TurnRuntimeConfig
      { turnRuntimeCwd = cwd
      , turnRuntimeModel = defaultModel
      , turnRuntimeEffort = defaultEffort
      , turnRuntimeApprovalPolicy = defaultApprovalPolicy
      , turnRuntimeSandboxPolicy = defaultSandboxPolicy
      , turnRuntimeInput = input
      , turnRuntimeOutputSchema = Nothing
      , turnRuntimeCollaborationMode = collaborationMode
      }
  turnRuntime = mkTurnRuntime (RuntimeWorkdirCwd runtimeWorkdir)

data FakeActionCall
  = FakeCommand RuntimeCommand
  | FakeReadJson FilePath
  | FakeWriteJson FilePath Value
  | FakeWriteText FilePath Text
  | FakeAppendJsonLine FilePath Value
  | FakeAppServer AppServerRequest
  | FakeSleep
  | FakeStop
  deriving stock (Eq, Show)

fakeActionExecutor :: IO (ActionExecutor IO, IO [FakeActionCall])
fakeActionExecutor =
  fakeActionExecutorWith defaultFakeCommand defaultFakeAppServer

fakeActionExecutorWith :: (RuntimeCommand -> CommandReport) -> (AppServerRequest -> Value) -> IO (ActionExecutor IO, IO [FakeActionCall])
fakeActionExecutorWith =
  fakeActionExecutorWithLogger Log.noopWatcherLogger

fakeActionExecutorWithLogger :: Log.WatcherLogger IO -> (RuntimeCommand -> CommandReport) -> (AppServerRequest -> Value) -> IO (ActionExecutor IO, IO [FakeActionCall])
fakeActionExecutorWithLogger logger commandResponse appServerResponse = do
  calls <- newIORef []
  let record call = modifyIORef' calls (<> [call])
      runtime =
        RuntimeInterpreter
          { runtimeRunCommand = \command -> do
              record (FakeCommand command)
              pure (commandResponse command)
          , runtimeReadJsonValue = \path -> do
              record (FakeReadJson path)
              pure (Left "not implemented in fake")
          , runtimeWriteJsonValue = \path value -> record (FakeWriteJson path value)
          , runtimeWriteTextFile = \path content -> record (FakeWriteText path content)
          , runtimeAppendJsonLine = \path value -> record (FakeAppendJsonLine path value)
          }
      appServer =
        AppServerInterpreter
          { appServerSendRequest = \request -> do
              record (FakeAppServer request)
              pure (appServerResponse request)
          }
      executor =
        ActionExecutor
          { actionRuntime = runtime
          , actionAppServer = appServer
          , actionSleepUntilNextPoll = record FakeSleep
          , actionStopDaemon = record FakeStop
          , actionLogger = logger
          }
  pure (executor, readIORef calls)

fakeActionExecutorWithJsonStore :: (RuntimeCommand -> CommandReport) -> (AppServerRequest -> Value) -> IO (ActionExecutor IO, IO [FakeActionCall])
fakeActionExecutorWithJsonStore commandResponse appServerResponse = do
  calls <- newIORef []
  jsonStore <- newIORef []
  let record call = modifyIORef' calls (<> [call])
      readStoredJson path = lookup path <$> readIORef jsonStore
      writeStoredJson path value =
        modifyIORef' jsonStore \entries -> (path, value) : filter ((/= path) . fst) entries
      runtime =
        RuntimeInterpreter
          { runtimeRunCommand = \command -> do
              record (FakeCommand command)
              pure (commandResponse command)
          , runtimeReadJsonValue = \path -> do
              record (FakeReadJson path)
              stored <- readStoredJson path
              pure (maybe (Left "not found") Right stored)
          , runtimeWriteJsonValue = \path value -> do
              record (FakeWriteJson path value)
              writeStoredJson path value
          , runtimeWriteTextFile = \path content -> record (FakeWriteText path content)
          , runtimeAppendJsonLine = \path value -> record (FakeAppendJsonLine path value)
          }
      appServer =
        AppServerInterpreter
          { appServerSendRequest = \request -> do
              record (FakeAppServer request)
              pure (appServerResponse request)
          }
      executor =
        ActionExecutor
          { actionRuntime = runtime
          , actionAppServer = appServer
          , actionSleepUntilNextPoll = record FakeSleep
          , actionStopDaemon = record FakeStop
          , actionLogger = Log.noopWatcherLogger
          }
  pure (executor, readIORef calls)

collectWatcherLogs :: IO (Log.WatcherLogger IO, IO [Log.WatcherLog])
collectWatcherLogs = do
  logs <- newIORef []
  let logger = Log.watcherLoggerFromFunction \entry -> modifyIORef' logs (<> [entry])
  pure (logger, readIORef logs)

defaultFakeCommand :: RuntimeCommand -> CommandReport
defaultFakeCommand _command =
  CommandReport {ok = True, status = Just 0, stdout = "ok", stderr = "", errorMessage = Nothing}

jsonCommandReport :: Value -> CommandReport
jsonCommandReport value =
  CommandReport {ok = True, status = Just 0, stdout = jsonText value, stderr = "", errorMessage = Nothing}

failedCommandReport :: Text -> CommandReport
failedCommandReport message =
  CommandReport {ok = False, status = Just 1, stdout = "", stderr = message, errorMessage = Just message}

defaultFakeAppServer :: AppServerRequest -> Value
defaultFakeAppServer request
  | request.requestMethod == "thread/start" =
      object ["threadId" .= ("thread-started" :: Text)]
  | request.requestMethod == "turn/start" =
      object ["turnId" .= ("turn-started" :: Text)]
  | otherwise =
      object ["ok" .= True]


callBefore :: FakeActionCall -> FakeActionCall -> [FakeActionCall] -> Bool
callBefore expectedFirst expectedSecond =
  go False
 where
  go _sawFirst [] = False
  go sawFirst (call : rest)
    | call == expectedFirst = go True rest
    | call == expectedSecond = sawFirst
    | otherwise = go sawFirst rest
