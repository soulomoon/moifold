{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.EventLog.Types
  ( WatcherEvent (..)
  , ReplayFailure (..)
  , EventReplayResult (..)
  , eventName
  , watcherEventCodecContract
  , watcherEventMetadataLabels
  , watcherEventSchemaVersion
  ) where

import CodexWatcher.Effects
import CodexWatcher.Core.Limits (MaxParallel, mkMaxParallel, unMaxParallel)
import CodexWatcher.Core.Reason (BlockedReason (..), StopReason (..))
import CodexWatcher.Core.State (SomeWatcherState)
import CodexWatcher.Domain.IssueImplement.Types (IssueConfig (..))
import CodexWatcher.Domain.IssuePlanning.Types (IssueCreationRequest, PlannerConfig (..), PlanningGraph)
import CodexWatcher.Domain.PrReview.Types
  ( CleanReviewEvidence (..)
  , MergeCommit (..)
  , PrConfig (..)
  , ReviewEvidence (..)
  , reviewEvidenceFromParts
  , reviewEvidenceFromSummaries
  , reviewEvidenceSummaries
  , reviewEvidenceThreadIds
  )
import CodexWatcher.Workflow.Codec
  ( WorkflowCodecContract (..)
  , WorkflowDecodeError (..)
  , WorkflowEventTypeLabel (..)
  , WorkflowMetadataLabel (..)
  , WorkflowSchemaVersion (..)
  )
import CodexWatcher.Workflow.Agent.Ids (ThreadId (..), TurnId (..))
import CodexWatcher.Workflow.GitHub.Ids
  ( BranchName (..)
  , CommitSha (..)
  , IssueNumber (..)
  , PrNumber (..)
  , RepoName (..)
  , ReviewThreadId (..)
  )
import Data.Aeson (FromJSON (..), Object, ToJSON (..), Value (..), object, withObject, (.:), (.:?), (.!=), (.=))
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Types (Pair, Parser, parseEither)
import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)
import Data.Text qualified as Text

data WatcherEvent
  = IssuePlanningInitialized PlannerConfig
  | IssuePlanningTurnStarted ThreadId TurnId
  | IssuePlanningIssuesRequested (NonEmpty IssueCreationRequest)
  | IssuePlanningGraphUpdated PlanningGraph
  | IssuePlanningReadyIssuesFixed
  | IssuePlanningScopeCompleted
  | IssuePlanningTurnRetryRequested BlockedReason
  | IssuePlanningTurnCompleted
  | PrReviewInitialized PrConfig ThreadId ThreadId
  | PrReviewThreadsRefreshed ThreadId ThreadId
  | PrReviewUnresolvedFound (NonEmpty ReviewThreadId) CommitSha TurnId
  | PrReviewFeedbackFound ReviewEvidence TurnId
  | PrReviewNoUnresolvedFound CommitSha TurnId
  | PrReviewFixVerificationStarted ReviewEvidence CommitSha TurnId
  | PrReviewFixCompleted
  | PrReviewFixIncomplete Text
  | PrReviewCleanFound CleanReviewEvidence [ReviewThreadId]
  | PrReviewProblemsAdded ReviewEvidence [ReviewThreadId]
  | PrReviewReviewIncomplete Text
  | PrReviewMergeabilityClean CommitSha
  | PrReviewMergeabilityWaiting Text
  | PrReviewMergeabilityRecheck Text
  | PrReviewMergeabilityFixRequired ReviewEvidence
  | PrReviewMergeCompleted MergeCommit
  | IssueImplementInitialized IssueConfig ThreadId
  | IssueWorkerThreadRefreshed ThreadId
  | IssueAttemptBranchAdvancedEvent BranchName
  | IssuePlanTurnStartedEvent TurnId
  | IssuePlanCompletedEvent Text (Maybe TurnId)
  | IssuePullRequestCreatedEvent PrNumber
  | IssuePullRequestReusedEvent PrNumber
  | IssuePullRequestBodyUpdatedEvent PrNumber
  | IssueImplementationTurnStartedEvent TurnId
  | IssueImplementationIncompleteEvent Text
  | IssueImplementationBlockedEvent BlockedReason
  | IssueReviewerThreadReadyEvent ThreadId
  | IssueReviewHandoffInitializedEvent PrNumber
  | IssueReviewHandoffStartedEvent PrNumber
  | IssueImplementationCompletedEvent PrNumber (Maybe ThreadId)
  | IssuePullRequestMergedEvent PrNumber
  | IssuePostMergeReviewStartedEvent CommitSha TurnId
  | IssuePostMergeReviewCleanEvent CleanReviewEvidence
  | IssuePostMergeReviewFollowUpEvent ReviewEvidence
  | IssuePostMergeReviewIncompleteEvent Text
  | IssueClosedEvent PrNumber
  | WatcherRecoveredInvalidState Text
  | WatcherBlocked BlockedReason
  | WatcherStopped StopReason
  deriving stock (Eq, Show)

data ReplayFailure = ReplayFailure
  { eventIndex :: Int
  , event :: WatcherEvent
  , reason :: Text
  }
  deriving stock (Eq, Show)

data EventReplayResult = EventReplayResult
  { replayState :: SomeWatcherState
  , replayEffects :: [EffectPlan]
  }
  deriving stock (Show)

instance ToJSON WatcherEvent where
  toJSON event =
    object case event of
      IssuePlanningInitialized config ->
        eventType event <> plannerConfigFields config
      IssuePlanningTurnStarted plannerThreadId plannerTurnId ->
        eventType event
          <> [ "plannerThreadId" .= unThreadId plannerThreadId
             , "plannerTurnId" .= unTurnId plannerTurnId
             ]
      IssuePlanningIssuesRequested requests ->
        eventType event <> ["issues" .= requests]
      IssuePlanningGraphUpdated graph ->
        eventType event <> ["planningGraph" .= graph]
      IssuePlanningReadyIssuesFixed ->
        eventType event
      IssuePlanningScopeCompleted ->
        eventType event
      IssuePlanningTurnRetryRequested reason ->
        eventType event <> ["reason" .= unBlockedReason reason]
      IssuePlanningTurnCompleted ->
        eventType event
      PrReviewInitialized config workerThreadId reviewerThreadId ->
        eventType event
          <> prConfigFields config
          <> [ "workerThreadId" .= unThreadId workerThreadId
             , "reviewerThreadId" .= unThreadId reviewerThreadId
             ]
      PrReviewThreadsRefreshed workerThreadId reviewerThreadId ->
        eventType event
          <> [ "workerThreadId" .= unThreadId workerThreadId
             , "reviewerThreadId" .= unThreadId reviewerThreadId
             ]
      PrReviewUnresolvedFound reviewThreadIds' commitSha workerTurnId ->
        eventType event
          <> [ "reviewThreadIds" .= fmap unReviewThreadId (nonEmptyToList reviewThreadIds')
             , "commitSha" .= unCommitSha commitSha
             , "workerTurnId" .= unTurnId workerTurnId
             ]
      PrReviewFeedbackFound evidence workerTurnId ->
        eventType event
          <> reviewEvidenceFields evidence
          <> [ "commitSha" .= unCommitSha (reviewedCommit evidence)
             , "workerTurnId" .= unTurnId workerTurnId
             ]
      PrReviewNoUnresolvedFound commitSha reviewerTurnId ->
        eventType event
          <> [ "commitSha" .= unCommitSha commitSha
             , "reviewerTurnId" .= unTurnId reviewerTurnId
             ]
      PrReviewFixVerificationStarted evidence reviewTargetSha reviewerTurnId ->
        eventType event
          <> reviewEvidenceFields evidence
          <> [ "reviewedCommitSha" .= unCommitSha (reviewedCommit evidence)
             , "commitSha" .= unCommitSha reviewTargetSha
             , "reviewerTurnId" .= unTurnId reviewerTurnId
             ]
      PrReviewFixCompleted ->
        eventType event
      PrReviewFixIncomplete reason ->
        eventType event <> ["reason" .= reason]
      PrReviewCleanFound evidence resolvedThreadIds ->
        eventType event
          <> [ "commitSha" .= unCommitSha (cleanReviewCommit evidence)
             , "comment" .= cleanReviewComment evidence
             , "resolvedReviewThreadIds" .= fmap unReviewThreadId resolvedThreadIds
             ]
      PrReviewProblemsAdded evidence resolvedThreadIds ->
        eventType event
          <> reviewEvidenceFields evidence
          <> [ "commitSha" .= unCommitSha (reviewedCommit evidence)
             , "resolvedReviewThreadIds" .= fmap unReviewThreadId resolvedThreadIds
             ]
      PrReviewReviewIncomplete reason ->
        eventType event <> ["reason" .= reason]
      PrReviewMergeabilityClean commitSha ->
        eventType event <> ["commitSha" .= unCommitSha commitSha]
      PrReviewMergeabilityWaiting reason ->
        eventType event <> ["reason" .= reason]
      PrReviewMergeabilityRecheck reason ->
        eventType event <> ["reason" .= reason]
      PrReviewMergeabilityFixRequired evidence ->
        eventType event
          <> reviewEvidenceFields evidence
          <> ["commitSha" .= unCommitSha (reviewedCommit evidence)]
      PrReviewMergeCompleted mergeCommit ->
        eventType event <> ["mergeCommitSha" .= unCommitSha (unMergeCommit mergeCommit)]
      IssueImplementInitialized config workerThreadId ->
        eventType event
          <> issueConfigFields config
          <> ["workerThreadId" .= unThreadId workerThreadId]
      IssueWorkerThreadRefreshed workerThreadId ->
        eventType event <> ["workerThreadId" .= unThreadId workerThreadId]
      IssueAttemptBranchAdvancedEvent branch ->
        eventType event <> ["branch" .= unBranchName branch]
      IssuePlanTurnStartedEvent planTurnId ->
        eventType event <> ["planTurnId" .= unTurnId planTurnId]
      IssuePlanCompletedEvent planMarkdown maybeImplementationTurnId ->
        eventType event
          <> ["planMarkdown" .= planMarkdown]
          <> maybe [] (\turnId -> ["implementationTurnId" .= unTurnId turnId]) maybeImplementationTurnId
      IssuePullRequestCreatedEvent prNumber' ->
        eventType event <> ["prNumber" .= unPrNumber prNumber']
      IssuePullRequestReusedEvent prNumber' ->
        eventType event <> ["prNumber" .= unPrNumber prNumber']
      IssuePullRequestBodyUpdatedEvent prNumber' ->
        eventType event <> ["prNumber" .= unPrNumber prNumber']
      IssueImplementationTurnStartedEvent implementationTurnId ->
        eventType event <> ["implementationTurnId" .= unTurnId implementationTurnId]
      IssueImplementationIncompleteEvent reason ->
        eventType event <> ["reason" .= reason]
      IssueImplementationBlockedEvent reason ->
        eventType event <> ["reason" .= unBlockedReason reason]
      IssueReviewerThreadReadyEvent reviewerThreadId ->
        eventType event <> ["reviewerThreadId" .= unThreadId reviewerThreadId]
      IssueReviewHandoffInitializedEvent prNumber' ->
        eventType event <> ["prNumber" .= unPrNumber prNumber']
      IssueReviewHandoffStartedEvent prNumber' ->
        eventType event <> ["prNumber" .= unPrNumber prNumber']
      IssueImplementationCompletedEvent prNumber' maybeReviewerThreadId ->
        eventType event
          <> ["prNumber" .= unPrNumber prNumber']
          <> maybe [] (\threadId -> ["reviewerThreadId" .= unThreadId threadId]) maybeReviewerThreadId
      IssuePullRequestMergedEvent prNumber' ->
        eventType event <> ["prNumber" .= unPrNumber prNumber']
      IssuePostMergeReviewStartedEvent commitSha reviewerTurnId ->
        eventType event
          <> [ "commitSha" .= unCommitSha commitSha
             , "reviewerTurnId" .= unTurnId reviewerTurnId
             ]
      IssuePostMergeReviewCleanEvent evidence ->
        eventType event
          <> [ "commitSha" .= unCommitSha (cleanReviewCommit evidence)
             , "comment" .= cleanReviewComment evidence
             ]
      IssuePostMergeReviewFollowUpEvent evidence ->
        eventType event
          <> reviewEvidenceFields evidence
          <> ["commitSha" .= unCommitSha (reviewedCommit evidence)]
      IssuePostMergeReviewIncompleteEvent reason ->
        eventType event <> ["reason" .= reason]
      IssueClosedEvent prNumber' ->
        eventType event <> ["prNumber" .= unPrNumber prNumber']
      WatcherRecoveredInvalidState reason ->
        eventType event
          <> [ "reason" .= reason
             , "recoveredFromInvalidState" .= True
             ]
      WatcherBlocked reason ->
        eventType event <> ["reason" .= unBlockedReason reason]
      WatcherStopped reason ->
        eventType event <> ["reason" .= unStopReason reason]

instance FromJSON WatcherEvent where
  parseJSON = withObject "WatcherEvent" \objectValue -> do
    eventTypeValue <- objectValue .: "type"
    case eventTypeValue :: Text of
      "issue_planning_initialized" ->
        IssuePlanningInitialized
          <$> parsePlannerConfig objectValue
      "issue_planning_turn_started" ->
        IssuePlanningTurnStarted
          <$> (ThreadId <$> nonEmptyTextField objectValue "plannerThreadId")
          <*> (TurnId <$> nonEmptyTextField objectValue "plannerTurnId")
      "issue_planning_issues_requested" ->
        IssuePlanningIssuesRequested
          <$> (nonEmptyIssueCreationRequests =<< objectValue .: "issues")
      "issue_planning_graph_updated" ->
        IssuePlanningGraphUpdated
          <$> objectValue .: "planningGraph"
      "issue_planning_ready_issues_fixed" ->
        pure IssuePlanningReadyIssuesFixed
      "issue_planning_scope_completed" ->
        pure IssuePlanningScopeCompleted
      "issue_planning_turn_retry_requested" ->
        IssuePlanningTurnRetryRequested
          <$> (BlockedReason <$> (objectValue .:? "reason" .!= "planner turn retry requested"))
      "issue_planning_turn_completed" ->
        pure IssuePlanningTurnCompleted
      "pr_review_initialized" ->
        PrReviewInitialized
          <$> parsePrConfig objectValue
          <*> (ThreadId <$> nonEmptyTextField objectValue "workerThreadId")
          <*> (ThreadId <$> nonEmptyTextField objectValue "reviewerThreadId")
      "pr_review_threads_refreshed" ->
        PrReviewThreadsRefreshed
          <$> (ThreadId <$> nonEmptyTextField objectValue "workerThreadId")
          <*> (ThreadId <$> nonEmptyTextField objectValue "reviewerThreadId")
      "pr_review_unresolved_found" ->
        PrReviewUnresolvedFound
          <$> (reviewThreadIds =<< objectValue .: "reviewThreadIds")
          <*> (CommitSha <$> nonEmptyTextField objectValue "commitSha")
          <*> (TurnId <$> nonEmptyTextField objectValue "workerTurnId")
      "pr_review_feedback_found" ->
        PrReviewFeedbackFound
          <$> parseReviewEvidence objectValue "commitSha" Nothing
          <*> (TurnId <$> nonEmptyTextField objectValue "workerTurnId")
      "pr_review_no_unresolved_found" ->
        PrReviewNoUnresolvedFound
          <$> (CommitSha <$> nonEmptyTextField objectValue "commitSha")
          <*> (TurnId <$> nonEmptyTextField objectValue "reviewerTurnId")
      "pr_review_fix_verification_started" ->
        parsePrReviewFixVerificationStarted objectValue
      "pr_review_fix_completed" ->
        pure PrReviewFixCompleted
      "pr_review_fix_incomplete" ->
        PrReviewFixIncomplete
          <$> (objectValue .:? "reason" .!= "incomplete")
      "pr_review_clean_found" ->
        PrReviewCleanFound
          <$> (CleanReviewEvidence <$> (CommitSha <$> nonEmptyTextField objectValue "commitSha") <*> (objectValue .:? "comment" .!= "LGTM"))
          <*> reviewThreadIdListField objectValue "resolvedReviewThreadIds"
      "pr_review_problems_added" ->
        PrReviewProblemsAdded
          <$> parseReviewEvidence objectValue "commitSha" (Just "reviewer reported problems without structured findings")
          <*> reviewThreadIdListField objectValue "resolvedReviewThreadIds"
      "pr_review_review_incomplete" ->
        PrReviewReviewIncomplete
          <$> (objectValue .:? "reason" .!= "incomplete")
      "pr_review_mergeability_clean" ->
        PrReviewMergeabilityClean
          <$> (CommitSha <$> nonEmptyTextField objectValue "commitSha")
      "pr_review_mergeability_waiting" ->
        PrReviewMergeabilityWaiting
          <$> (objectValue .:? "reason" .!= "waiting for mergeability")
      "pr_review_mergeability_recheck" ->
        PrReviewMergeabilityRecheck
          <$> (objectValue .:? "reason" .!= "rechecking reviews")
      "pr_review_mergeability_fix_required" ->
        PrReviewMergeabilityFixRequired
          <$> parseReviewEvidence objectValue "commitSha" (Just "pre-merge mergeability requires a worker fix")
      "pr_review_merge_completed" ->
        PrReviewMergeCompleted . MergeCommit . CommitSha
          <$> nonEmptyTextField objectValue "mergeCommitSha"
      "issue_implement_initialized" ->
        IssueImplementInitialized
          <$> parseIssueConfig objectValue
          <*> (ThreadId <$> nonEmptyTextField objectValue "workerThreadId")
      "issue_worker_thread_refreshed" ->
        IssueWorkerThreadRefreshed
          <$> (ThreadId <$> nonEmptyTextField objectValue "workerThreadId")
      "issue_attempt_branch_advanced" ->
        IssueAttemptBranchAdvancedEvent
          <$> (BranchName <$> nonEmptyTextField objectValue "branch")
      "issue_plan_turn_started" ->
        IssuePlanTurnStartedEvent
          <$> (TurnId <$> nonEmptyTextField objectValue "planTurnId")
      "issue_plan_completed" ->
        IssuePlanCompletedEvent
          <$> nonEmptyTextField objectValue "planMarkdown"
          <*> (traverse nonEmptyTurnId =<< objectValue .:? "implementationTurnId")
      "issue_pr_created" ->
        IssuePullRequestCreatedEvent
          <$> (PrNumber <$> positiveIntField objectValue "prNumber")
      "issue_pr_reused" ->
        IssuePullRequestReusedEvent
          <$> (PrNumber <$> positiveIntField objectValue "prNumber")
      "issue_pr_body_updated" ->
        IssuePullRequestBodyUpdatedEvent
          <$> (PrNumber <$> positiveIntField objectValue "prNumber")
      "issue_implementation_turn_started" ->
        IssueImplementationTurnStartedEvent
          <$> (TurnId <$> nonEmptyTextField objectValue "implementationTurnId")
      "issue_implementation_incomplete" ->
        IssueImplementationIncompleteEvent
          <$> (objectValue .:? "reason" .!= "incomplete")
      "issue_implementation_blocked" ->
        IssueImplementationBlockedEvent
          <$> (BlockedReason <$> nonEmptyTextField objectValue "reason")
      "issue_reviewer_thread_ready" ->
        IssueReviewerThreadReadyEvent
          <$> (ThreadId <$> nonEmptyTextField objectValue "reviewerThreadId")
      "issue_review_handoff_initialized" ->
        IssueReviewHandoffInitializedEvent
          <$> (PrNumber <$> positiveIntField objectValue "prNumber")
      "issue_review_handoff_started" ->
        IssueReviewHandoffStartedEvent
          <$> (PrNumber <$> positiveIntField objectValue "prNumber")
      "issue_implementation_completed" ->
        IssueImplementationCompletedEvent
          <$> (PrNumber <$> positiveIntField objectValue "prNumber")
          <*> (traverse (fmap ThreadId . nonEmptyText "reviewerThreadId") =<< objectValue .:? "reviewerThreadId")
      "issue_pr_merged" ->
        IssuePullRequestMergedEvent
          <$> (PrNumber <$> positiveIntField objectValue "prNumber")
      "issue_post_merge_review_started" ->
        IssuePostMergeReviewStartedEvent
          <$> (CommitSha <$> nonEmptyTextField objectValue "commitSha")
          <*> (TurnId <$> nonEmptyTextField objectValue "reviewerTurnId")
      "issue_post_merge_review_clean" ->
        IssuePostMergeReviewCleanEvent
          <$> (CleanReviewEvidence <$> (CommitSha <$> nonEmptyTextField objectValue "commitSha") <*> (objectValue .:? "comment" .!= "LGTM"))
      "issue_post_merge_review_follow_up" ->
        IssuePostMergeReviewFollowUpEvent
          <$> parseReviewEvidence objectValue "commitSha" (Just "post-merge reviewer reported follow-up without structured findings")
      "issue_post_merge_review_incomplete" ->
        IssuePostMergeReviewIncompleteEvent
          <$> (objectValue .:? "reason" .!= "incomplete")
      "issue_closed" ->
        IssueClosedEvent
          <$> (PrNumber <$> positiveIntField objectValue "prNumber")
      "watcher_recovered_invalid_state" ->
        WatcherRecoveredInvalidState
          <$> (objectValue .:? "reason" .!= "recovered invalid watcher state")
      "watcher_blocked" ->
        WatcherBlocked
          <$> (BlockedReason <$> nonEmptyTextField objectValue "reason")
      "watcher_stopped" ->
        WatcherStopped
          <$> (StopReason <$> nonEmptyTextField objectValue "reason")
      unknown ->
        fail ("unknown watcher event type: " <> Text.unpack unknown)

parsePlannerConfig :: Object -> Parser PlannerConfig
parsePlannerConfig objectValue =
  PlannerConfig
    <$> (RepoName <$> nonEmptyTextField objectValue "repoFullName")
    <*> maxParallelField objectValue "maxParallel"
    <*> scopeIssueNumbersField objectValue

parsePrConfig :: Object -> Parser PrConfig
parsePrConfig objectValue =
  PrConfig
    <$> (RepoName <$> nonEmptyTextField objectValue "repoFullName")
    <*> (PrNumber <$> positiveIntField objectValue "prNumber")
    <*> (BranchName <$> nonEmptyTextField objectValue "branch")

parsePrReviewFixVerificationStarted :: Object -> Parser WatcherEvent
parsePrReviewFixVerificationStarted objectValue = do
  reviewTargetSha <- CommitSha <$> nonEmptyTextField objectValue "commitSha"
  oldReviewedCommitSha <- CommitSha <$> (objectValue .:? "reviewedCommitSha" .!= unCommitSha reviewTargetSha)
  evidence <- parseReviewEvidenceWithCommit objectValue oldReviewedCommitSha Nothing
  reviewerTurnId <- TurnId <$> nonEmptyTextField objectValue "reviewerTurnId"
  pure (PrReviewFixVerificationStarted evidence reviewTargetSha reviewerTurnId)

parseReviewEvidence :: Object -> Key.Key -> Maybe Text -> Parser ReviewEvidence
parseReviewEvidence objectValue commitKey fallback = do
  commit <- CommitSha <$> nonEmptyTextField objectValue commitKey
  parseReviewEvidenceWithCommit objectValue commit fallback

parseReviewEvidenceWithCommit :: Object -> CommitSha -> Maybe Text -> Parser ReviewEvidence
parseReviewEvidenceWithCommit objectValue commit fallback = do
  threadIds <- reviewThreadIdListField objectValue "reviewThreadIds"
  summaries <- reviewFindingListField objectValue "reviewFindings"
  case reviewEvidenceFromParts threadIds summaries commit of
    Just evidence -> pure evidence
    Nothing ->
      case fallback of
        Just summary -> pure (reviewEvidenceFromSummaries (summary :| []) commit)
        Nothing -> fail "review evidence must include reviewThreadIds or reviewFindings"

parseIssueConfig :: Object -> Parser IssueConfig
parseIssueConfig objectValue =
  IssueConfig
    <$> (RepoName <$> nonEmptyTextField objectValue "repoFullName")
    <*> (IssueNumber <$> positiveIntField objectValue "issueNumber")
    <*> (BranchName <$> nonEmptyTextField objectValue "branch")

reviewThreadIds :: [Text] -> Parser (NonEmpty ReviewThreadId)
reviewThreadIds [] = fail "reviewThreadIds must not be empty"
reviewThreadIds (first : rest) = do
  first' <- nonEmptyText "reviewThreadIds[]" first
  rest' <- traverse (nonEmptyText "reviewThreadIds[]") rest
  pure (ReviewThreadId first' :| fmap ReviewThreadId rest')

reviewThreadIdListField :: Object -> Key.Key -> Parser [ReviewThreadId]
reviewThreadIdListField objectValue key = do
  values <- objectValue .:? key .!= ([] :: [Text])
  traverse (fmap ReviewThreadId . nonEmptyText (Key.toString key <> "[]")) values

reviewFindingListField :: Object -> Key.Key -> Parser [Text]
reviewFindingListField objectValue key = do
  values <- objectValue .:? key .!= ([] :: [Text])
  traverse (nonEmptyText (Key.toString key <> "[]")) values

nonEmptyIssueCreationRequests :: [IssueCreationRequest] -> Parser (NonEmpty IssueCreationRequest)
nonEmptyIssueCreationRequests [] = fail "issues must not be empty"
nonEmptyIssueCreationRequests (request : rest) = pure (request :| rest)

nonEmptyTextField :: Object -> Key.Key -> Parser Text
nonEmptyTextField objectValue key = objectValue .: key >>= nonEmptyText (Key.toString key)

nonEmptyText :: String -> Text -> Parser Text
nonEmptyText field value
  | Text.null (Text.strip value) = fail (field <> " must not be empty")
  | otherwise = pure value

positiveIntField :: Object -> Key.Key -> Parser Int
positiveIntField objectValue key = do
  value <- objectValue .: key
  if value > 0
    then pure value
    else fail (Key.toString key <> " must be positive")

maxParallelField :: Object -> Key.Key -> Parser MaxParallel
maxParallelField objectValue key = do
  value <- positiveIntField objectValue key
  maybe (fail (Key.toString key <> " must be positive")) pure (mkMaxParallel value)

nonEmptyTurnId :: Text -> Parser TurnId
nonEmptyTurnId value = TurnId <$> nonEmptyText "implementationTurnId" value

eventType :: WatcherEvent -> [Pair]
eventType event = ["type" .= eventName event]

plannerConfigFields :: PlannerConfig -> [Pair]
plannerConfigFields config =
  [ "repoFullName" .= unRepoName (plannerRepo config)
  , "maxParallel" .= unMaxParallel (plannerMaxParallel config)
  , "scopeIssueNumbers" .= fmap unIssueNumber (plannerScopeIssues config)
  ]

optionalIssueNumberField :: Object -> Key.Key -> Parser (Maybe IssueNumber)
optionalIssueNumberField objectValue key = do
  maybeValue <- objectValue .:? key
  case maybeValue of
    Nothing -> pure Nothing
    Just value
      | value > 0 -> pure (Just (IssueNumber value))
      | otherwise -> fail (Key.toString key <> " must be positive")

scopeIssueNumbersField :: Object -> Parser [IssueNumber]
scopeIssueNumbersField objectValue = do
  legacyScope <- optionalIssueNumberField objectValue "scopeIssueNumber"
  scopeNumbers <- objectValue .:? "scopeIssueNumbers" .!= ([] :: [Int])
  parsedScopeNumbers <- traverse (positiveIssueNumber "scopeIssueNumbers[]") scopeNumbers
  pure (maybe [] (: []) legacyScope <> parsedScopeNumbers)

positiveIssueNumber :: String -> Int -> Parser IssueNumber
positiveIssueNumber field value
  | value > 0 = pure (IssueNumber value)
  | otherwise = fail (field <> " must be positive")

issueConfigFields :: IssueConfig -> [Pair]
issueConfigFields config =
  [ "repoFullName" .= unRepoName (issueRepo config)
  , "issueNumber" .= unIssueNumber (issueNumber config)
  , "branch" .= unBranchName (issueBranch config)
  ]

prConfigFields :: PrConfig -> [Pair]
prConfigFields config =
  [ "repoFullName" .= unRepoName (prRepo config)
  , "prNumber" .= unPrNumber (prNumber config)
  , "branch" .= unBranchName (prBranch config)
  ]

reviewEvidenceFields :: ReviewEvidence -> [Pair]
reviewEvidenceFields evidence =
  [ "reviewThreadIds" .= fmap unReviewThreadId (reviewEvidenceThreadIds evidence)
  , "reviewFindings" .= reviewEvidenceSummaries evidence
  ]

nonEmptyToList :: NonEmpty a -> [a]
nonEmptyToList (first :| rest) = first : rest

eventName :: WatcherEvent -> Text
eventName = \case
  IssuePlanningInitialized {} -> "issue_planning_initialized"
  IssuePlanningTurnStarted {} -> "issue_planning_turn_started"
  IssuePlanningIssuesRequested {} -> "issue_planning_issues_requested"
  IssuePlanningGraphUpdated {} -> "issue_planning_graph_updated"
  IssuePlanningReadyIssuesFixed -> "issue_planning_ready_issues_fixed"
  IssuePlanningScopeCompleted -> "issue_planning_scope_completed"
  IssuePlanningTurnRetryRequested {} -> "issue_planning_turn_retry_requested"
  IssuePlanningTurnCompleted -> "issue_planning_turn_completed"
  PrReviewInitialized {} -> "pr_review_initialized"
  PrReviewThreadsRefreshed {} -> "pr_review_threads_refreshed"
  PrReviewUnresolvedFound {} -> "pr_review_unresolved_found"
  PrReviewFeedbackFound {} -> "pr_review_feedback_found"
  PrReviewNoUnresolvedFound {} -> "pr_review_no_unresolved_found"
  PrReviewFixVerificationStarted {} -> "pr_review_fix_verification_started"
  PrReviewFixCompleted -> "pr_review_fix_completed"
  PrReviewFixIncomplete {} -> "pr_review_fix_incomplete"
  PrReviewCleanFound {} -> "pr_review_clean_found"
  PrReviewProblemsAdded {} -> "pr_review_problems_added"
  PrReviewReviewIncomplete {} -> "pr_review_review_incomplete"
  PrReviewMergeabilityClean {} -> "pr_review_mergeability_clean"
  PrReviewMergeabilityWaiting {} -> "pr_review_mergeability_waiting"
  PrReviewMergeabilityRecheck {} -> "pr_review_mergeability_recheck"
  PrReviewMergeabilityFixRequired {} -> "pr_review_mergeability_fix_required"
  PrReviewMergeCompleted {} -> "pr_review_merge_completed"
  IssueImplementInitialized {} -> "issue_implement_initialized"
  IssueWorkerThreadRefreshed {} -> "issue_worker_thread_refreshed"
  IssueAttemptBranchAdvancedEvent {} -> "issue_attempt_branch_advanced"
  IssuePlanTurnStartedEvent {} -> "issue_plan_turn_started"
  IssuePlanCompletedEvent {} -> "issue_plan_completed"
  IssuePullRequestCreatedEvent {} -> "issue_pr_created"
  IssuePullRequestReusedEvent {} -> "issue_pr_reused"
  IssuePullRequestBodyUpdatedEvent {} -> "issue_pr_body_updated"
  IssueImplementationTurnStartedEvent {} -> "issue_implementation_turn_started"
  IssueImplementationIncompleteEvent {} -> "issue_implementation_incomplete"
  IssueImplementationBlockedEvent {} -> "issue_implementation_blocked"
  IssueReviewerThreadReadyEvent {} -> "issue_reviewer_thread_ready"
  IssueReviewHandoffInitializedEvent {} -> "issue_review_handoff_initialized"
  IssueReviewHandoffStartedEvent {} -> "issue_review_handoff_started"
  IssueImplementationCompletedEvent {} -> "issue_implementation_completed"
  IssuePullRequestMergedEvent {} -> "issue_pr_merged"
  IssuePostMergeReviewStartedEvent {} -> "issue_post_merge_review_started"
  IssuePostMergeReviewCleanEvent {} -> "issue_post_merge_review_clean"
  IssuePostMergeReviewFollowUpEvent {} -> "issue_post_merge_review_follow_up"
  IssuePostMergeReviewIncompleteEvent {} -> "issue_post_merge_review_incomplete"
  IssueClosedEvent {} -> "issue_closed"
  WatcherRecoveredInvalidState {} -> "watcher_recovered_invalid_state"
  WatcherBlocked {} -> "watcher_blocked"
  WatcherStopped {} -> "watcher_stopped"

watcherEventSchemaVersion :: WatcherEvent -> WorkflowSchemaVersion
watcherEventSchemaVersion _ =
  WorkflowSchemaVersion 1

watcherEventMetadataLabels :: [WorkflowMetadataLabel]
watcherEventMetadataLabels =
  fmap
    WorkflowMetadataLabel
    [ "emittedAt"
    , "workflowId"
    , "domain"
    , "phase"
    , "actor"
    , "source"
    , "correlationId"
    ]

watcherEventCodecContract :: WorkflowCodecContract WatcherEvent Value
watcherEventCodecContract =
  WorkflowCodecContract
    { workflowCodecEventTypeLabel = WorkflowEventTypeLabel . eventName
    , workflowCodecSchemaVersion = watcherEventSchemaVersion
    , workflowCodecMetadataLabels = watcherEventMetadataLabels
    , workflowCodecEncode = toJSON
    , workflowCodecEncodedEventTypeLabel = eventTypeLabelFromValue
    , workflowCodecDecode =
        \value ->
          case parseEither parseJSON value of
            Right event -> Right event
            Left reason ->
              Left
                WorkflowDecodeError
                  { workflowDecodeErrorTypeLabel = eventTypeLabelFromValue value
                  , workflowDecodeErrorSchemaVersion = Just (WorkflowSchemaVersion 1)
                  , workflowDecodeErrorReason = Text.pack reason
                  }
    }

eventTypeLabelFromValue :: Value -> Maybe WorkflowEventTypeLabel
eventTypeLabelFromValue (Object objectValue) =
  case KeyMap.lookup "type" objectValue of
    Just (String label) -> Just (WorkflowEventTypeLabel label)
    _ -> Nothing
eventTypeLabelFromValue _ =
  Nothing
