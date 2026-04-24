{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.ObserveCli
  ( observeOnce
  , parseDaemonObservation
  ) where

import CodexWatcher.ActionExecutor
import CodexWatcher.AppServerClient
import CodexWatcher.Cli
import CodexWatcher.Daemon
import CodexWatcher.EffectRuntimeCli
import CodexWatcher.GhGit
import CodexWatcher.Domain.IssueImplement.Watcher
import CodexWatcher.Domain.IssuePlanning.Watcher
import CodexWatcher.Domain.PrReview.Watcher
import CodexWatcher.Domain.PrReview.Protocol
import CodexWatcher.Runtime.Owner.Cli (validateRuntimeOwnerForExecution)
import CodexWatcher.Types
import Data.Aeson (Value (Null))
import Data.List (find)
import Data.Maybe (fromMaybe)
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

data ObservationSpec = ObservationSpec
  { specDomain :: Domain
  , specName :: String
  , specParser :: ObserveOnceCli -> IO DaemonObservation
  }

parseDaemonObservation :: ObserveOnceCli -> IO DaemonObservation
parseDaemonObservation cli =
  case find matches observationSpecs of
    Just spec -> spec.specParser cli
    Nothing ->
      die ("unsupported observe-once domain/observation: " <> cliDomainName cli.observeCliDomain <> "/" <> cli.observeCliObservation)
 where
  matches spec =
    spec.specDomain == cli.observeCliDomain
      && spec.specName == cli.observeCliObservation

observationSpecs :: [ObservationSpec]
observationSpecs =
  [ planning "turn-started" ( \cli ->
        ObservedPlanningTurnStarted
          <$> requiredValue "--thread-id" cli.observeCliThreadId
          <*> requiredValue "--turn-id" cli.observeCliTurnId
    )
  , planningPure "turn-completed" ObservedPlanningTurnCompleted
  , issue "plan-turn-started" ( \cli ->
        ObservedPlanTurnStarted <$> requiredValue "--turn-id" cli.observeCliTurnId
    )
  , issue "plan-completed" ( \cli ->
        ObservedPlanCompleted
          <$> requiredValue "--plan-markdown" cli.observeCliPlanMarkdown
          <*> pure cli.observeCliImplementationTurnId
    )
  , issue "pr-created" ( \cli ->
        ObservedPullRequestCreated <$> requiredValue "--pr-number" cli.observeCliPrNumber
    )
  , issue "pr-reused" ( \cli ->
        ObservedPullRequestReused <$> requiredValue "--pr-number" cli.observeCliPrNumber
    )
  , issue "implementation-turn-started" ( \cli ->
        ObservedImplementationTurnStarted <$> requiredValue "--turn-id" cli.observeCliTurnId
    )
  , issuePureFromCli "implementation-incomplete" ( \cli ->
        ObservedImplementationIncomplete (fromMaybe "incomplete" cli.observeCliReason)
    )
  , issue "implementation-blocked" ( \cli ->
        ObservedImplementationBlocked <$> requiredBlockedReason cli
    )
  , issue "review-handoff-initialized" ( \cli ->
        ObservedReviewHandoffInitialized <$> requiredValue "--pr-number" cli.observeCliPrNumber
    )
  , issue "review-handoff-started" ( \cli ->
        ObservedReviewHandoffStarted <$> requiredValue "--pr-number" cli.observeCliPrNumber
    )
  , issue "implementation-completed" ( \cli ->
        ObservedImplementationCompleted <$> requiredValue "--pr-number" cli.observeCliPrNumber
    )
  , issue "pr-merged" ( \cli ->
        ObservedPullRequestMerged <$> requiredValue "--pr-number" cli.observeCliPrNumber
    )
  , prReview "review-threads" ( \cli ->
        ObservedReviewThreads
          <$> reviewThreadsReportFromCli cli
          <*> requiredValue "--commit-sha" cli.observeCliCommitSha
          <*> requiredValue "--turn-id" cli.observeCliTurnId
    )
  , prReviewPure "worker-completed" (ObservedWorkerOutcome WorkerCompleted)
  , prReviewPureFromCli "worker-incomplete" ( \cli ->
        ObservedWorkerOutcome (WorkerIncomplete (fromMaybe "incomplete" cli.observeCliReason))
    )
  , prReview "worker-blocked" ( \cli ->
        ObservedWorkerOutcome . WorkerBlocked <$> requiredBlockedReason cli
    )
  , prReview "reviewer-clean" ( \cli ->
        ObservedReviewerOutcome . ReviewerClean <$> requiredCleanReviewEvidence cli
    )
  , prReview "reviewer-problems" ( \cli ->
        ObservedReviewerOutcome . ReviewerProblemsAdded <$> requiredValue "--commit-sha" cli.observeCliCommitSha
    )
  , prReviewPureFromCli "reviewer-incomplete" ( \cli ->
        ObservedReviewerOutcome (ReviewerIncomplete (fromMaybe "incomplete" cli.observeCliReason))
    )
  , prReview "reviewer-blocked" ( \cli ->
        ObservedReviewerOutcome . ReviewerBlocked <$> requiredBlockedReason cli
    )
  , prReview "mergeability-clean" ( \cli ->
        ObservedMergeabilityClean <$> requiredValue "--commit-sha" cli.observeCliCommitSha
    )
  , prReviewPureFromCli "mergeability-waiting" ( \cli ->
        ObservedMergeabilityRetry (fromMaybe "waiting for mergeability" cli.observeCliReason)
    )
  , prReviewPureFromCli "mergeability-recheck" ( \cli ->
        ObservedMergeabilityRecheck (fromMaybe "rechecking reviews" cli.observeCliReason)
    )
  , prReview "merge-completed" ( \cli ->
        ObservedMergeCompleted . MergeCommit <$> requiredValue "--merge-commit-sha" cli.observeCliMergeCommitSha
    )
  , prReview "blocked" ( \cli ->
        ObservedPrReviewBlocked <$> requiredBlockedReason cli
    )
  ]

planning :: String -> (ObserveOnceCli -> IO IssuePlanningObservation) -> ObservationSpec
planning name parser =
  ObservationSpec IssuePlanning name (fmap DaemonIssuePlanningObservation . parser)

planningPure :: String -> IssuePlanningObservation -> ObservationSpec
planningPure name observation =
  planning name (const (pure observation))

issue :: String -> (ObserveOnceCli -> IO IssueImplementObservation) -> ObservationSpec
issue name parser =
  ObservationSpec IssueImplement name (fmap DaemonIssueImplementObservation . parser)

issuePureFromCli :: String -> (ObserveOnceCli -> IssueImplementObservation) -> ObservationSpec
issuePureFromCli name parser =
  issue name (pure . parser)

prReview :: String -> (ObserveOnceCli -> IO PrReviewObservation) -> ObservationSpec
prReview name parser =
  ObservationSpec PrReview name (fmap DaemonPrReviewObservation . parser)

prReviewPure :: String -> PrReviewObservation -> ObservationSpec
prReviewPure name observation =
  prReview name (const (pure observation))

prReviewPureFromCli :: String -> (ObserveOnceCli -> PrReviewObservation) -> ObservationSpec
prReviewPureFromCli name parser =
  prReview name (pure . parser)

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
    <*> pure (fromMaybe "LGTM" cli.observeCliComment)

requiredBlockedReason :: ObserveOnceCli -> IO BlockedReason
requiredBlockedReason cli =
  BlockedReason <$> requiredValue "--reason" cli.observeCliReason

requiredValue :: String -> Maybe a -> IO a
requiredValue flag =
  maybe (die ("missing required flag " <> flag)) pure
