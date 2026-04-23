{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module CodexWatcher.EventLog
  ( WatcherEvent (..)
  , ReplayFailure (..)
  , EventReplayResult (..)
  , eventName
  , loadEventLogFile
  , replayEventLog
  ) where

import CodexWatcher.Effects
import CodexWatcher.StateMachine
import CodexWatcher.Types
import Data.Aeson (FromJSON (..), Object, ToJSON (..), eitherDecodeStrict', object, withObject, (.:), (.:?), (.!=), (.=))
import Data.Aeson.Key qualified as Key
import Data.Aeson.Types (Pair, Parser)
import Data.ByteString qualified as ByteString
import Data.ByteString.Char8 qualified as ByteString.Char8
import Data.Char (isSpace)
import Data.List (find, intersect)
import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)
import Data.Text qualified as Text

data WatcherEvent
  = IssuePlanningInitialized PlannerConfig
  | IssuePlanningTurnStarted ThreadId TurnId
  | IssuePlanningIssuesRequested [IssueCreationRequest]
  | IssuePlanningGraphUpdated PlanningGraph
  | IssuePlanningReadyIssuesFixed
  | IssuePlanningScopeCompleted
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

loadEventLogFile :: FilePath -> IO (Either String [WatcherEvent])
loadEventLogFile path = do
  bytes <- ByteString.readFile path
  pure (traverse parseLine (numberedNonBlankLines bytes))

replayEventLog :: [WatcherEvent] -> Either ReplayFailure EventReplayResult
replayEventLog = go 1 Nothing []
 where
  go _ (Just state) effects [] =
    Right EventReplayResult { replayState = state, replayEffects = reverse effects }
  go index Nothing effects (event : rest) =
    case initializeFromEvent event of
      Right (state, effectPlan) -> go (index + 1) (Just state) (effectPlan : effects) rest
      Left reason -> Left ReplayFailure { eventIndex = index, event, reason }
  go index (Just state) effects (event : rest) =
    case applyEvent state event of
      Right (state', effectPlan) -> go (index + 1) (Just state') (effectPlan : effects) rest
      Left reason -> Left ReplayFailure { eventIndex = index, event, reason }
  go index Nothing _ [] =
    Left ReplayFailure { eventIndex = index, event = WatcherStopped (StopReason "empty event log"), reason = "event log is empty" }

initializeFromEvent :: WatcherEvent -> Either Text (SomeWatcherState, EffectPlan)
initializeFromEvent = \case
  IssuePlanningInitialized config ->
    Right
      ( SomeWatcherState (PlanningReady config :: WatcherState 'IssuePlanning 'Initialized)
      , []
      )
  PrReviewInitialized config workerThread reviewerThread ->
    Right
      ( SomeWatcherState (PrCheckingReviews config (WorkerIdle workerThread) (ReviewerIdle reviewerThread) :: WatcherState 'PrReview 'CheckingReviews)
      , []
      )
  IssueImplementInitialized config workerThread ->
    Right
      ( SomeWatcherState (IssueImplementationReady config Nothing (WorkerIdle workerThread) :: WatcherState 'IssueImplement 'Implementing)
      , []
      )
  event ->
    Left ("first event must initialize a watcher, got " <> eventName event)

applyEvent :: SomeWatcherState -> WatcherEvent -> Either Text (SomeWatcherState, EffectPlan)
applyEvent state event
  | isTerminalPhase (somePhase state) =
      terminalEvent state event
applyEvent _ event@PrReviewInitialized {} =
  Left ("duplicate initialization event: " <> eventName event)
applyEvent _ event@IssueImplementInitialized {} =
  Left ("duplicate initialization event: " <> eventName event)
applyEvent _ event@IssuePlanningInitialized {} =
  Left ("duplicate initialization event: " <> eventName event)
applyEvent (SomeWatcherState (PrCheckingReviews config (WorkerIdle _oldWorker) (ReviewerIdle _oldReviewer))) (PrReviewThreadsRefreshed workerThread reviewerThread) =
  Right (SomeWatcherState (PrCheckingReviews config (WorkerIdle workerThread) (ReviewerIdle reviewerThread)), [])
applyEvent (SomeWatcherState (PrWaitingForMergeability config evidence (WorkerIdle _oldWorker) (ReviewerIdle _oldReviewer))) (PrReviewThreadsRefreshed workerThread reviewerThread) =
  Right (SomeWatcherState (PrWaitingForMergeability config evidence (WorkerIdle workerThread) (ReviewerIdle reviewerThread)), [])
applyEvent (SomeWatcherState state@PlanningReady {}) (IssuePlanningTurnStarted plannerThread turnId) =
  fromDecision (step state (StartPlanningTurn (ActiveTurn plannerThread turnId)))
applyEvent (SomeWatcherState state@PlanningTurnActive {}) (IssuePlanningIssuesRequested requests) =
  fromDecision (step state (PlannerRequestedIssueCreation requests))
applyEvent (SomeWatcherState state@PlanningTurnActive {}) (IssuePlanningGraphUpdated graph) =
  case state of
    PlanningTurnActive config _activeTurn ->
      case validatePlanningGraphForReplay config graph of
        Left reason -> Left reason
        Right () -> fromDecision (step state (PlannerUpdatedGraph graph))
applyEvent (SomeWatcherState state@PlanningWaitingForReadyIssues {}) IssuePlanningReadyIssuesFixed =
  fromDecision (step state PlannerReadyIssuesFixed)
applyEvent (SomeWatcherState state@PlanningReady {}) IssuePlanningScopeCompleted =
  fromDecision (step state PlannerScopeCompleted)
applyEvent (SomeWatcherState state@PlanningTurnActive {}) IssuePlanningTurnCompleted =
  fromDecision (step state PlannerTurnCompleted)
applyEvent (SomeWatcherState state@(PrCheckingReviews _config (WorkerIdle workerThread) _reviewer)) (PrReviewUnresolvedFound threadIds commit turnId) =
  fromDecision (step state (ReviewThreadsFound (ReviewEvidence threadIds commit) (ActiveTurn workerThread turnId)))
applyEvent (SomeWatcherState state@(PrCheckingReviews _config _worker (ReviewerIdle reviewerThread))) (PrReviewNoUnresolvedFound commit turnId) =
  fromDecision (step state (NoReviewThreadsFound commit (ActiveTurn reviewerThread turnId)))
applyEvent (SomeWatcherState state@PrFixingReviews {}) PrReviewFixCompleted =
  fromDecision (step state ReviewFixCompleted)
applyEvent (SomeWatcherState state@PrFixingReviews {}) (PrReviewFixIncomplete _reason) =
  fromDecision (step state ReviewFixIncomplete)
applyEvent (SomeWatcherState state@PrReviewingClean {}) (PrReviewCleanFound evidence) =
  fromDecision (step state (ReviewerFoundClean evidence))
applyEvent (SomeWatcherState state@PrReviewingClean {}) (PrReviewProblemsAdded _commit) =
  fromDecision (step state ReviewerFoundProblems)
applyEvent (SomeWatcherState state@PrReviewingClean {}) (PrReviewReviewIncomplete _reason) =
  fromDecision (step state ReviewerTurnIncomplete)
applyEvent (SomeWatcherState state@PrWaitingForMergeability {}) event@(PrReviewMergeabilityClean commitSha) =
  case state of
    PrWaitingForMergeability _config evidence _worker _reviewer
      | cleanReviewCommit evidence == commitSha ->
          fromDecision (step state MergeabilityClean)
      | otherwise ->
          Left ("event " <> eventName event <> " does not match reviewed commit")
applyEvent (SomeWatcherState state@PrWaitingForMergeability {}) (PrReviewMergeabilityWaiting reason) =
  fromDecision (step state (MergeabilityRetryLater reason))
applyEvent (SomeWatcherState state@PrWaitingForMergeability {}) (PrReviewMergeabilityRecheck reason) =
  fromDecision (step state (MergeabilityRecheckReviews reason))
applyEvent (SomeWatcherState state@PrMerging {}) (PrReviewMergeCompleted mergeCommit) =
  fromDecision (step state (MergeCompleted mergeCommit))
applyEvent (SomeWatcherState state@(IssueReadyToPlan _config _prNumber (WorkerIdle threadId))) (IssuePlanTurnStartedEvent turnId) =
  fromDecision (step state (StartReadyIssuePlanTurn (ActiveTurn threadId turnId)))
applyEvent (SomeWatcherState (IssueReadyToPlan config prNumber (WorkerIdle _oldThread))) (IssueWorkerThreadRefreshed threadId) =
  Right (SomeWatcherState (IssueReadyToPlan config prNumber (WorkerIdle threadId)), [])
applyEvent (SomeWatcherState state@(IssueInPlanMode _config _prNumber (WorkerActive activeTurn))) (IssuePlanCompletedEvent planMarkdown turnId) =
  fromDecision (step state (IssuePlanCompleted planMarkdown (ActiveTurn (activeThreadId activeTurn) <$> turnId)))
applyEvent (SomeWatcherState (IssuePlanReady config prNumber (WorkerIdle _oldThread))) (IssueWorkerThreadRefreshed threadId) =
  Right (SomeWatcherState (IssuePlanReady config prNumber (WorkerIdle threadId)), [])
applyEvent (SomeWatcherState (IssueImplementationReady config maybePr (WorkerIdle _oldThread))) (IssueWorkerThreadRefreshed threadId) =
  Right (SomeWatcherState (IssueImplementationReady config maybePr (WorkerIdle threadId)), [])
applyEvent (SomeWatcherState state@(IssueImplementationReady _config _maybePr _worker)) (IssuePullRequestCreatedEvent prNumber) =
  fromDecision (step state (IssuePullRequestReady prNumber))
applyEvent (SomeWatcherState state@(IssueImplementationReady _config _maybePr _worker)) (IssuePullRequestReusedEvent prNumber) =
  fromDecision (step state (IssuePullRequestReady prNumber))
applyEvent (SomeWatcherState state@(IssueImplementing _config _maybePr _worker)) (IssuePullRequestCreatedEvent prNumber) =
  fromDecision (step state (IssuePullRequestReady prNumber))
applyEvent (SomeWatcherState state@(IssueImplementing _config _maybePr _worker)) (IssuePullRequestReusedEvent prNumber) =
  fromDecision (step state (IssuePullRequestReady prNumber))
applyEvent (SomeWatcherState state@(IssuePlanReady _config expectedPrNumber _worker)) event@(IssuePullRequestBodyUpdatedEvent prNumber)
  | expectedPrNumber == prNumber =
      fromDecision (step state (IssuePullRequestBodyUpdated prNumber))
  | otherwise =
      Left ("event " <> eventName event <> " does not match a known PR")
applyEvent (SomeWatcherState state@(IssueImplementationReady _config maybePr _worker)) event@(IssuePullRequestBodyUpdatedEvent prNumber)
  | maybePr == Just prNumber =
      fromDecision (step state (IssuePullRequestBodyUpdated prNumber))
  | otherwise =
      Left ("event " <> eventName event <> " does not match a known PR")
applyEvent (SomeWatcherState state@(IssueImplementing _config maybePr _worker)) event@(IssuePullRequestBodyUpdatedEvent prNumber)
  | maybePr == Just prNumber =
      fromDecision (step state (IssuePullRequestBodyUpdated prNumber))
  | otherwise =
      Left ("event " <> eventName event <> " does not match a known PR")
applyEvent (SomeWatcherState state@(IssueImplementationReady _config _maybePr (WorkerIdle threadId))) (IssueImplementationTurnStartedEvent turnId) =
  fromDecision (step state (StartIssueImplementationTurn (ActiveTurn threadId turnId)))
applyEvent (SomeWatcherState state@(IssueImplementing _config _maybePr _worker)) (IssueImplementationIncompleteEvent _reason) =
  fromDecision (step state IssueImplementationIncomplete)
applyEvent (SomeWatcherState state@IssueHandoffReady {}) (IssueReviewHandoffInitializedEvent prNumber) =
  fromDecision (step state (IssueReviewHandoffInitialized prNumber))
applyEvent (SomeWatcherState state@IssueHandoffInitialized {}) (IssueReviewHandoffInitializedEvent prNumber) =
  fromDecision (step state (IssueReviewHandoffInitialized prNumber))
applyEvent (SomeWatcherState state@IssueHandoffInitialized {}) (IssueReviewHandoffStartedEvent prNumber) =
  fromDecision (step state (IssueReviewHandoffStarted prNumber))
applyEvent (SomeWatcherState state@IssueWaitingForPrMerge {}) (IssueReviewHandoffInitializedEvent prNumber) =
  fromDecision (step state (IssueReviewHandoffInitialized prNumber))
applyEvent (SomeWatcherState state@IssueWaitingForPrMerge {}) (IssueReviewHandoffStartedEvent prNumber) =
  fromDecision (step state (IssueReviewHandoffStarted prNumber))
applyEvent (SomeWatcherState state@IssueImplementationReady {}) (IssueImplementationBlockedEvent reason) =
  fromDecision (step state (MarkBlocked reason))
applyEvent (SomeWatcherState state@IssueImplementing {}) (IssueImplementationBlockedEvent reason) =
  fromDecision (step state (MarkBlocked reason))
applyEvent (SomeWatcherState state@IssueHandoffReady {}) (IssueImplementationBlockedEvent reason) =
  fromDecision (step state (MarkBlocked reason))
applyEvent (SomeWatcherState state@IssueHandoffInitialized {}) (IssueImplementationBlockedEvent reason) =
  fromDecision (step state (MarkBlocked reason))
applyEvent (SomeWatcherState state@IssueWaitingForPrMerge {}) (IssueImplementationBlockedEvent reason) =
  fromDecision (step state (MarkBlocked reason))
applyEvent (SomeWatcherState state@(IssueImplementing _config _maybePr _worker)) (IssueImplementationCompletedEvent prNumber) =
  fromDecision (step state (IssueImplementationCompleted prNumber))
applyEvent (SomeWatcherState state@IssueHandoffReady {}) (IssueImplementationCompletedEvent prNumber) =
  fromDecision (step state (IssueImplementationCompleted prNumber))
applyEvent (SomeWatcherState state@IssueHandoffInitialized {}) (IssueImplementationCompletedEvent prNumber) =
  fromDecision (step state (IssueImplementationCompleted prNumber))
applyEvent (SomeWatcherState state@IssueWaitingForPrMerge {}) (IssueImplementationCompletedEvent prNumber) =
  fromDecision (step state (IssueImplementationCompleted prNumber))
applyEvent (SomeWatcherState state@IssueWaitingForPrMerge {}) (IssuePullRequestMergedEvent prNumber) =
  fromDecision (step state (IssuePullRequestMerged prNumber))
applyEvent (SomeWatcherState state@IssueWaitingForIssueClose {}) (IssueClosedEvent prNumber) =
  fromDecision (step state (IssueClosed prNumber))
applyEvent (SomeWatcherState state) (WatcherRecoveredInvalidState _reason) =
  Right (SomeWatcherState state, [])
applyEvent (SomeWatcherState state) (WatcherBlocked reason) =
  Right (blockSameDomain state reason, [SomeEffect (RecordBlocked reason), SomeEffect StopDaemon])
applyEvent (SomeWatcherState state) (WatcherStopped reason) =
  Right (stopSameDomain state reason, [SomeEffect StopDaemon])
applyEvent state event =
  Left ("event " <> eventName event <> " is invalid in " <> Text.pack (show (someDomain state)) <> "/" <> Text.pack (show (somePhase state)))

terminalEvent :: SomeWatcherState -> WatcherEvent -> Either Text (SomeWatcherState, EffectPlan)
terminalEvent state event =
  case event of
    WatcherStopped reason ->
      case state of
        SomeWatcherState typedState -> Right (stopSameDomain typedState reason, [SomeEffect StopDaemon])
    _ ->
      Left ("event " <> eventName event <> " cannot run after terminal phase " <> Text.pack (show (somePhase state)))

fromDecision :: KnownDomain domain => Decision domain -> Either Text (SomeWatcherState, EffectPlan)
fromDecision (Decision state effects) = Right (SomeWatcherState state, effects)

blockSameDomain :: forall domain phase. KnownDomain domain => WatcherState domain phase -> BlockedReason -> SomeWatcherState
blockSameDomain _ reason = SomeWatcherState (BlockedState reason :: WatcherState domain 'Blocked)

stopSameDomain :: forall domain phase. KnownDomain domain => WatcherState domain phase -> StopReason -> SomeWatcherState
stopSameDomain _ reason = SomeWatcherState (StoppedState reason :: WatcherState domain 'Stopped)

parsePlannerConfig :: Object -> Parser PlannerConfig
parsePlannerConfig objectValue =
  PlannerConfig
    <$> (RepoName <$> nonEmptyTextField objectValue "repoFullName")
    <*> positiveIntField objectValue "maxParallel"
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

nonEmptyIssueCreationRequests :: [IssueCreationRequest] -> Parser [IssueCreationRequest]
nonEmptyIssueCreationRequests [] = fail "issues must not be empty"
nonEmptyIssueCreationRequests requests = pure requests

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

nonEmptyTurnId :: Text -> Parser TurnId
nonEmptyTurnId value = TurnId <$> nonEmptyText "implementationTurnId" value

eventType :: WatcherEvent -> [Pair]
eventType event = ["type" .= eventName event]

plannerConfigFields :: PlannerConfig -> [Pair]
plannerConfigFields config =
  [ "repoFullName" .= unRepoName (plannerRepo config)
  , "maxParallel" .= plannerMaxParallel config
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

validatePlanningGraphForReplay :: PlannerConfig -> PlanningGraph -> Either Text ()
validatePlanningGraphForReplay config graph
  | hasDuplicate graph.planningReadyIssues =
      Left "planning graph has duplicate ready issues"
  | hasDuplicate blockedIssues =
      Left "planning graph has duplicate blocked issues"
  | not (null (graph.planningReadyIssues `intersect` blockedIssues)) =
      Left "planning graph marks an issue as both ready and blocked"
  | any readyIssueHasDependency graph.planningDependencies =
      Left "planning graph marks a dependent issue as ready"
  | Just issue <- outOfScopeIssue =
      Left ("planning graph references issue outside configured scope: #" <> Text.pack (show (unIssueNumber issue)))
  | otherwise =
      Right ()
 where
  blockedIssues = fmap blockedPlanningIssue graph.planningBlockedIssues
  dependencyIssues = concatMap (\dependency -> dependency.dependencyIssue : dependency.dependencyDependsOn) graph.planningDependencies
  graphIssues = graph.planningReadyIssues <> blockedIssues <> dependencyIssues
  outOfScopeIssue =
    case plannerScopeIssues config of
      [] -> Nothing
      scopeIssues -> find (`notElem` scopeIssues) graphIssues
  readyIssueHasDependency dependency =
    dependency.dependencyIssue `elem` graph.planningReadyIssues && not (null dependency.dependencyDependsOn)

hasDuplicate :: Eq a => [a] -> Bool
hasDuplicate [] = False
hasDuplicate (item : rest) = item `elem` rest || hasDuplicate rest

numberedNonBlankLines :: ByteString.ByteString -> [(Int, ByteString.ByteString)]
numberedNonBlankLines =
  filter (not . ByteString.Char8.all isSpace . snd)
    . zip [1 ..]
    . ByteString.Char8.lines

parseLine :: (Int, ByteString.ByteString) -> Either String WatcherEvent
parseLine (lineNumber, line) =
  case eitherDecodeStrict' line of
    Left error' -> Left ("line " <> show lineNumber <> ": " <> error')
    Right event -> Right event

eventName :: WatcherEvent -> Text
eventName = \case
  IssuePlanningInitialized {} -> "issue_planning_initialized"
  IssuePlanningTurnStarted {} -> "issue_planning_turn_started"
  IssuePlanningIssuesRequested {} -> "issue_planning_issues_requested"
  IssuePlanningGraphUpdated {} -> "issue_planning_graph_updated"
  IssuePlanningReadyIssuesFixed -> "issue_planning_ready_issues_fixed"
  IssuePlanningScopeCompleted -> "issue_planning_scope_completed"
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
