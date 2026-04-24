{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Domain.IssueImplement.Loop
  ( runIssueHandoffInitialized
  , runIssueHandoffReady
  , runIssueImplementationReady
  , runIssueImplementing
  , runIssuePlanActive
  , runIssuePlanReady
  , runIssueReadyToPlan
  , runIssueWaitingForIssueClose
  , runIssueWaitingForPrMerge
  ) where

import CodexWatcher.ActionExecutor
import CodexWatcher.Daemon (DaemonFailure (..), DaemonObservation (..), DaemonOptions (..))
import CodexWatcher.DaemonLoop.Types
import CodexWatcher.EffectInterpreter
import CodexWatcher.Effects
import CodexWatcher.EventLog.Types
import CodexWatcher.GhGit
import CodexWatcher.Domain.IssueImplement.TurnClassifier
import CodexWatcher.Domain.IssueImplement.Watcher
import CodexWatcher.Runtime.Command.Render (commandText)
import CodexWatcher.Runtime.Command.Types (CommandReport (..), RuntimeCommand (..))
import CodexWatcher.Runtime.Interpreter (RuntimeInterpreter (..))
import CodexWatcher.Runtime.Json (decodeJsonText)
import CodexWatcher.Core.Types
import Data.Aeson (Result (..), Value (..), fromJSON)
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Foldable (toList)
import Data.List (find)
import Data.Maybe (mapMaybe, maybeToList)
import Data.Text (Text)
import Data.Text qualified as Text

runIssueReadyToPlan
  :: DomainLoopOps m
  -> ActionExecutor m
  -> DaemonLoopConfig
  -> [WatcherEvent]
  -> IssueConfig
  -> PrNumber
  -> ThreadId
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
runIssueReadyToPlan ops executor config events issueConfig prNumber workerThread =
  ops.loopPrestartAndObserve
    executor
    config
    events
    (StartIssuePlanWorkerTurnKind issueConfig prNumber)
    workerThread
    (DaemonIssueImplementObservation . ObservedPlanTurnStarted)

runIssuePlanActive
  :: Monad m
  => DomainLoopOps m
  -> ActionExecutor m
  -> DaemonLoopConfig
  -> [WatcherEvent]
  -> EventReplayResult
  -> ActiveTurn
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
runIssuePlanActive ops executor config events replay activeTurn =
  observeClassifiedActiveTurn ops executor config events replay activeTurn \turn ->
    fmap DaemonIssueImplementObservation (classifyIssuePlanTurn turn)

runIssuePlanReady
  :: Monad m
  => DomainLoopOps m
  -> ActionExecutor m
  -> DaemonLoopConfig
  -> [WatcherEvent]
  -> EventReplayResult
  -> IssueConfig
  -> PrNumber
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
runIssuePlanReady =
  updatePullRequestBody

runIssueImplementationReady
  :: Monad m
  => DomainLoopOps m
  -> ActionExecutor m
  -> DaemonLoopConfig
  -> [WatcherEvent]
  -> EventReplayResult
  -> IssueConfig
  -> Maybe PrNumber
  -> ThreadId
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
runIssueImplementationReady ops executor config events replay issueConfig maybePrNumber workerThread =
  case maybePrNumber of
    Nothing ->
      observeExistingPullRequest ops executor config events replay issueConfig
    Just _prNumber ->
      ops.loopPrestartAndObserve
        executor
        config
        events
        StartIssueImplementationWorkerTurnKind
        workerThread
        (DaemonIssueImplementObservation . ObservedImplementationTurnStarted)

runIssueImplementing
  :: Monad m
  => DomainLoopOps m
  -> ActionExecutor m
  -> DaemonLoopConfig
  -> [WatcherEvent]
  -> EventReplayResult
  -> Maybe PrNumber
  -> ActiveTurn
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
runIssueImplementing ops executor config events replay maybePr activeTurn =
  observeClassifiedActiveTurn ops executor config events replay activeTurn \turn ->
    fmap DaemonIssueImplementObservation (classifyIssueImplementationTurn maybePr turn)

runIssueHandoffReady
  :: DomainLoopOps m
  -> ActionExecutor m
  -> DaemonLoopConfig
  -> [WatcherEvent]
  -> PrNumber
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
runIssueHandoffReady ops executor config events prNumber =
  ops.loopObserveWithExecutor executor config events (DaemonIssueImplementObservation (ObservedReviewHandoffInitialized prNumber))

runIssueHandoffInitialized
  :: DomainLoopOps m
  -> ActionExecutor m
  -> DaemonLoopConfig
  -> [WatcherEvent]
  -> PrNumber
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
runIssueHandoffInitialized ops executor config events prNumber =
  ops.loopObserveWithExecutor executor config events (DaemonIssueImplementObservation (ObservedReviewHandoffStarted prNumber))

runIssueWaitingForPrMerge
  :: Monad m
  => DomainLoopOps m
  -> ActionExecutor m
  -> DaemonLoopConfig
  -> [WatcherEvent]
  -> EventReplayResult
  -> IssueConfig
  -> PrNumber
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
runIssueWaitingForPrMerge ops executor config events replay issueConfig prNumber = do
  pullRequest <- runGhPrView executor.actionRuntime issueConfig.issueRepo prNumber
  case pullRequest of
    Left reason -> pure (Left (DaemonLoopExternalFailure reason))
    Right remote
      | remotePullRequestIsMerged remote ->
          ops.loopObserveWithExecutor executor config events (DaemonIssueImplementObservation (ObservedPullRequestMerged prNumber))
      | otherwise ->
          ops.loopIdle executor config replay ("waiting for PR merge before closing issue: #" <> Text.pack (show (unPrNumber prNumber)))

runIssueWaitingForIssueClose
  :: Monad m
  => DomainLoopOps m
  -> ActionExecutor m
  -> DaemonLoopConfig
  -> [WatcherEvent]
  -> EventReplayResult
  -> IssueConfig
  -> PrNumber
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
runIssueWaitingForIssueClose ops executor config events replay issueConfig prNumber = do
  issue <- runGhIssueView executor.actionRuntime issueConfig.issueRepo issueConfig.issueNumber
  case issue of
    Left reason -> pure (Left (DaemonLoopExternalFailure reason))
    Right remote
      | remoteIssueIsClosed remote ->
          ops.loopObserveWithExecutor executor config events (DaemonIssueImplementObservation (ObservedIssueClosed prNumber))
      | otherwise ->
          retryCloseIssue executor config replay issueConfig prNumber

observeExistingPullRequest
  :: Monad m
  => DomainLoopOps m
  -> ActionExecutor m
  -> DaemonLoopConfig
  -> [WatcherEvent]
  -> EventReplayResult
  -> IssueConfig
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
observeExistingPullRequest ops executor config events replay issueConfig = do
  pullRequests <- runGhPrListOpen executor.actionRuntime issueConfig.issueRepo
  case pullRequests of
    Left reason -> pure (Left (DaemonLoopExternalFailure reason))
    Right openPullRequests ->
      case find ((== issueConfig.issueBranch) . ghPullRequestHeadRefName) openPullRequests of
        Nothing -> retryCreatePullRequest ops executor config events replay issueConfig
        Just pullRequest -> do
          linked <- validateExistingPullRequestLink executor issueConfig pullRequest
          case linked of
            Left reason ->
              pure (Left (DaemonLoopExternalFailure reason))
            Right True ->
              ops.loopObserveWithExecutor
                executor
                config
                events
                (DaemonIssueImplementObservation (ObservedPullRequestReused pullRequest.ghPullRequestNumber))
            Right False ->
              ops.loopObserveWithExecutor
                executor
                config
                events
                ( DaemonIssueImplementObservation
                    ( ObservedIssueImplementBlocked
                        ( BlockedReason
                            ( "open PR #"
                                <> Text.pack (show (unPrNumber pullRequest.ghPullRequestNumber))
                                <> " already uses branch "
                                <> unBranchName issueConfig.issueBranch
                                <> " but is not linked to issue #"
                                <> Text.pack (show (unIssueNumber issueConfig.issueNumber))
                            )
                        )
                    )
                )

validateExistingPullRequestLink :: Monad m => ActionExecutor m -> IssueConfig -> GhPullRequest -> m (Either Text Bool)
validateExistingPullRequestLink executor issueConfig pullRequest
  | pullRequestLinkedToIssue issueConfig pullRequest =
      pure (Right True)
  | otherwise = do
      report <-
        executor.actionRuntime.runtimeRunCommand
          (GhPrView issueConfig.issueRepo pullRequest.ghPullRequestNumber ["body", "closingIssuesReferences"])
      pure do
        if report.ok
          then pullRequestLinkJsonLinksIssue issueConfig.issueNumber <$> decodeJsonText ("PR #" <> Text.pack (show (unPrNumber pullRequest.ghPullRequestNumber))) report.stdout
          else Left ("could not validate existing PR link: " <> commandText report)

pullRequestLinkedToIssue :: IssueConfig -> GhPullRequest -> Bool
pullRequestLinkedToIssue issueConfig pullRequest =
  issueConfig.issueNumber `elem` pullRequest.ghPullRequestLinkedIssueNumbers
    || maybe False (bodyLinksIssue issueConfig.issueNumber) pullRequest.ghPullRequestBody

pullRequestLinkJsonLinksIssue :: IssueNumber -> Value -> Bool
pullRequestLinkJsonLinksIssue issueNumber value =
  issueNumber `elem` jsonLinkedIssueNumbers value
    || maybe False (bodyLinksIssue issueNumber) (jsonTextField "body" value)

jsonLinkedIssueNumbers :: Value -> [IssueNumber]
jsonLinkedIssueNumbers value =
  case jsonField "closingIssuesReferences" value of
    Just (Array references) -> mapMaybe jsonIssueNumber (toList references)
    _ -> []

jsonIssueNumber :: Value -> Maybe IssueNumber
jsonIssueNumber (Object objectValue) = do
  value <- KeyMap.lookup (Key.fromText "number") objectValue
  case fromJSON value of
    Success number -> Just (IssueNumber number)
    Error _ -> Nothing
jsonIssueNumber _ = Nothing

jsonTextField :: Text -> Value -> Maybe Text
jsonTextField key value = do
  String text <- jsonField key value
  pure text

jsonField :: Text -> Value -> Maybe Value
jsonField key (Object objectValue) =
  KeyMap.lookup (Key.fromText key) objectValue
jsonField _ _ =
  Nothing

bodyLinksIssue :: IssueNumber -> Text -> Bool
bodyLinksIssue issueNumber body =
  any (`Text.isInfixOf` normalizedBody) linkPhrases
 where
  issueRef = "#" <> Text.pack (show (unIssueNumber issueNumber))
  normalizedBody = Text.toLower body
  linkPhrases =
    [ "close " <> issueRef
    , "closes " <> issueRef
    , "closed " <> issueRef
    , "fix " <> issueRef
    , "fixes " <> issueRef
    , "fixed " <> issueRef
    , "resolve " <> issueRef
    , "resolves " <> issueRef
    , "resolved " <> issueRef
    ]

retryCreatePullRequest
  :: Monad m
  => DomainLoopOps m
  -> ActionExecutor m
  -> DaemonLoopConfig
  -> [WatcherEvent]
  -> EventReplayResult
  -> IssueConfig
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
retryCreatePullRequest ops executor config events replay issueConfig =
  runIssueEffectPlan
    executor
    config
    replay
    [SomeEffect (CreatePullRequest issueConfig)]
    ("would create pull request for branch " <> unBranchName issueConfig.issueBranch)
    \reports ->
      case onlyCommandReport "PR creation" reports of
        Left failure ->
          pure (Left failure)
        Right commandAction ->
          case successfulCommandActionReport commandAction of
            Left failure ->
              pure (Left failure)
            Right successful ->
              let report = successful.successfulCommandActionExecutionReport
                  commandReport = successful.successfulCommandActionCommandReport
               in case parseGhPrCreateResult commandReport.stdout of
                    Left reason ->
                      pure (Left (invalidCommandResult report reason))
                    Right (GhPullRequestCreated prNumber) ->
                      withPrependedActionReport report <$> ops.loopObserveWithExecutor executor config events (DaemonIssueImplementObservation (ObservedPullRequestCreated prNumber))
                    Right (GhPullRequestReused prNumber) ->
                      withPrependedActionReport report <$> ops.loopObserveWithExecutor executor config events (DaemonIssueImplementObservation (ObservedPullRequestReused prNumber))

updatePullRequestBody
  :: Monad m
  => DomainLoopOps m
  -> ActionExecutor m
  -> DaemonLoopConfig
  -> [WatcherEvent]
  -> EventReplayResult
  -> IssueConfig
  -> PrNumber
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
updatePullRequestBody ops executor config events replay issueConfig prNumber = do
  let planRecordEffects =
        [ SomeEffect (RecordIssuePlan issueConfig prNumber planMarkdown)
        | planMarkdown <- maybeToList (latestIssuePlanMarkdown events)
        ]
  runIssueEffectPlan
    executor
    config
    replay
    (planRecordEffects <> [SomeEffect (UpdatePullRequestBody issueConfig prNumber)])
    ("would update pull request body for PR #" <> Text.pack (show (unPrNumber prNumber)))
    \reports ->
      case requireFinalCommandReport "PR body update" reports of
        Left failure ->
          pure (Left failure)
        Right commandAction ->
          case successfulCommandActionReport commandAction of
            Left failure ->
              pure (Left failure)
            Right _successful ->
              withPrependedActionReports reports <$> ops.loopObserveWithExecutor executor config events (DaemonIssueImplementObservation (ObservedPullRequestBodyUpdated prNumber))

latestIssuePlanMarkdown :: [WatcherEvent] -> Maybe Text
latestIssuePlanMarkdown =
  foldl' step Nothing
 where
  step _latestPlan (IssuePlanCompletedEvent planMarkdown _maybeImplementationTurn) = Just planMarkdown
  step latestPlan _event = latestPlan

retryCloseIssue
  :: Monad m
  => ActionExecutor m
  -> DaemonLoopConfig
  -> EventReplayResult
  -> IssueConfig
  -> PrNumber
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
retryCloseIssue executor config replay issueConfig prNumber =
  runIssueEffectPlan
    executor
    config
    replay
    [ SomeEffect (CloseIssue issueConfig prNumber)
    , SomeEffect SleepUntilNextPoll
    ]
    ("would close issue after merged PR #" <> Text.pack (show (unPrNumber prNumber)))
    \reports ->
      pure case firstCommandFailure reports of
        Just failure -> Left (DaemonLoopDaemonFailure failure)
        Nothing ->
          Right (idleTickResult replay ("closed issue after merged PR #" <> Text.pack (show (unPrNumber prNumber)) <> "; waiting to observe closed issue") reports)

runIssueEffectPlan
  :: Monad m
  => ActionExecutor m
  -> DaemonLoopConfig
  -> EventReplayResult
  -> [SomeEffect]
  -> Text
  -> ([ActionExecutionReport] -> m (Either DaemonLoopFailure DaemonLoopTickResult))
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
runIssueEffectPlan executor config replay effects dryRunReason onExecute = do
  let plan = compileEffectPlan config.loopDaemonOptions.daemonRuntimeConfig effects
  reports <- executeCompiledEffectPlan executor config.loopDaemonOptions.daemonExecutionMode plan
  case config.loopDaemonOptions.daemonExecutionMode of
    DryRunActions ->
      pure (Right (idleTickResult replay dryRunReason reports))
    ExecuteActions ->
      onExecute reports

onlyCommandReport :: Text -> [ActionExecutionReport] -> Either DaemonLoopFailure CommandActionReport
onlyCommandReport label reports =
  case reports of
    [report] ->
      commandReportFromAction label report
    _ ->
      Left (DaemonLoopExternalFailure ("unexpected " <> Text.toLower label <> " action report count"))

requireFinalCommandReport :: Text -> [ActionExecutionReport] -> Either DaemonLoopFailure CommandActionReport
requireFinalCommandReport label reports =
  case finalCommandReport reports of
    Just report ->
      Right report
    Nothing ->
      Left (DaemonLoopExternalFailure (label <> " did not return a command report"))

commandReportFromAction :: Text -> ActionExecutionReport -> Either DaemonLoopFailure CommandActionReport
commandReportFromAction label report =
  case report.actionExecutionResult of
    CommandActionResult commandReport ->
      Right (CommandActionReport report commandReport)
    _ ->
      Left (invalidCommandResult report (label <> " did not return a command report"))

invalidCommandResult :: ActionExecutionReport -> Text -> DaemonLoopFailure
invalidCommandResult report =
  DaemonLoopDaemonFailure . DaemonActionResultInvalid report.actionExecutionAction
