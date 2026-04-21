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
  , loadEventLogFile
  , replayEventLog
  ) where

import CodexWatcher.Effects
import CodexWatcher.StateMachine
import CodexWatcher.Types
import Data.Aeson (FromJSON (..), Object, eitherDecodeStrict', withObject, (.:), (.:?), (.!=))
import Data.Aeson.Types (Parser)
import Data.ByteString qualified as ByteString
import Data.ByteString.Char8 qualified as ByteString.Char8
import Data.Char (isSpace)
import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)
import Data.Text qualified as Text

data WatcherEvent
  = IssuePlanningInitialized PlannerConfig
  | IssuePlanningTurnStarted ThreadId TurnId
  | IssuePlanningTurnCompleted
  | PrReviewInitialized PrConfig ThreadId ThreadId
  | PrReviewUnresolvedFound (NonEmpty ReviewThreadId) CommitSha TurnId
  | PrReviewNoUnresolvedFound CommitSha TurnId
  | PrReviewFixCompleted
  | PrReviewFixIncomplete Text
  | PrReviewCleanFound CleanReviewEvidence
  | PrReviewProblemsAdded CommitSha
  | PrReviewReviewIncomplete Text
  | PrReviewMergeCompleted MergeCommit
  | IssueImplementInitialized IssueConfig ThreadId
  | IssueStartPlanMode TurnId
  | IssuePlanCompletedEvent TurnId
  | IssueImplementationCompletedEvent PrNumber
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

instance FromJSON WatcherEvent where
  parseJSON = withObject "WatcherEvent" \object -> do
    eventType <- object .: "type"
    case eventType :: Text of
      "issue_planning_initialized" ->
        IssuePlanningInitialized
          <$> parsePlannerConfig object
      "issue_planning_turn_started" ->
        IssuePlanningTurnStarted
          <$> (ThreadId <$> object .: "plannerThreadId")
          <*> (TurnId <$> object .: "plannerTurnId")
      "issue_planning_turn_completed" ->
        pure IssuePlanningTurnCompleted
      "pr_review_initialized" ->
        PrReviewInitialized
          <$> parsePrConfig object
          <*> (ThreadId <$> object .: "workerThreadId")
          <*> (ThreadId <$> object .: "reviewerThreadId")
      "pr_review_unresolved_found" ->
        PrReviewUnresolvedFound
          <$> (reviewThreadIds =<< object .: "reviewThreadIds")
          <*> (CommitSha <$> object .: "commitSha")
          <*> (TurnId <$> object .: "workerTurnId")
      "pr_review_no_unresolved_found" ->
        PrReviewNoUnresolvedFound
          <$> (CommitSha <$> object .: "commitSha")
          <*> (TurnId <$> object .: "reviewerTurnId")
      "pr_review_fix_completed" ->
        pure PrReviewFixCompleted
      "pr_review_fix_incomplete" ->
        PrReviewFixIncomplete
          <$> (object .:? "reason" .!= "incomplete")
      "pr_review_clean_found" ->
        PrReviewCleanFound
          <$> (CleanReviewEvidence <$> (CommitSha <$> object .: "commitSha") <*> (object .:? "comment" .!= "LGTM"))
      "pr_review_problems_added" ->
        PrReviewProblemsAdded
          <$> (CommitSha <$> object .: "commitSha")
      "pr_review_review_incomplete" ->
        PrReviewReviewIncomplete
          <$> (object .:? "reason" .!= "incomplete")
      "pr_review_merge_completed" ->
        PrReviewMergeCompleted
          <$> (MergeCommit . CommitSha <$> object .: "mergeCommitSha")
      "issue_implement_initialized" ->
        IssueImplementInitialized
          <$> parseIssueConfig object
          <*> (ThreadId <$> object .: "workerThreadId")
      "issue_start_plan_mode" ->
        IssueStartPlanMode
          <$> (TurnId <$> object .: "planTurnId")
      "issue_plan_completed" ->
        IssuePlanCompletedEvent
          <$> (TurnId <$> object .: "implementationTurnId")
      "issue_implementation_completed" ->
        IssueImplementationCompletedEvent
          <$> (PrNumber <$> object .: "prNumber")
      "watcher_blocked" ->
        WatcherBlocked
          <$> (BlockedReason <$> object .: "reason")
      "watcher_stopped" ->
        WatcherStopped
          <$> (StopReason <$> object .: "reason")
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
      ( SomeWatcherState (IssueNeedsTriage config (WorkerIdle workerThread) :: WatcherState 'IssueImplement 'Triage)
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
applyEvent (SomeWatcherState state@PlanningReady {}) (IssuePlanningTurnStarted plannerThread turnId) =
  fromDecision (step state (StartPlanningTurn (ActiveTurn plannerThread turnId)))
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
applyEvent (SomeWatcherState state@PrMerging {}) (PrReviewMergeCompleted mergeCommit) =
  fromDecision (step state (MergeCompleted mergeCommit))
applyEvent (SomeWatcherState state@(IssueNeedsTriage _config (WorkerIdle threadId))) (IssueStartPlanMode turnId) =
  fromDecision (step state (StartIssuePlanMode (ActiveTurn threadId turnId)))
applyEvent (SomeWatcherState state@(IssueInPlanMode _config (WorkerActive activeTurn))) (IssuePlanCompletedEvent turnId) =
  fromDecision (step state (IssuePlanCompleted (ActiveTurn (activeThreadId activeTurn) turnId)))
applyEvent (SomeWatcherState state@(IssueImplementing _config _worker)) (IssueImplementationCompletedEvent prNumber) =
  fromDecision (step state (IssueImplementationCompleted prNumber))
applyEvent (SomeWatcherState state@(IssueImplementationReady _config _maybePr _worker)) (IssueImplementationCompletedEvent prNumber) =
  fromDecision (step state (IssueImplementationCompleted prNumber))
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
parsePlannerConfig object =
  PlannerConfig
    <$> (RepoName <$> object .: "repoFullName")
    <*> object .: "maxParallel"

parsePrConfig :: Object -> Parser PrConfig
parsePrConfig object =
  PrConfig
    <$> (RepoName <$> object .: "repoFullName")
    <*> (PrNumber <$> object .: "prNumber")
    <*> (BranchName <$> object .: "branch")

parseIssueConfig :: Object -> Parser IssueConfig
parseIssueConfig object =
  IssueConfig
    <$> (RepoName <$> object .: "repoFullName")
    <*> (IssueNumber <$> object .: "issueNumber")
    <*> (BranchName <$> object .: "branch")

reviewThreadIds :: [Text] -> Parser (NonEmpty ReviewThreadId)
reviewThreadIds [] = fail "reviewThreadIds must not be empty"
reviewThreadIds (first : rest) = pure (ReviewThreadId first :| fmap ReviewThreadId rest)

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
  IssuePlanningTurnCompleted -> "issue_planning_turn_completed"
  PrReviewInitialized {} -> "pr_review_initialized"
  PrReviewUnresolvedFound {} -> "pr_review_unresolved_found"
  PrReviewNoUnresolvedFound {} -> "pr_review_no_unresolved_found"
  PrReviewFixCompleted -> "pr_review_fix_completed"
  PrReviewFixIncomplete {} -> "pr_review_fix_incomplete"
  PrReviewCleanFound {} -> "pr_review_clean_found"
  PrReviewProblemsAdded {} -> "pr_review_problems_added"
  PrReviewReviewIncomplete {} -> "pr_review_review_incomplete"
  PrReviewMergeCompleted {} -> "pr_review_merge_completed"
  IssueImplementInitialized {} -> "issue_implement_initialized"
  IssueStartPlanMode {} -> "issue_start_plan_mode"
  IssuePlanCompletedEvent {} -> "issue_plan_completed"
  IssueImplementationCompletedEvent {} -> "issue_implementation_completed"
  WatcherBlocked {} -> "watcher_blocked"
  WatcherStopped {} -> "watcher_stopped"
