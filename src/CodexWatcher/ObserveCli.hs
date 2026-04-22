{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.ObserveCli
  ( observeOnce
  ) where

import CodexWatcher.ActionExecutor
import CodexWatcher.AppServerClient
import CodexWatcher.Cli
import CodexWatcher.Daemon
import CodexWatcher.EffectRuntimeCli
import CodexWatcher.GhGit
import CodexWatcher.IssueImplementWatcher
import CodexWatcher.IssuePlanningWatcher
import CodexWatcher.PrReviewWatcher
import CodexWatcher.Protocol
import CodexWatcher.RuntimeOwnerCli (validateRuntimeOwnerForExecution)
import CodexWatcher.Types
import Data.Aeson (Value (Null))
import Data.Text qualified as Text
import System.Exit (die)

observeOnce :: ObserveOnceCli -> IO ()
observeOnce cli = do
  observation <- parseDaemonObservation cli
  executor <- observeOnceExecutor cli
  let executionMode = if cli.observeCliExecute then ExecuteActions else DryRunActions
      options =
        DaemonOptions
          { daemonEventLogPath = cli.observeCliEventsPath
          , daemonRuntimeConfig = defaultEffectRuntimeConfig cli.observeCliRepo cli.observeCliWorkdir cli.observeCliStateDir
          , daemonExecutionMode = executionMode
          }
  validateRuntimeOwnerForExecution cli.observeCliStateDir options.daemonExecutionMode
  result <- runObservedDaemonTickFromFile executor options observation
  case result of
    Left failure -> die (Text.unpack (formatDaemonFailure failure))
    Right tick -> do
      putStrLn ("event: " <> show tick.daemonObservedEvent)
      putStrLn ("phase: " <> show (somePhase tick.daemonObservedState))
      putStrLn ("compatibility writes: " <> show (length tick.daemonObservedCompatibilityWrites))
      putStrLn ("actions: " <> show (length tick.daemonObservedActionReports))
      putStrLn ("mode: " <> show options.daemonExecutionMode)

observeOnceExecutor :: ObserveOnceCli -> IO (ActionExecutor IO)
observeOnceExecutor cli
  | cli.observeCliExecute = do
      endpoint <- maybe (die "--execute requires --app-server-host and --app-server-port") pure cli.observeCliEndpoint
      pure (ioActionExecutor (appServerInterpreterFromEndpoint endpoint defaultAppServerClientOptions) (pure ()) (pure ()))
  | otherwise =
      pure (ioActionExecutor (AppServerInterpreter (\_ -> pure Null)) (pure ()) (pure ()))

parseDaemonObservation :: ObserveOnceCli -> IO DaemonObservation
parseDaemonObservation cli =
  case (cli.observeCliDomain, cli.observeCliObservation) of
    (CliIssuePlanning, "turn-started") ->
      DaemonIssuePlanningObservation
        <$> (ObservedPlanningTurnStarted <$> requiredValue "--thread-id" cli.observeCliThreadId <*> requiredValue "--turn-id" cli.observeCliTurnId)
    (CliIssuePlanning, "turn-completed") ->
      pure (DaemonIssuePlanningObservation ObservedPlanningTurnCompleted)
    (CliIssueImplement, "triage-turn-started") ->
      DaemonIssueImplementObservation . ObservedTriageTurnStarted <$> requiredValue "--turn-id" cli.observeCliTurnId
    (CliIssueImplement, "triage-already-fixed") ->
      pure (DaemonIssueImplementObservation ObservedTriageAlreadyFixed)
    (CliIssueImplement, "triage-needs-implementation") ->
      pure (DaemonIssueImplementObservation ObservedTriageNeedsImplementation)
    (CliIssueImplement, "triage-blocked") ->
      DaemonIssueImplementObservation . ObservedTriageBlocked <$> requiredBlockedReason cli
    (CliIssueImplement, "plan-turn-started") ->
      DaemonIssueImplementObservation . ObservedPlanTurnStarted <$> requiredValue "--turn-id" cli.observeCliTurnId
    (CliIssueImplement, "plan-completed") ->
      pure (DaemonIssueImplementObservation (ObservedPlanCompleted cli.observeCliImplementationTurnId))
    (CliIssueImplement, "pr-created") ->
      DaemonIssueImplementObservation . ObservedPullRequestCreated <$> requiredValue "--pr-number" cli.observeCliPrNumber
    (CliIssueImplement, "pr-reused") ->
      DaemonIssueImplementObservation . ObservedPullRequestReused <$> requiredValue "--pr-number" cli.observeCliPrNumber
    (CliIssueImplement, "implementation-turn-started") ->
      DaemonIssueImplementObservation . ObservedImplementationTurnStarted <$> requiredValue "--turn-id" cli.observeCliTurnId
    (CliIssueImplement, "implementation-incomplete") ->
      pure (DaemonIssueImplementObservation (ObservedImplementationIncomplete (maybe "incomplete" id cli.observeCliReason)))
    (CliIssueImplement, "implementation-blocked") ->
      DaemonIssueImplementObservation . ObservedImplementationBlocked <$> requiredBlockedReason cli
    (CliIssueImplement, "review-handoff-initialized") ->
      DaemonIssueImplementObservation . ObservedReviewHandoffInitialized <$> requiredValue "--pr-number" cli.observeCliPrNumber
    (CliIssueImplement, "review-handoff-started") ->
      DaemonIssueImplementObservation . ObservedReviewHandoffStarted <$> requiredValue "--pr-number" cli.observeCliPrNumber
    (CliIssueImplement, "implementation-completed") ->
      DaemonIssueImplementObservation . ObservedImplementationCompleted <$> requiredValue "--pr-number" cli.observeCliPrNumber
    (CliIssueImplement, "pr-merged") ->
      DaemonIssueImplementObservation . ObservedPullRequestMerged <$> requiredValue "--pr-number" cli.observeCliPrNumber
    (CliPrReview, "review-threads") ->
      DaemonPrReviewObservation
        <$> (ObservedReviewThreads <$> reviewThreadsReportFromCli cli <*> requiredValue "--commit-sha" cli.observeCliCommitSha <*> requiredValue "--turn-id" cli.observeCliTurnId)
    (CliPrReview, "worker-completed") ->
      pure (DaemonPrReviewObservation (ObservedWorkerOutcome WorkerCompleted))
    (CliPrReview, "worker-incomplete") ->
      pure (DaemonPrReviewObservation (ObservedWorkerOutcome (WorkerIncomplete (maybe "incomplete" id cli.observeCliReason))))
    (CliPrReview, "worker-blocked") ->
      DaemonPrReviewObservation . ObservedWorkerOutcome . WorkerBlocked <$> requiredBlockedReason cli
    (CliPrReview, "reviewer-clean") ->
      DaemonPrReviewObservation . ObservedReviewerOutcome . ReviewerClean <$> requiredCleanReviewEvidence cli
    (CliPrReview, "reviewer-problems") ->
      DaemonPrReviewObservation . ObservedReviewerOutcome . ReviewerProblemsAdded <$> requiredValue "--commit-sha" cli.observeCliCommitSha
    (CliPrReview, "reviewer-incomplete") ->
      pure (DaemonPrReviewObservation (ObservedReviewerOutcome (ReviewerIncomplete (maybe "incomplete" id cli.observeCliReason))))
    (CliPrReview, "reviewer-blocked") ->
      DaemonPrReviewObservation . ObservedReviewerOutcome . ReviewerBlocked <$> requiredBlockedReason cli
    (CliPrReview, "merge-completed") ->
      DaemonPrReviewObservation . ObservedMergeCompleted . MergeCommit <$> requiredValue "--merge-commit-sha" cli.observeCliMergeCommitSha
    (CliPrReview, "blocked") ->
      DaemonPrReviewObservation . ObservedPrReviewBlocked <$> requiredBlockedReason cli
    _ ->
      die ("unsupported observe-once domain/observation: " <> cliDomainName cli.observeCliDomain <> "/" <> cli.observeCliObservation)

reviewThreadsReportFromCli :: ObserveOnceCli -> IO ReviewThreadsReport
reviewThreadsReportFromCli cli =
  pure
    ReviewThreadsReport
      { reviewThreads = unresolvedThreads
      , unresolvedReviewThreads = unresolvedThreads
      }
 where
  unresolvedThreads =
    fmap
      (\threadId -> ReviewThread threadId False False Nothing Nothing Nothing [])
      cli.observeCliReviewThreadIds

requiredCleanReviewEvidence :: ObserveOnceCli -> IO CleanReviewEvidence
requiredCleanReviewEvidence cli =
  CleanReviewEvidence
    <$> requiredValue "--commit-sha" cli.observeCliCommitSha
    <*> pure (maybe "LGTM" id cli.observeCliComment)

requiredBlockedReason :: ObserveOnceCli -> IO BlockedReason
requiredBlockedReason cli =
  BlockedReason <$> requiredValue "--reason" cli.observeCliReason

requiredValue :: String -> Maybe a -> IO a
requiredValue flag =
  maybe (die ("missing required flag " <> flag)) pure
