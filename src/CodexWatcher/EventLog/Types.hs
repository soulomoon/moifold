{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.EventLog.Types
  ( WatcherEvent (..)
  , ReplayFailure (..)
  , EventReplayResult (..)
  , eventName
  ) where

import CodexWatcher.Effects
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
import CodexWatcher.Core.Limits (MaxParallel, mkMaxParallel, unMaxParallel)
import CodexWatcher.Core.Reason (BlockedReason (..), StopReason (..))
import CodexWatcher.Core.State (SomeWatcherState)
import CodexWatcher.Domain.IssueImplement.Types (IssueConfig (..))
import CodexWatcher.Domain.IssuePlanning.Types (IssueCreationRequest, PlannerConfig (..), PlanningGraph)
import CodexWatcher.Domain.PrReview.Types (CleanReviewEvidence (..), MergeCommit (..), PrConfig (..))
import Data.Aeson (FromJSON (..), Object, ToJSON (..), object, withObject, (.:), (.:?), (.!=), (.=))
import Data.Aeson.Key qualified as Key
import Data.Aeson.Types (Pair, Parser)
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
  | PrReviewNoUnresolvedFound CommitSha TurnId
  | PrReviewFixCompleted
  | PrReviewFixIncomplete Text
  | PrReviewCleanFound CleanReviewEvidence
  | PrReviewProblemsAdded CommitSha
  | PrReviewReviewIncomplete Text
  | PrReviewMergeabilityClean CommitSha
  | PrReviewMergeabilityWaiting Text
  | PrReviewMergeabilityRecheck Text
  | PrReviewMergeCompleted MergeCommit
  | IssueImplementInitialized IssueConfig ThreadId
  | IssueWorkerThreadRefreshed ThreadId
  | IssuePlanTurnStartedEvent TurnId
  | IssuePlanCompletedEvent Text (Maybe TurnId)
  | IssuePullRequestCreatedEvent PrNumber
  | IssuePullRequestReusedEvent PrNumber
  | IssuePullRequestBodyUpdatedEvent PrNumber
  | IssueImplementationTurnStartedEvent TurnId
  | IssueImplementationIncompleteEvent Text
  | IssueImplementationBlockedEvent BlockedReason
  | IssueReviewHandoffInitializedEvent PrNumber
  | IssueReviewHandoffStartedEvent PrNumber
  | IssueImplementationCompletedEvent PrNumber
  | IssuePullRequestMergedEvent PrNumber
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
      PrReviewNoUnresolvedFound commitSha reviewerTurnId ->
        eventType event
          <> [ "commitSha" .= unCommitSha commitSha
             , "reviewerTurnId" .= unTurnId reviewerTurnId
             ]
      PrReviewFixCompleted ->
        eventType event
      PrReviewFixIncomplete reason ->
        eventType event <> ["reason" .= reason]
      PrReviewCleanFound evidence ->
        eventType event
          <> [ "commitSha" .= unCommitSha (cleanReviewCommit evidence)
             , "comment" .= cleanReviewComment evidence
             ]
      PrReviewProblemsAdded commitSha ->
        eventType event <> ["commitSha" .= unCommitSha commitSha]
      PrReviewReviewIncomplete reason ->
        eventType event <> ["reason" .= reason]
      PrReviewMergeabilityClean commitSha ->
        eventType event <> ["commitSha" .= unCommitSha commitSha]
      PrReviewMergeabilityWaiting reason ->
        eventType event <> ["reason" .= reason]
      PrReviewMergeabilityRecheck reason ->
        eventType event <> ["reason" .= reason]
      PrReviewMergeCompleted mergeCommit ->
        eventType event <> ["mergeCommitSha" .= unCommitSha (unMergeCommit mergeCommit)]
      IssueImplementInitialized config workerThreadId ->
        eventType event
          <> issueConfigFields config
          <> ["workerThreadId" .= unThreadId workerThreadId]
      IssueWorkerThreadRefreshed workerThreadId ->
        eventType event <> ["workerThreadId" .= unThreadId workerThreadId]
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
      IssueReviewHandoffInitializedEvent prNumber' ->
        eventType event <> ["prNumber" .= unPrNumber prNumber']
      IssueReviewHandoffStartedEvent prNumber' ->
        eventType event <> ["prNumber" .= unPrNumber prNumber']
      IssueImplementationCompletedEvent prNumber' ->
        eventType event <> ["prNumber" .= unPrNumber prNumber']
      IssuePullRequestMergedEvent prNumber' ->
        eventType event <> ["prNumber" .= unPrNumber prNumber']
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
      "pr_review_no_unresolved_found" ->
        PrReviewNoUnresolvedFound
          <$> (CommitSha <$> nonEmptyTextField objectValue "commitSha")
          <*> (TurnId <$> nonEmptyTextField objectValue "reviewerTurnId")
      "pr_review_fix_completed" ->
        pure PrReviewFixCompleted
      "pr_review_fix_incomplete" ->
        PrReviewFixIncomplete
          <$> (objectValue .:? "reason" .!= "incomplete")
      "pr_review_clean_found" ->
        PrReviewCleanFound
          <$> (CleanReviewEvidence <$> (CommitSha <$> nonEmptyTextField objectValue "commitSha") <*> (objectValue .:? "comment" .!= "LGTM"))
      "pr_review_problems_added" ->
        PrReviewProblemsAdded
          <$> (CommitSha <$> nonEmptyTextField objectValue "commitSha")
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
      "issue_review_handoff_initialized" ->
        IssueReviewHandoffInitializedEvent
          <$> (PrNumber <$> positiveIntField objectValue "prNumber")
      "issue_review_handoff_started" ->
        IssueReviewHandoffStartedEvent
          <$> (PrNumber <$> positiveIntField objectValue "prNumber")
      "issue_implementation_completed" ->
        IssueImplementationCompletedEvent
          <$> (PrNumber <$> positiveIntField objectValue "prNumber")
      "issue_pr_merged" ->
        IssuePullRequestMergedEvent
          <$> (PrNumber <$> positiveIntField objectValue "prNumber")
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
  PrReviewNoUnresolvedFound {} -> "pr_review_no_unresolved_found"
  PrReviewFixCompleted -> "pr_review_fix_completed"
  PrReviewFixIncomplete {} -> "pr_review_fix_incomplete"
  PrReviewCleanFound {} -> "pr_review_clean_found"
  PrReviewProblemsAdded {} -> "pr_review_problems_added"
  PrReviewReviewIncomplete {} -> "pr_review_review_incomplete"
  PrReviewMergeabilityClean {} -> "pr_review_mergeability_clean"
  PrReviewMergeabilityWaiting {} -> "pr_review_mergeability_waiting"
  PrReviewMergeabilityRecheck {} -> "pr_review_mergeability_recheck"
  PrReviewMergeCompleted {} -> "pr_review_merge_completed"
  IssueImplementInitialized {} -> "issue_implement_initialized"
  IssueWorkerThreadRefreshed {} -> "issue_worker_thread_refreshed"
  IssuePlanTurnStartedEvent {} -> "issue_plan_turn_started"
  IssuePlanCompletedEvent {} -> "issue_plan_completed"
  IssuePullRequestCreatedEvent {} -> "issue_pr_created"
  IssuePullRequestReusedEvent {} -> "issue_pr_reused"
  IssuePullRequestBodyUpdatedEvent {} -> "issue_pr_body_updated"
  IssueImplementationTurnStartedEvent {} -> "issue_implementation_turn_started"
  IssueImplementationIncompleteEvent {} -> "issue_implementation_incomplete"
  IssueImplementationBlockedEvent {} -> "issue_implementation_blocked"
  IssueReviewHandoffInitializedEvent {} -> "issue_review_handoff_initialized"
  IssueReviewHandoffStartedEvent {} -> "issue_review_handoff_started"
  IssueImplementationCompletedEvent {} -> "issue_implementation_completed"
  IssuePullRequestMergedEvent {} -> "issue_pr_merged"
  IssueClosedEvent {} -> "issue_closed"
  WatcherRecoveredInvalidState {} -> "watcher_recovered_invalid_state"
  WatcherBlocked {} -> "watcher_blocked"
  WatcherStopped {} -> "watcher_stopped"
